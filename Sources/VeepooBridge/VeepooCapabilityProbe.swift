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

    #if canImport(VeepooBleSDK)
    private let manager = VPBleCentralManage.sharedBleManager()

    init() {
        status = "VeepooBleSDK disponible: inicia búsqueda"
    }

    func scan() {
        status = "Buscando mediante SDK oficial"
        guard let manager else { status = "Gestor Veepoo no inicializado"; return }
        manager.veepooSDKStartScanDeviceAndReceiveScanningDevice { [weak self] models in
            Task { @MainActor in
                // The callback's collection type is defined by VPPublicDefine.
                self?.status = "El SDK ha entregado una respuesta de búsqueda"
            }
        }
    }

    func connect(_ device: VPPeripheralModel) {
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
    #else
    init() {}
    func scan() {
        status = "No disponible: el framework VeepooBleSDK no está enlazado al target."
    }
    #endif
}
