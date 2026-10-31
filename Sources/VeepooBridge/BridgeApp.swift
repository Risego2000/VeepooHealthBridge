import SwiftUI
import Charts
import UniformTypeIdentifiers

@main struct VeepooHealthBridgeApp: App {
    @StateObject private var bluetooth = BluetoothScanner()
    @StateObject private var veepoo = VeepooCapabilityProbe()
    @StateObject private var health = HealthBridge()
    @StateObject private var measurements = MeasurementStore()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(bluetooth).environmentObject(veepoo)
                .environmentObject(health).environmentObject(measurements).tint(.teal)
        }
    }
}

struct ContentView: View {
    @State private var tab = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--screen=") })?.replacingOccurrences(of: "--screen=", with: "") ?? "home"
    var body: some View {
        TabView(selection: $tab) {
            DashboardView().tabItem { Label("Resumen", systemImage: "square.grid.2x2.fill") }.tag("home")
            DeviceView().tabItem { Label("Reloj", systemImage: "applewatch") }.tag("device")
            HistoryView().tabItem { Label("Historial", systemImage: "chart.xyaxis.line") }.tag("history")
            HealthView().tabItem { Label("Salud", systemImage: "heart.fill") }.tag("health")
            SettingsView().tabItem { Label("Ajustes", systemImage: "gearshape.fill") }.tag("settings")
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var veepoo: VeepooCapabilityProbe
    @EnvironmentObject var measurements: MeasurementStore
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("VEEPOO · HEALTH BRIDGE", systemImage: "waveform.path.ecg").font(.caption.weight(.bold))
                        Text("Tu salud,\nen un mismo lugar.").font(.largeTitle.bold())
                        Text("Del reloj a Salud de Apple. Tú decides qué datos compartir.").font(.subheadline)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
                        .foregroundStyle(.white).background(LinearGradient(colors: [.teal, Color(red: 0.05, green: 0.28, blue: 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28))
                    HStack(spacing: 12) {
                        SummaryTile(title: "En tu iPhone", value: "\(measurements.records.count)", symbol: "tray.full.fill")
                        SummaryTile(title: "Verificados", value: "\(measurements.records.filter(\.validated).count)", symbol: "checkmark.shield.fill")
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Tu reloj A2", systemImage: "applewatch").font(.headline)
                        Text(veepoo.ready ? "Conectado y autenticado" : "Sin conexión verificada").foregroundStyle(.secondary)
                        Text("Firmware de referencia: 02.52.01.00-5982").font(.caption).foregroundStyle(.secondary)
                        NavigationLink("Configurar conexión") { DeviceView() }.buttonStyle(.borderedProminent)
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.background, in: RoundedRectangle(cornerRadius: 22))
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Primera sincronización").font(.headline)
                        Label("Conecta y autentica el reloj", systemImage: "1.circle")
                        Label("Descarga y revisa las muestras", systemImage: "2.circle")
                        Label("Autoriza el envío a Salud", systemImage: "3.circle")
                    }.font(.subheadline).padding(20)
                    Label("Datos locales · Sin cuenta de usuario · Sin datos de demostración", systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary)
                    Text("Versión de pruebas. La compatibilidad del A2 requiere validación física.").font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }.background(Color(.systemGroupedBackground)).navigationTitle("Resumen")
        }
    }
}

