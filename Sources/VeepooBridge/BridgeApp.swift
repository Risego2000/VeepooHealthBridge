import SwiftUI
import UniformTypeIdentifiers
import Charts

@main struct VeepooHealthBridgeApp: App {
    @StateObject private var bluetooth = BluetoothScanner()
    @StateObject private var veepoo = VeepooCapabilityProbe()
    @StateObject private var health = HealthBridge()
    @StateObject private var measurements = MeasurementStore()
    var body: some Scene {
        WindowGroup { ContentView()
            .environmentObject(bluetooth).environmentObject(veepoo).environmentObject(health).environmentObject(measurements) }
    }
}

struct ContentView: View {
    @EnvironmentObject var bluetooth: BluetoothScanner
    @EnvironmentObject var veepoo: VeepooCapabilityProbe
    @EnvironmentObject var health: HealthBridge
    @EnvironmentObject var measurements: MeasurementStore
    @AppStorage("recordingTimeZone") private var recordingZone = TimeZone.current.identifier
    @State private var importing = false
    @State private var exportURL: URL?
    @State private var showDeleteConfirmation = false
    @State private var confirmedForHealth = false

    var body: some View {
        NavigationStack {
            List {
                Section("Diagnóstico") {
                    LabeledContent("Bluetooth", value: bluetooth.status)
                    LabeledContent("Conexión A2", value: bluetooth.connectionStatus)
                    if !bluetooth.services.isEmpty {
                        Text("Servicios GATT: " + bluetooth.services.joined(separator: ", "))
                            .font(.caption).textSelection(.enabled)
                    }
                    LabeledContent("SDK Veepoo", value: veepoo.status)
                    Button("Buscar con SDK Veepoo") { veepoo.scan() }
                    Button("Leer historial con SDK") { veepoo.readHistoryDiagnostic() }
                        .disabled(!veepoo.ready || veepoo.reading)
                    Button("Desconectar SDK") { veepoo.disconnect() }
                    Text(veepoo.historyStatus).font(.caption)
                    Button("Inspeccionar datos guardados por SDK") { veepoo.inspectSDKDatabase() }
                    Button("Extraer métricas documentadas a vista previa") { veepoo.extractHeartRatePreview() }
                    Button("Guardar vista previa sin validar") { measurements.addSDKPreview(veepoo.extractedMeasurements) }
                        .disabled(veepoo.extractedMeasurements.isEmpty)
                    Text("Muestras extraídas: \(veepoo.extractedMeasurements.count). No se envían a Salud sin verificación.")
                    ForEach(veepoo.databaseSummary, id: \.self) { Text($0).font(.caption) }
                    ForEach(Array(veepoo.discovered.enumerated()), id: \.offset) { index, label in
                        Button("Conectar Veepoo: " + label) { veepoo.connect(index: index) }
                    }
                    ForEach(veepoo.capabilities, id: \.self) { Text($0) }
                    LabeledContent("HealthKit", value: health.status)
                    Text("No se generan ni simulan mediciones. El escaneo no lee registros del reloj.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Configuración") {
                    Toggle("Reconectar mediante SDK tras pérdida de señal", isOn: $veepoo.automaticReconnect)
                    Picker("Zona horaria de las mediciones", selection: $recordingZone) {
                        ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0).tag($0) }
                    }
                    Text("Selecciona la zona donde el reloj registró los datos. Los cambios de zona y la hora repetida de otoño requieren cotejo manual.")
                        .font(.caption)
                }
                Section("Gráficos") { MeasurementChart(records: measurements.records) }
                Section("Relojes Bluetooth próximos") {
                    Button(bluetooth.scanning ? "Detener búsqueda" : "Buscar dispositivos") { bluetooth.toggleScan() }
                    ForEach(bluetooth.devices) { device in
                        VStack(alignment: .leading) {
                            Button(device.name) { bluetooth.connect(to: device.id) }.font(.headline)
                            Text("RSSI \(device.rssi) dBm · \(device.id.uuidString)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Prueba de conexión") {
                    Button("Desconectar dispositivo") { bluetooth.disconnect() }
                    Text("Esta prueba utiliza CoreBluetooth para descubrir servicios GATT. No reemplaza el protocolo Veepoo ni extrae datos de salud.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Historial local") {
                    LabeledContent("Registros", value: "\(measurements.records.count)")
                    Button("Importar archivo JSON") { importing = true }
                    Button("Preparar exportación JSON") {
                        exportURL = try? measurements.exportJSON()
                    }
                    if let exportURL { ShareLink("Compartir archivo", item: exportURL) }
                    Text(measurements.message).font(.caption)
                    ForEach(measurements.records.prefix(25)) { record in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.kind.title).font(.headline)
                            Text("\(record.value.formatted()) · \(record.start.formatted())")
                            if !record.validated {
                                Button("He cotejado esta muestra: verificar") { measurements.verify(id: record.id) }
                            }
                            Text("\(record.source) · \(record.method) · \(record.validated ? "verificado" : "no verificado")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button("Borrar historial local", role: .destructive) { showDeleteConfirmation = true }
                }
                Section("Apple Health") {
                    Button("Solicitar permisos") { health.requestPermissions() }
                    Toggle("Confirmo que he verificado los registros antes de transferir", isOn: $confirmedForHealth)
                    Button("Sincronizar registros verificados") { health.sync(measurements.records) }
                        .disabled(!confirmedForHealth || measurements.records.isEmpty || health.isSyncing)
                    Text(health.lastResults)
                    Text("El ECG y las estimaciones de glucosa, ácido úrico y lípidos NO se escriben en HealthKit. HRV solo se transfiere si el método es SDNN.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Estado de compatibilidad A2") {
                    Text("La integración del SDK se debe validar con el firmware del reloj. El emparejamiento de G Band no demuestra que otra app pueda leer su historial.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Veepoo Health Bridge")
            .onAppear { veepoo.recordingTimeZone = TimeZone(identifier: recordingZone) ?? .current }
            .onChange(of: recordingZone) { _, zone in
                veepoo.recordingTimeZone = TimeZone(identifier: zone) ?? .current
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result { measurements.importJSON(url) }
            }
            .confirmationDialog("¿Borrar los registros almacenados por Bridge?", isPresented: $showDeleteConfirmation) {
                Button("Borrar", role: .destructive) { measurements.deleteAll() }
            } message: { Text("No elimina datos de G Band ni Salud de Apple.") }
        }
    }
}

struct MeasurementChart: View {
    let records: [Measurement]
    @State private var kind = Measurement.Kind.heartRate
    var body: some View {
        VStack {
            Picker("Métrica", selection: $kind) {
                ForEach(Measurement.Kind.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            let samples = Array(records.filter { $0.kind == kind }.prefix(500)).sorted { $0.start < $1.start }
            if samples.isEmpty { Text("Sin datos de esta métrica") }
            else {
                Chart(samples) { sample in
                    PointMark(x: .value("Fecha", sample.start), y: .value("Valor", sample.value))
                }.frame(height: 180)
                Text("Hasta 500 muestras recientes. Oxígeno y grasa en fracción 0–1; temperatura en °C; pulsaciones en lpm.").font(.caption)
            }
        }
    }
}
