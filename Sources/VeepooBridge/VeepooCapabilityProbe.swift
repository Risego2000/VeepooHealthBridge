import Foundation
import Combine

#if canImport(VeepooBleSDK)
import VeepooBleSDK
#endif

/// Diagnostic bridge to vendor APIs. It only reports verified device feature flags.
/// It never fabricates measurements or writes to HealthKit.
@MainActor
final class VeepooCapabilityProbe: ObservableObject {
    @Published private(set) var status = "SDK no enlazado"
    @Published private(set) var capabilities: [String] = []
    @Published private(set) var discovered: [String] = []
    @Published private(set) var historyStatus = "Sin lectura iniciada"
    @Published private(set) var databaseSummary: [String] = []
    @Published private(set) var extractedMeasurements: [Measurement] = []

    @Published private(set) var ready = false
    @Published private(set) var reading = false
    @Published private(set) var archiveURL: URL?
    private var operationID = UUID()
    @Published var automaticReconnect = UserDefaults.standard.object(forKey: "automaticReconnect") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(automaticReconnect, forKey: "automaticReconnect")
            #if canImport(VeepooBleSDK)
            manager?.automaticConnection = automaticReconnect
            #endif
        }
    }
    var recordingTimeZone: TimeZone {
        get { TimeZone(identifier: UserDefaults.standard.string(forKey: "recordingTimeZone") ?? "") ?? .current }
        set { UserDefaults.standard.set(newValue.identifier, forKey: "recordingTimeZone") }
    }

    #if canImport(VeepooBleSDK)
    private let manager = VPBleCentralManage.sharedBleManager()
    private var models: [VPPeripheralModel] = []
    private var connectionWanted = false

    init() {
        status = "VeepooBleSDK disponible: inicia búsqueda"
        manager?.isLogEnable = false
        manager?.automaticConnection = automaticReconnect
        manager?.vpBleConnectStateChangeBlock = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                self.ready = self.connectionWanted && state.rawValue == 3
                if state.rawValue == 0 { self.reading = false; self.status = "Desconectado; reconexión según configuración" }
                if state.rawValue == 4 { self.status = "Contraseña rechazada por el reloj" }
            }
        }
    }

    func scan() {
        status = "Buscando mediante SDK oficial"
        guard !reading else { return }
        manager?.veepooSDKStopScanDevice()
        models.removeAll()
        discovered.removeAll()
        guard let manager else { status = "Gestor Veepoo no inicializado"; return }
        manager.veepooSDKStartScanDeviceAndReceiveScanningDevice { [weak self] model in
            Task { @MainActor in
                guard let self else { return }
                guard let model else { return }
                let label = (model.deviceName ?? "Dispositivo") + " · " + (model.deviceAddress ?? "sin dirección")
                if !self.discovered.contains(label) {
                    self.models.append(model)
                    self.discovered.append(label)
                }
                self.status = "\(self.discovered.count) dispositivos encontrados"
            }
        }
    }

    func connect(index: Int, password: String = "0000") {
        guard models.indices.contains(index) else { status = "Selecciona un dispositivo válido"; return }
        guard password.count == 4, password.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            status = "La contraseña debe tener cuatro cifras"; return
        }
        connectionWanted = true
        ready = false
        extractedMeasurements = []
        databaseSummary = []
        manager?.veepooSDKStopScanDevice()
        manager?.automaticConnection = automaticReconnect
        let device = models[index]
        device.devicePassword = password
        status = "Conectando mediante SDK Veepoo"
        guard let manager else { status = "Gestor Veepoo no inicializado"; return }
        manager.veepooSDKConnectDevice(device) { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                guard self.connectionWanted else { return }
                self.ready = state.rawValue == 4
                self.status = self.ready ? "Conectado y contraseña verificada" : "Estado de conexión SDK: \(state)"
                guard let model = self.manager?.peripheralModel else { return }
                self.capabilities = [
                    "HRV: \(model.hrvType)",
                    "ECG: \(model.ecgType)",
                    "Sueño: \(model.sleepType)",
                    "Oxígeno: \(model.oxygenType)",
                    "Temperatura: \(model.temperatureType)",
                    "Composición corporal: \(model.bodyCompositionType)",
                    "Glucosa estimada: \(model.bloodGlucoseType)",
                    "Días retenidos: \(model.saveDays)",
                    "Firmware: " + (model.deviceVersion ?? "no disponible"),
                    "Firmware interno: " + (model.deviceTestVersion ?? "no disponible")
                ]
            }
        }
    }

    func supports(_ category: String) -> Bool {
        guard ready, let model = manager?.peripheralModel else { return false }
        switch category {
        case "oxygen": return model.oxygenType > 0
        case "hrv": return model.hrvType > 0
        case "temperature": return model.temperatureType > 0
        case "activity": return model.runningSaveTimes > 0
        default: return true
        }
    }

    func readHistoryDiagnostic() { readHistory(category: "basic") }

    func readHistory(category: String) {
        guard !reading, ready, let manager, manager.isConnected,
              let peripheral = manager.peripheralManage else {
            historyStatus = "Conecta y autentica el reloj; espera a terminar la operación actual."
            return
        }
        guard supports(category) else { historyStatus = "El reloj no anuncia esta capacidad"; return }
        reading = true
        extractedMeasurements = []
        let token = UUID()
        operationID = token
        historyStatus = "Solicitando historial: " + category
        let progress: (VPReadDeviceBaseDataState, UInt, UInt, UInt) -> Void = { [weak self] state, total, current, percent in
            Task { @MainActor in
                guard let self, self.operationID == token else { return }
                self.historyStatus = "\(category): estado \(state.rawValue), día \(current)/\(total), \(percent)%"
                if state.rawValue == 2 || state.rawValue == 3 { self.reading = false }
            }
        }
        switch category {
        case "oxygen": peripheral.veepooSdkStartReadDeviceOxygenData(progress)
        case "hrv": peripheral.veepooSdkStartReadDeviceHrvData(progress)
        case "temperature":
            if manager.peripheralModel?.temperatureType == 5 { peripheral.veepooSdkStartReadDeviceAllData(readStateChange: progress) }
            else { peripheral.veepooSdkStartReadDeviceTemperatureData(progress) }
        case "activity": peripheral.veepooSDKStartReadDeviceRunningData(progress)
        default: peripheral.veepooSdkStartReadDeviceAllData(readStateChange: progress)
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000_000)
            guard let self, self.operationID == token, self.reading else { return }
            // Disconnect before allowing a new command: the old SDK transfer may still be active.
            self.disconnect()
            self.historyStatus = "Tiempo de espera agotado. Se desconectó para cancelar la transferencia. Reconecta y reintenta."
        }
    }

    /// KVC keys are an explicit allowlist of public properties in the pinned SDK headers.
    /// Values are preserved without inferring clinical units or invoking a vendor diagnosis.
    private func snapshot(_ model: NSObject, keys: [String]) -> [String: Any] {
        var result: [String: Any] = [:]
        for key in keys { if let value = model.value(forKey: key) { result[key] = value } }
        return result
    }

    func exportSDKArchive() {
        guard !reading, ready, let address = manager?.peripheralModel?.deviceAddress, !address.isEmpty else {
            historyStatus = "Conecta el reloj y espera al fin de la lectura antes de archivar."
            return
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = recordingTimeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = recordingTimeZone
        var days: [[String: Any]] = []
        for offset in 0..<max(1, min(256, Int(manager?.peripheralModel?.saveDays ?? 0) + 1)) {
            guard let instant = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let day = formatter.string(from: instant)
            let accurate = VPDataBaseOperation.veepooSDKGetAccurateSleepData(withDate: day, andTableID: address) ?? []
            let sleep = accurate.map { snapshot($0, keys: [
                "sleepType", "sleepTime", "wakeTime", "sleepTag", "getUpScore", "deepScore",
                "sleepEfficiencyScore", "fallAsleepScore", "sleepTimeScore", "exitSleepMode", "sleepQuality",
                "getUpTimes", "deepAndLightMode", "sleepDuration", "deepDuration", "lightDuration",
                "getUpDuration", "otherDuration", "firstDeepDuration", "getUpToDeepAve", "onePointDuration",
                "accurateType", "insomniaTag", "insomniaScore", "insomniaTimes", "insomniaRecord",
                "sleepLine", "insomniaDuration", "lastType", "nextType", "mac"]) }
            let composition = VPDataBaseOperation.veepooSDKGetDeviceOffStoreBodyComposition(withDate: day, andTableID: address) ?? []
            let bodies = composition.map { snapshot($0, keys: [
                "date", "testTime", "isDeviceTest", "stature", "weight", "gender", "bmi",
                "bodyFatPercentage", "fatMass", "leanBodyMass", "muscleRate", "muscleMass",
                "subcutaneousFat", "bodyMoisture", "waterContent", "skeletalMuscleRate", "boneMass",
                "proportionOfProtein", "proteinAmount", "basalMetabolicRate"]) }
            let ecgs = VPDataBaseOperation.veepooSDKGetDeviceOffStoreECG(withDate: day, andTableID: address) ?? []
            let traces = ecgs.map { snapshot($0, keys: [
                "type", "ecgType", "date", "testTime", "duration", "mac", "state", "aveHeart", "aveHrv",
                "aveResRate", "aveQT", "avePWV", "originalSignals", "filterSignals", "hearts", "hrvs",
                "rrs", "resRates", "qts", "pwvs", "lead", "result1", "result2", "result3", "result4",
                "result5", "result6", "result7", "result8", "multipleDiagnosisTempStr", "frequency", "uploadFrequency"]) }
            let analysis = VPDataBaseOperation.veepooSDKGetDeviceBloodAnalysisData(withDate: day, andTableID: address) ?? []
            let estimates: [[String: Any]] = analysis.map { model in
                ["time": model.time, "totalCholesterols": model.totalCholesterols,
                 "triglycerides": model.triglycerides, "highDensityLipoproteins": model.highDensityLipoproteins,
                 "lowDensityLipoproteins": model.lowDensityLipoproteins, "uricAcids": model.uricAcids]
            }
            var entry: [String: Any] = ["date": day]
            entry["bodyComposition"] = bodies
            entry["ecgRawNotHealthKit"] = traces
            entry["bloodAnalysisEstimates"] = estimates
            entry["glucoseEstimates"] = VPDataBaseOperation.veepooSDKGetDeviceBloodGlucoseData(withDate: day, andTableID: address) ?? []
            entry["original"] = VPDataBaseOperation.veepooSDKGetOriginalData(withDate: day, andTableID: address) ?? [:]
            entry["bloodPressureRawAmbiguousKeys"] = VPDataBaseOperation.veepooSDKGetBloodData(withDate: day, andTableID: address) ?? []
            entry["ordinarySleep"] = VPDataBaseOperation.veepooSDKGetSleepData(withDate: day, andTableID: address) ?? []
            entry["accurateSleep"] = sleep
            entry["oxygen"] = VPDataBaseOperation.veepooSDKGetDeviceOxygenData(withDate: day, andTableID: address) ?? []
            entry["hrvUnspecifiedMethod"] = VPDataBaseOperation.veepooSDKGetDeviceHrvData(withDate: day, andTableID: address) ?? []
            entry["temperature"] = VPDataBaseOperation.veepooSDKGetDeviceTemperatureData(withDate: day, andTableID: address) ?? []
            entry["activities"] = VPDataBaseOperation.veepooSDKGetDeviceRunningData(withDate: day, andTableID: address) ?? []
            days.append(entry)
        }
        let archive: [String: Any] = ["schemaVersion": 1, "device": address,
            "firmware": manager?.peripheralModel?.deviceVersion ?? "unknown",
            "timeZone": recordingTimeZone.identifier, "clinicalValidation": false, "days": days]
        do {
            let data = try JSONSerialization.data(withJSONObject: archive, options: [.prettyPrinted, .sortedKeys])
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Veepoo-SDK-private-archive.json")
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            archiveURL = url
            historyStatus = "Archivo privado preparado. Contiene datos sanitarios brutos, no verificados."
        } catch { historyStatus = "No se pudo crear el archivo privado: \(error.localizedDescription)" }
    }

    func inspectSDKDatabase() {
        guard let address = manager?.peripheralModel?.deviceAddress, !address.isEmpty else {
            historyStatus = "No se conoce la dirección del reloj conectado."
            return
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        databaseSummary = (0..<min(7, Int(manager?.peripheralModel?.saveDays ?? 0) + 1)).map { dayOffset in
            let day = formatter.string(from: Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date())
            let raw = VPDataBaseOperation.veepooSDKGetOriginalData(withDate: day, andTableID: address)
            let sleep = VPDataBaseOperation.veepooSDKGetSleepData(withDate: day, andTableID: address)
            let oxygen = VPDataBaseOperation.veepooSDKGetDeviceOxygenData(withDate: day, andTableID: address)
            let hrv = VPDataBaseOperation.veepooSDKGetDeviceHrvData(withDate: day, andTableID: address)
            return "\(day): intervalos \(raw?.count ?? 0), sueño \(sleep?.count ?? 0), oxígeno \(oxygen?.count ?? 0), HRV \(hrv?.count ?? 0)"
        }
        historyStatus = "Diagnóstico local disponible. Ninguna medición se ha enviado a HealthKit."
    }
    /// Convert only documented timestamped heart-rate samples, without declaring clinical validation.
    /// The SDK labels original-data fields heartValue and keys as local HH:mm timestamps.
    func extractHeartRatePreview() {
        guard let address = manager?.peripheralModel?.deviceAddress, !address.isEmpty else {
            historyStatus = "Conecta el reloj antes de extraer el historial."
            return
        }
        guard ready, !reading else { historyStatus = "Espera a la autenticación y a finalizar la lectura"; return }
        let decoder = VendorHistoryDecoder(device: address, timeZone: recordingTimeZone)
        let days = max(1, min(256, Int(manager?.peripheralModel?.saveDays ?? 0) + 1))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = recordingTimeZone
        formatter.dateFormat = "yyyy-MM-dd"
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = recordingTimeZone
        var output: [Measurement] = []
        for offset in 0..<days {
            guard let instant = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let day = formatter.string(from: instant)
            if let rows = VPDataBaseOperation.veepooSDKGetOriginalData(withDate: day, andTableID: address) as? [String: Any] {
                output += decoder.original(day: day, rows: rows)
            }
            if let rows = VPDataBaseOperation.veepooSDKGetOriginalChangeHalfHourData(withDate: day, andTableID: address) as? [String: Any] {
                output += decoder.halfHourSteps(day: day, rows: rows)
            }
            if let rows = VPDataBaseOperation.veepooSDKGetDeviceOxygenData(withDate: day, andTableID: address) as? [[String: Any]] {
                output += decoder.oxygen(day: day, rows: rows)
            }
            if let rows = VPDataBaseOperation.veepooSDKGetDeviceTemperatureData(withDate: day, andTableID: address) as? [[String: Any]] {
                output += decoder.temperature(day: day, rows: rows)
            }
            if let models = VPDataBaseOperation.veepooSDKGetDeviceOffStoreBodyComposition(withDate: day, andTableID: address) {
                let rows: [[String: Any]] = models.map { model in
                    ["date": model.date, "testTime": model.testTime,
                     "bodyFatPercentage": model.bodyFatPercentage, "leanBodyMass": model.leanBodyMass]
                }
                output += decoder.bodyComposition(rows: rows)
            }
            if manager?.peripheralModel?.sleepType == 1,
               let models = VPDataBaseOperation.veepooSDKGetAccurateSleepData(withDate: day, andTableID: address) {
                let rows: [[String: Any]] = models.map { model in
                    ["sleepTime": model.sleepTime, "wakeTime": model.wakeTime,
                     "onePointDuration": model.onePointDuration, "sleepLine": model.sleepLine]
                }
                output += decoder.accurateSleep(rows: rows)
            }
            if manager?.peripheralModel?.sleepType == 0,
               let rows = VPDataBaseOperation.veepooSDKGetSleepData(withDate: day, andTableID: address) as? [[String: Any]] {
                output += decoder.ordinarySleep(rows: rows)
            }
        }
        extractedMeasurements = MeasurementValidation.merge([], incoming: output)
        historyStatus = "Extraídas \(extractedMeasurements.count) muestras sin verificar. Coteja zona horaria, fechas y unidades antes de Salud."
    }

    func disconnect() {
        operationID = UUID()
        connectionWanted = false
        ready = false
        reading = false
        manager?.veepooSDKStopScanDevice()
        manager?.veepooSDKDisconnectDevice()
        status = "Desconectado por el usuario"
    }

    #else
    init() {}
    func disconnect() {}
    func readHistory(category: String) { historyStatus = "El SDK no está enlazado." }
    func exportSDKArchive() { historyStatus = "El SDK no está enlazado." }
    func readHistoryDiagnostic() { historyStatus = "El SDK no está enlazado." }
    func inspectSDKDatabase() { historyStatus = "El SDK no está enlazado." }
    func extractHeartRatePreview() { historyStatus = "El SDK no está enlazado." }
    func supports(_ category: String) -> Bool { false }
    func connect(index: Int, password: String = "0000") { status = "El SDK no está disponible en esta compilación." }
    func scan() {
        status = "No disponible: el framework VeepooBleSDK no está enlazado al target."
    }
    #endif
}
