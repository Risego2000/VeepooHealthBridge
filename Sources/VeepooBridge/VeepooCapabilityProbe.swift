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

    #if canImport(VeepooBleSDK)
    private let manager = VPBleCentralManage.sharedBleManager()
    private var models: [VPPeripheralModel] = []

    init() {
        status = "VeepooBleSDK disponible: inicia búsqueda"
    }

    func scan() {
        status = "Buscando mediante SDK oficial"
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
        let device = models[index]
        status = "Conectando mediante SDK Veepoo"
        guard let manager else { status = "Gestor Veepoo no inicializado"; return }
        manager.veepooSDKConnectDevice(device) { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                self.status = "Estado de conexión SDK: \(state)"
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
        guard let manager, manager.isConnected,
              let peripheral = manager.peripheralManage else {
            historyStatus = "No hay dispositivo conectado mediante Veepoo."
            return
        }
        historyStatus = "Solicitando historial mediante SDK…"
        peripheral.veepooSdkStartReadDeviceAllData { [weak self] state, totalDays, currentDay, dayProgress in
            Task { @MainActor in
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
        let days = min(7, Int(manager?.peripheralModel?.saveDays ?? 0) + 1)
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "yyyy-MM-dd"
        dayFormatter.timeZone = .current
        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateTimeFormatter.timeZone = .current
        dateTimeFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        var output: [Measurement] = []
        for offset in 0..<days {
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let day = dayFormatter.string(from: date)
            guard let original = VPDataBaseOperation.veepooSDKGetOriginalData(withDate: day, andTableID: address) as? [String: Any] else { continue }
            for (time, fields) in original {
                guard let data = fields as? [String: Any],
                      let raw = data["heartValue"] as? NSNumber,
                      let instant = dateTimeFormatter.date(from: day + " " + time) else { continue }
                let bpm = raw.doubleValue
                guard (25...240).contains(bpm), instant <= Date() else { continue }
                let stableID = "veepoo-" + address + "-" + day + "-" + time + "-heart"
                output.append(Measurement(id: stableID, kind: .heartRate, value: bpm,
                    start: instant, end: instant, source: "Veepoo A2 " + address,
                    method: "SDK original-data heartValue", validated: false,
                    note: "Muestra del SDK; pendiente de contrastar con G Band antes de escribir en Salud."))
            }
        }
        extractedMeasurements = output.sorted { $0.start > $1.start }
        historyStatus = "Extraídas \(output.count) muestras de frecuencia cardíaca no verificadas. No enviadas a Salud."
    }
    #else
    init() {}
    func readHistoryDiagnostic() { historyStatus = "El SDK no está enlazado." }
    func inspectSDKDatabase() { historyStatus = "El SDK no está enlazado." }
    func extractHeartRatePreview() { historyStatus = "El SDK no está enlazado." }
    func connect(index: Int) { status = "El SDK no está disponible en esta compilación." }
    func scan() {
        status = "No disponible: el framework VeepooBleSDK no está enlazado al target."
    }
    #endif
}
