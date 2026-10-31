import Foundation
import CoreBluetooth

struct NearbyDevice: Identifiable {
    let id: UUID
    var name: String
    var rssi: Int
}

final class BluetoothScanner: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published private(set) var status = "Inicializando"
    @Published private(set) var scanning = false
    @Published private(set) var devices: [NearbyDevice] = []
    private var central: CBCentralManager!

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: status = "Disponible"
        case .poweredOff: status = "Desactivado"
        case .unauthorized: status = "Sin permiso"
        case .unsupported: status = "No compatible"
        default: status = "No disponible"
        }
    }

    func toggleScan() {
        guard central.state == .poweredOn else { status = "Activa Bluetooth y concede acceso"; return }
        if scanning { central.stopScan(); scanning = false }
        else {
            devices.removeAll()
            central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            scanning = true
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "Dispositivo sin nombre"
        let device = NearbyDevice(id: peripheral.identifier, name: name, rssi: RSSI.intValue)
        if let i = devices.firstIndex(where: { $0.id == device.id }) { devices[i] = device }
        else { devices.append(device) }
    }
}