struct SummaryTile: View {
    let title: String
    let value: String
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(.teal)
            Text(value).font(.title.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.background, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct DeviceView: View {
    @EnvironmentObject var veepoo: VeepooCapabilityProbe
    @EnvironmentObject var measurements: MeasurementStore
    @EnvironmentObject var bluetooth: BluetoothScanner
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(veepoo.ready ? "Reloj preparado" : "Conecta tu reloj", systemImage: "applewatch.radiowaves.left.and.right").font(.title3.bold())
                    Text(veepoo.status).foregroundStyle(.secondary)
                    Button("Buscar reloj con Veepoo", systemImage: "antenna.radiowaves.left.and.right") { bluetooth.disconnect(); veepoo.scan() }
                    ForEach(Array(veepoo.discovered.enumerated()), id: \.offset) { index, label in
                        Button(label) { veepoo.connect(index: index) }
                    }
                    Button("Desconectar", role: .destructive) { veepoo.disconnect() }
                } header: { Text("Conexión oficial SDK") } footer: { Text("Libera la conexión de G Band antes de buscar. El SDK verifica la contraseña del reloj antes de permitir la lectura.") }
                Section("Recuperar mediciones") {
                    Button("Leer historial del reloj", systemImage: "arrow.down.circle") { veepoo.readHistoryDiagnostic() }.disabled(!veepoo.ready || veepoo.reading)
                    Menu("Lecturas adicionales por capacidad") {
                        Button("Oxígeno") { veepoo.readHistory(category: "oxygen") }
                        Button("HRV original, sin convertir a SDNN") { veepoo.readHistory(category: "hrv") }
                        Button("Temperatura") { veepoo.readHistory(category: "temperature") }
                        Button("Sesiones de actividad") { veepoo.readHistory(category: "activity") }
                    }.disabled(!veepoo.ready || veepoo.reading)
                    Text(veepoo.historyStatus).font(.caption)
                    Button("Extraer métricas documentadas") { veepoo.extractHeartRatePreview() }.disabled(!veepoo.ready || veepoo.reading)
                    Button("Guardar \(veepoo.extractedMeasurements.count) muestras para revisión") { measurements.addSDKPreview(veepoo.extractedMeasurements) }.disabled(veepoo.extractedMeasurements.isEmpty)
                }
                Section("Capacidades anunciadas") {
                    if veepoo.capabilities.isEmpty { Text("Se consultarán al conectar el dispositivo").foregroundStyle(.secondary) }
                    ForEach(veepoo.capabilities, id: \.self) { Text($0).font(.subheadline) }
                }
                Section("Diagnóstico de la base de datos") {
                    Button("Preparar archivo privado del SDK") { veepoo.exportSDKArchive() }
                    if let url = veepoo.archiveURL { ShareLink("Compartir datos sanitarios brutos", item: url) }
                    Text("El archivo conserva HRV sin método SDNN, sueño preciso y presión con nombres de campos ambiguos. No se envían a Salud.").font(.caption)
                    Button("Inspeccionar recuentos") { veepoo.inspectSDKDatabase() }
                    ForEach(veepoo.databaseSummary, id: \.self) { Text($0).font(.caption) }
                }
            }.navigationTitle("Tu reloj")
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject var measurements: MeasurementStore
    @State private var importing = false
    @State private var exportURL: URL?
    @State private var deleting = false
    @State private var verifying: Measurement?
    var body: some View {
        NavigationStack {
            List {
                Section("Tendencias") { MeasurementChart(records: measurements.records) }
                Section("Muestras recientes · \(measurements.records.count)") {
                    if measurements.records.isEmpty {
                        ContentUnavailableView("Aún no hay mediciones", systemImage: "waveform.path.ecg", description: Text("Conecta tu reloj y recupera el historial para ver tus datos aquí."))
                    }
                    ForEach(measurements.records.prefix(100)) { record in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { Text(record.kind.title).font(.headline); Spacer(); Image(systemName: record.validated ? "checkmark.seal.fill" : "clock").foregroundStyle(record.validated ? .teal : .secondary) }
                            Text("\(record.value.formatted()) · \(record.start.formatted())").font(.subheadline)
                            Text(record.method).font(.caption).foregroundStyle(.secondary)
                            Text(record.validated ? "Cotejado por ti" : "Pendiente de cotejo").font(.caption).foregroundStyle(.secondary)
                            if !record.validated { Button("Revisar y verificar") { verifying = record } }
                        }.padding(.vertical, 5)
                    }
                }
                Section("Tus archivos") {
                    Button("Importar JSON", systemImage: "square.and.arrow.down") { importing = true }
                    Button("Preparar exportación", systemImage: "square.and.arrow.up") {
                        do { exportURL = try measurements.exportJSON() }
                        catch { measurements.message = "No se pudo exportar: \(error.localizedDescription)" }
                    }
                    if let exportURL { ShareLink("Compartir historial sanitario", item: exportURL) }
                    Text(measurements.message).font(.caption)
                    Button("Borrar historial local", role: .destructive) { deleting = true }
                }
            }.navigationTitle("Historial")
                .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                    switch result {
                    case .success(let url): measurements.importJSON(url)
                    case .failure(let error): measurements.message = error.localizedDescription
                    }
                }
                .confirmationDialog("Borrar historial local", isPresented: $deleting) {
                    Button("Borrar", role: .destructive) { measurements.deleteAll() }
                } message: { Text("Los datos enviados a Salud y la base del SDK no se eliminan con esta acción.") }
                .sheet(item: $verifying) { record in
                    NavigationStack {
                        Form {
                            Section("Contrasta con el registro original") {
                                Text(record.kind.title).font(.headline)
                                LabeledContent("Valor", value: record.value.formatted())
                                LabeledContent("Inicio", value: record.start.formatted())
                                LabeledContent("Fin", value: record.end.formatted())
                                Text(record.source); Text(record.method)
                                Text(record.note ?? "Sin notas adicionales")
                            }
                            Section {
                                Text("Comprueba fecha, zona horaria, unidades y origen frente a G Band. Verificar no convierte una estimación del reloj en una medición clínica. La temperatura corporal requiere confirmar el tipo de sensor.")
                                Button("He comprobado los datos: verificar") { measurements.verify(id: record.id); verifying = nil }.buttonStyle(.borderedProminent)
                            }
                        }.navigationTitle("Revisar muestra").toolbar { Button("Cerrar") { verifying = nil } }
                    }
                }
        }
    }
}

