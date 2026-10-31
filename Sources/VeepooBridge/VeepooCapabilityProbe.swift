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
    #else
    init() {}
    func readHistoryDiagnostic() { historyStatus = "El SDK no está enlazado." }
    func connect(index: Int) { status = "El SDK no está disponible en esta compilación." }
    func scan() {
        status = "No disponible: el framework VeepooBleSDK no está enlazado al target."
    }
    #endif
}
