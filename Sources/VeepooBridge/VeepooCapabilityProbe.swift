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
    @Published var automaticReconnect = true {
        didSet {
            #if canImport(VeepooBleSDK)
            manager?.automaticConnection = automaticReconnect
            #endif
        }
    }
    var recordingTimeZone = TimeZone.current

    #if canImport(VeepooBleSDK)
    private let manager = VPBleCentralManage.sharedBleManager()
    private var models: [VPPeripheralModel] = []

    init() {
        status = "VeepooBleSDK disponible: inicia búsqueda"
        manager?.isLogEnable = false
        manager?.automaticConnection = automaticReconnect
        manager?.vpBleConnectStateChangeBlock = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                self.ready = state.rawValue == 2
                if state.rawValue == 0 { self.reading = false; self.status = "Desconectado; reconexión según configuración" }
                if state.rawValue == 3 { self.status = "Contraseña rechazada por el reloj" }
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

    func connect(index: Int) {
        guard models.indices.contains(index) else { status = "Selecciona un dispositivo válido"; return }
        ready = false
        extractedMeasurements = []
        databaseSummary = []
        manager?.veepooSDKStopScanDevice()
        manager?.automaticConnection = automaticReconnect
        let device = models[index]
        status = "Conectando mediante SDK Veepoo"
        guard let manager else { status = "Gestor Veepoo no inicializado"; return }
        manager.veepooSDKConnectDevice(device) { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                self.ready = state.rawValue == 4
                self.status = self.ready ? "Conectado y contraseña verificada" : "Estado de conexión SDK: \(state)"
                guard let model = self.manager?.peripheralModel else { return }
                self.capabilities = [
                    "HRV: \(model.hrvType)",
                    "ECG: \(model.ecgType)",
                    "Sueño: \(model.sleepType)",
                    "Oxígeno: \(model.oxygenType)",
                    "Temperatura: \(model.temperatureType)",
                    "Días retenidos: \(model.saveDays)",
                    "Firmware: " + (model.deviceVersion ?? "no disponible")
                ]
            }
        }
    }

    func readHistoryDiagnostic() {
        guard !reading, ready, let manager, manager.isConnected,
              let peripheral = manager.peripheralManage else {
            historyStatus = "No hay dispositivo conectado mediante Veepoo."
            return
        }
        reading = true
        extractedMeasurements = []
        historyStatus = "Solicitando historial mediante SDK…"
        peripheral.veepooSdkStartReadDeviceAllData { [weak self] state, totalDays, currentDay, dayProgress in
            Task { @MainActor in
                if state.rawValue == 2 || state.rawValue == 3 { self?.reading = false }
                self?.historyStatus = "Lectura SDK: estado \(state), día \(currentDay)/\(totalDays), progreso \(dayProgress)%"
            }
        }
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
        let days = max(1, min(30, Int(manager?.peripheralModel?.saveDays ?? 0) + 1))
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
            if let rows = VPDataBaseOperation.veepooSDKGetDeviceOxygenData(withDate: day, andTableID: address) as? [[String: Any]] {
                output += decoder.oxygen(day: day, rows: rows)
            }
            if let rows = VPDataBaseOperation.veepooSDKGetDeviceTemperatureData(withDate: day, andTableID: address) as? [[String: Any]] {
                output += decoder.temperature(day: day, rows: rows)
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
        ready = false
        reading = false
        manager?.veepooSDKStopScanDevice()
        manager?.veepooSDKDisconnectDevice()
        status = "Desconectado por el usuario"
    }

    #else
    init() {}
    func disconnect() {}
    func readHistoryDiagnostic() { historyStatus = "El SDK no está enlazado." }
    func inspectSDKDatabase() { historyStatus = "El SDK no está enlazado." }
    func extractHeartRatePreview() { historyStatus = "El SDK no está enlazado." }
    func connect(index: Int) { status = "El SDK no está disponible en esta compilación." }
    func scan() {
        status = "No disponible: el framework VeepooBleSDK no está enlazado al target."
    }
    #endif
}