struct HealthView: View {
    @EnvironmentObject var health: HealthBridge
    @EnvironmentObject var measurements: MeasurementStore
    @State private var consent = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Image(systemName: "heart.text.square.fill").font(.system(size: 54)).foregroundStyle(.pink).padding(.vertical, 12)
                    Text("Comparte solo lo que tú autorices.").font(.title2.bold())
                    Text("Las muestras deben pasar la validación de formato y tu revisión antes de enviarse a Salud.").foregroundStyle(.secondary)
                }
                Section("Permisos de Apple Health") {
                    Text(health.status)
                    Button("Solicitar permisos", systemImage: "heart.circle") { health.requestPermissions() }
                }
                Section("Sincronización") {
                    LabeledContent("Muestras verificadas", value: "\(measurements.records.filter(\.validated).count)")
                    Toggle("Autorizo transferir las muestras verificadas", isOn: $consent)
                    Button(health.isSyncing ? "Sincronizando…" : "Sincronizar con Salud", systemImage: "arrow.triangle.2.circlepath") { health.sync(measurements.records) }
                        .disabled(!consent || health.isSyncing || !measurements.records.contains(where: \.validated))
                    Text(health.lastResults).font(.caption)
                }
                Section("Qué debes saber") {
                    Label("Sin escritura de ECG ni estimaciones de glucosa, lípidos o ácido úrico", systemImage: "info.circle")
                    Text("HRV solo si consta el método SDNN. La HRV genérica del SDK no se convierte a SDNN.")
                    Text("La deduplicación identifica registros de Bridge. No garantiza detectar copias que otra app haya enviado con identificadores distintos.")
                }.font(.footnote)
            }.navigationTitle("Salud de Apple")
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var veepoo: VeepooCapabilityProbe
    @EnvironmentObject var bluetooth: BluetoothScanner
    @AppStorage("recordingTimeZone") private var zone = TimeZone.current.identifier
    var body: some View {
        NavigationStack {
            Form {
                Section("Conexión") {
                    Toggle("Reconexión automática con el SDK", isOn: $veepoo.automaticReconnect)
                    Text("Actúa durante la sesión de la app. La ejecución permanente en segundo plano no está validada.").font(.caption)
                }
                Section("Fechas del historial") {
                    Picker("Zona del reloj", selection: $zone) {
                        ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0).tag($0) }
                    }
                    Text("Usa la zona donde se registraron las mediciones. Los viajes y la hora repetida del cambio de horario requieren revisión.").font(.caption)
                }
                Section("Privacidad") {
                    Label("Historial local protegido al bloquear el iPhone", systemImage: "lock.shield")
                    Text("El historial gestionado por Bridge se excluye de las copias de seguridad. Exportarlo crea un archivo con datos sanitarios que tú decides compartir.").font(.caption)
                    Text("El borrado local de Bridge no borra Salud ni la base interna del SDK.").font(.caption)
                }
                Section("Diagnóstico Bluetooth independiente") {
                    LabeledContent("Bluetooth", value: bluetooth.status)
                    Button(bluetooth.scanning ? "Detener búsqueda" : "Buscar servicios BLE") { veepoo.disconnect(); bluetooth.toggleScan() }
                    ForEach(bluetooth.devices) { device in
                        Button("\(device.name) · \(device.rssi) dBm") { bluetooth.connect(to: device.id) }
                    }
                    Text(bluetooth.connectionStatus).font(.caption)
                    ForEach(bluetooth.services, id: \.self) { Text($0).font(.caption) }
                    Button("Desconectar diagnóstico") { bluetooth.disconnect() }
                }
                Section("Acerca de") {
                    LabeledContent("Versión candidata", value: "0.3")
                    Text("A2 · firmware objetivo 02.52.01.00-5982")
                    Text("Sin validación física. Las capacidades mostradas proceden del reloj cuando se conecta, no de una lista de funciones supuestas.").font(.caption)
                }
            }.navigationTitle("Ajustes")
                .onAppear { veepoo.recordingTimeZone = TimeZone(identifier: zone) ?? .current }
                .onChange(of: zone) { _, value in veepoo.recordingTimeZone = TimeZone(identifier: value) ?? .current }
        }
    }
}

struct MeasurementChart: View {
    let records: [Measurement]
    @State private var kind = Measurement.Kind.heartRate
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Métrica", selection: $kind) {
                ForEach(Measurement.Kind.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            let samples = Array(records.filter { $0.kind == kind }.prefix(500)).sorted { $0.start < $1.start }
            if samples.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "chart.xyaxis.line").font(.largeTitle).foregroundStyle(.teal)
                    Text("Tus tendencias aparecerán aquí").font(.subheadline)
                    Text("Sin mediciones de esta categoría").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).frame(height: 150)
            } else {
                Chart(samples) { sample in
                    PointMark(x: .value("Fecha", sample.start), y: .value("Valor", sample.value))
                }.frame(height: 180).foregroundStyle(.teal)
                Text("Hasta 500 muestras. Oxígeno en fracción 0–1; temperatura en °C; frecuencia en lpm; pasos por intervalo.").font(.caption)
            }
        }
    }
}
