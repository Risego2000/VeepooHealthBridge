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
    @Published private(set) var connectionStatus = "Sin conectar"
    @Published private(set) var services: [String] = []
    private var selectedPeripheral: CBPeripheral?
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

    func connect(to id: UUID) {
        guard central.state == .poweredOn else {
            connectionStatus = "Bluetooth no disponible"
            return
        }
        guard let device = central.retrievePeripherals(withIdentifiers: [id]).first else {
            connectionStatus = "Dispositivo no encontrado: vuelve a buscar"
            return
        }
        central.stopScan()
        scanning = false
        selectedPeripheral = device
        device.delegate = self
        connectionStatus = "Conectando a \(device.name ?? "A2")"
        central.connect(device, options: nil)
    }

    func disconnect() {
        if let selectedPeripheral { central.cancelPeripheralConnection(selectedPeripheral) }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionStatus = "Conectado por BLE — descubriendo servicios"
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionStatus = "Falló la conexión: \(error?.localizedDescription ?? "sin detalle")"
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionStatus = "Desconectado \(error?.localizedDescription ?? "")"
        services = []
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

extension BluetoothScanner: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            connectionStatus = "Error de servicios: \(error.localizedDescription)"
            return
        }
        services = (peripheral.services ?? []).map { $0.uuid.uuidString }
        connectionStatus = "Conexión BLE establecida · \(services.count) servicios. No se han leído mediciones."
    }
}
