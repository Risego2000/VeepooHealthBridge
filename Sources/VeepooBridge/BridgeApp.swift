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
                .environmentObject(health).environmentObject(measurements).tint(.orange).preferredColorScheme(.light)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var veepoo: VeepooCapabilityProbe
    @EnvironmentObject var measurements: MeasurementStore
    @EnvironmentObject var health: HealthBridge
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("syncVerifiedAutomatically") private var syncAutomatically = false
    @State private var tab = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--screen=") })?.replacingOccurrences(of: "--screen=", with: "") ?? "home"
    var body: some View {
        TabView(selection: $tab) {
            DashboardView().tabItem { Label("Salud", systemImage: "heart.text.square.fill") }.tag("home")
            DeviceView().tabItem { Label("Dispositivo", systemImage: "applewatch") }.tag("device")
            ProfileView().tabItem { Label("Perfil", systemImage: "person.crop.circle") }.tag("settings")
        }
        .onChange(of: veepoo.historyRevision) { _, _ in
            veepoo.extractHeartRatePreview()
            measurements.addSDKPreview(veepoo.extractedMeasurements)
        }
        .onChange(of: measurements.records) { _, records in
            if syncAutomatically { health.sync(records) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && syncAutomatically { health.sync(measurements.records) }
        }
    }
}

enum BandTheme {
    static let background = Color(red: 0.96, green: 0.97, blue: 0.98)
    static let accent = Color(red: 1, green: 0.49, blue: 0.12)
}

struct DashboardView: View {
    @EnvironmentObject var measurements: MeasurementStore
    @EnvironmentObject var veepoo: VeepooCapabilityProbe
    @State private var selectedDay = Date()
    @AppStorage("dailyStepGoal") private var goal = 8000
    private var today: [Measurement] { measurements.records.filter { Calendar.current.isDate($0.start, inSameDayAs: selectedDay) } }
    private var steps: Double { today.filter { $0.kind == .steps }.reduce(0) { $0 + $1.value } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        Text("Veepoo Bridge").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        DatePicker("Día", selection: $selectedDay, in: ...Date(), displayedComponents: .date).labelsHidden()
                    }
                    activitySummary
                    NavigationLink { HistoryView() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.walk.circle.fill").font(.title).foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack { Text("Actividad diaria").font(.headline); Spacer(); Image(systemName: "chevron.right").font(.caption) }
                                ProgressView(value: min(steps / Double(max(goal, 1)), 1)).tint(.blue)
                                Text(today.contains(where: { $0.kind == .steps }) ? "Objetivo: \(goal) pasos" : "Sin actividad descargada del reloj").font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain)
                    HStack {
                        Label("Datos de salud", systemImage: "heart.text.square.fill").font(.headline)
                        Spacer()
                        Text(veepoo.ready ? "Conectado" : "Sin conectar").font(.caption).foregroundStyle(.secondary)
                    }.padding(.top, 6)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach([Measurement.Kind.sleepAsleep, .heartRate, .hrvSDNN, .oxygenFraction, .bodyTemperatureC, .systolic, .bodyFatFraction, .leanMassKg, .bodyMassIndex, .respiratoryRate], id: \.self) { kind in
                            NavigationLink { BandMetricDetail(kind: kind) } label: { BandMetricCard(kind: kind, records: today) }.buttonStyle(.plain)
                        }
                    }
                    NavigationLink { CardiacDataView() } label: {
                        HStack {
                            Image(systemName: "waveform.path.ecg").font(.title2).foregroundStyle(BandTheme.accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("ECG y VFC originales").font(.headline)
                                Text("Trazados, intervalos y datos del fabricante").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain)
                    Text("Sin datos inventados. Cada tarjeta muestra únicamente registros locales de la fecha elegida.").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                }.padding(16)
            }.background(BandTheme.background)
                .navigationTitle("Salud").navigationBarTitleDisplayMode(.inline)
                .toolbar { NavigationLink { HistoryView() } label: { Image(systemName: "clock.arrow.circlepath") } }
        }
    }
    private var activitySummary: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().stroke(BandTheme.accent.opacity(0.12), lineWidth: 12)
                Circle().trim(from: 0, to: min(steps / Double(max(goal, 1)), 1)).stroke(BandTheme.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: 3) {
                    Text(today.contains(where: { $0.kind == .steps }) ? steps.formatted(.number.precision(.fractionLength(0))) : "—").font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text("/ \(goal) pasos").font(.caption).foregroundStyle(.secondary)
                    Image(systemName: "shoeprints.fill").foregroundStyle(BandTheme.accent)
                }
            }.frame(width: 140, height: 140).padding(.top, 12)
            HStack {
                activityValue("Calorías", kind: .activeEnergyKcal, unit: "kcal")
                Divider().frame(height: 35)
                VStack(spacing: 5) { Text("Pasos").font(.caption).foregroundStyle(.secondary); Text(steps > 0 ? steps.formatted(.number.precision(.fractionLength(0))) : "—").font(.headline) }.frame(maxWidth: .infinity)
                Divider().frame(height: 35)
                activityValue("Distancia", kind: .walkingRunningMeters, unit: "km")
            }
        }.padding(20).frame(maxWidth: .infinity).background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
    private func activityValue(_ title: String, kind: Measurement.Kind, unit: String) -> some View {
        let rows = today.filter { $0.kind == kind }
        let value = rows.reduce(0) { $0 + $1.value } / (kind == .walkingRunningMeters ? 1000 : 1)
        return VStack(spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(rows.isEmpty ? "—" : value.formatted(.number.precision(.fractionLength(1))) + " " + unit).font(.headline)
        }.frame(maxWidth: .infinity)
    }
}

struct BandMetricCard: View {
    let kind: Measurement.Kind
    let records: [Measurement]
    private var rows: [Measurement] { records.filter { $0.kind == kind }.sorted { $0.start > $1.start } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: symbol).foregroundStyle(color)
                Text(kind == .hrvSDNN ? "VFC · SDNN" : kind.title).font(.subheadline.weight(.medium)).lineLimit(2)
                Spacer(minLength: 0)
            }
            if let m = rows.first {
                Text(display(m)).font(.title2.bold()).foregroundStyle(.primary).minimumScaleFactor(0.7).lineLimit(1)
                Text(m.start.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Sin datos").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
                Text("Pendiente de lectura").font(.caption).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }.padding(16).frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading).background(.white, in: RoundedRectangle(cornerRadius: 18))
    }
    private var symbol: String {
        switch kind {
        case .sleepAsleep: return "bed.double.fill"
        case .oxygenFraction, .respiratoryRate: return "lungs.fill"
        case .bodyTemperatureC: return "thermometer.medium"
        case .hrvSDNN: return "waveform.path"
        case .heartRate, .systolic, .diastolic: return "heart.fill"
        default: return "figure.stand"
        }
    }
    private var color: Color {
        switch kind {
        case .sleepAsleep: return .purple
        case .oxygenFraction, .respiratoryRate: return .cyan
        case .bodyTemperatureC: return .orange
        case .heartRate, .hrvSDNN, .systolic, .diastolic: return .pink
        default: return .blue
        }
    }
    private func display(_ m: Measurement) -> String {
        switch kind {
        case .sleepAsleep:
            let minutes = rows.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) } / 60
            return "\(Int(minutes) / 60) h \(Int(minutes) % 60) min"
        case .heartRate: return m.value.formatted() + " lpm"
        case .hrvSDNN: return m.value.formatted() + " ms"
        case .oxygenFraction, .bodyFatFraction: return (m.value * 100).formatted(.number.precision(.fractionLength(1))) + " %"
        case .bodyTemperatureC: return m.value.formatted() + " °C"
        case .systolic, .diastolic: return m.value.formatted() + " mmHg"
        case .leanMassKg: return m.value.formatted() + " kg"
        case .respiratoryRate: return m.value.formatted() + " /min"
        default: return m.value.formatted()
        }
    }
}

struct BandMetricDetail: View {
    let kind: Measurement.Kind
    @EnvironmentObject var measurements: MeasurementStore
    var body: some View {
        List {
            Section { MeasurementChart(records: measurements.records, kind: kind) }
            Section("Registros originales") {
                ForEach(measurements.records.filter { $0.kind == kind }.prefix(200)) { m in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(m.value.formatted()) · \(m.start.formatted())")
                        Text(m.method).font(.caption).foregroundStyle(.secondary)
                        Text(m.validated ? "Verificado por ti" : "Pendiente de verificación").font(.caption)
                    }
                }
            }
        }.navigationTitle(kind.title).navigationBarTitleDisplayMode(.inline)
    }
}

struct ProfileView: View {
    @AppStorage("dailyStepGoal") private var goal = 8000
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 48)).foregroundStyle(BandTheme.accent)
                        VStack(alignment: .leading) { Text("Veepoo Bridge").font(.headline); Text("Tus datos, en tu iPhone").font(.subheadline).foregroundStyle(.secondary) }
                    }.padding(.vertical, 8)
                }
                Section("Mi salud") {
                    NavigationLink("Historial y archivos") { HistoryView() }
                    NavigationLink("Salud de Apple") { HealthView() }
                    NavigationLink("ECG y VFC originales") { CardiacDataView() }
                }
                Section("Objetivo de actividad") {
                    Stepper("\(goal) pasos al día", value: $goal, in: 1000...50000, step: 500)
                    Text("Es un objetivo configurable, no una medición del reloj.").font(.caption)
                }
                Section { NavigationLink("Configuración y diagnóstico") { SettingsView() } }
            }.navigationTitle("Perfil").navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct CardiacDataView: View {
    @EnvironmentObject var veepoo: VeepooCapabilityProbe
    @State private var archive = false
    var body: some View {
        List {
            Section("ECG · registro original") {
                Label("El trazado se conserva en Bridge", systemImage: "waveform.path.ecg").foregroundStyle(BandTheme.accent)
                Text("Salud no permite crear una muestra ECG de terceros. Puedes examinar y compartir el archivo original del SDK.").font(.footnote)
                Button("Preparar datos cardíacos del SDK") { veepoo.exportSDKArchive() }.disabled(!veepoo.ready || veepoo.reading)
                if let url = veepoo.archiveURL {
                    Button("Examinar trazados e intervalos originales") { archive = true }
                    ShareLink("Compartir archivo original", item: url)
                }
            }
            Section("VFC · método de cálculo") {
                Text("SDNN se envía como SDNN. El valor HRV genérico del fabricante no se renombra ni se convierte a SDNN.")
                Text("El SDK dispone de campos SDNN y RMSSD en su informe ECG. Su disponibilidad en el A2 y las condiciones de acceso del fabricante necesitan comprobación.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Estado de lectura") { Text(veepoo.historyStatus).font(.caption) }
        }.navigationTitle("ECG y VFC").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $archive) { if let url = veepoo.archiveURL { RawArchiveView(url: url) } }
    }
}

struct DeviceView: View {
    @State private var password = "0000"
    @State private var showingRawArchive = false
    @EnvironmentObject var veepoo: VeepooCapabilityProbe
    @EnvironmentObject var measurements: MeasurementStore
    @EnvironmentObject var bluetooth: BluetoothScanner
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(veepoo.ready ? "Reloj preparado" : "Conecta tu reloj", systemImage: "applewatch.radiowaves.left.and.right").font(.title3.bold())
                    Text(veepoo.status).foregroundStyle(.secondary)
                    SecureField("Contraseña del reloj (4 cifras)", text: $password).keyboardType(.numberPad)
                    Button("Buscar reloj con Veepoo", systemImage: "antenna.radiowaves.left.and.right") { bluetooth.disconnect(); veepoo.scan() }
                    ForEach(Array(veepoo.discovered.enumerated()), id: \.offset) { index, label in
                        Button(label) { veepoo.connect(index: index, password: password) }
                    }
                    Button("Desconectar", role: .destructive) { veepoo.disconnect() }
                } header: { Text("Conexión oficial SDK") } footer: { Text("Libera la conexión de G Band antes de buscar. El SDK verifica la contraseña del reloj antes de permitir la lectura.") }
                Section("Recuperar mediciones") {
                    Button("Leer historial del reloj", systemImage: "arrow.down.circle") { veepoo.readHistoryDiagnostic() }.disabled(!veepoo.ready || veepoo.reading)
                    Button("Leer mediciones manuales del reloj") { veepoo.readManualHistory() }
                        .disabled(!veepoo.ready || veepoo.reading)
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
                    if let url = veepoo.archiveURL {
                        Button("Examinar todas las categorías del archivo") { showingRawArchive = true }
                        ShareLink("Compartir datos sanitarios brutos", item: url)
                    }
                    Text("El archivo conserva HRV sin método SDNN, sueño preciso y presión con nombres de campos ambiguos. No se envían a Salud.").font(.caption)
                    Button("Inspeccionar recuentos") { veepoo.inspectSDKDatabase() }
                    ForEach(veepoo.databaseSummary, id: \.self) { Text($0).font(.caption) }
                }
            }.navigationTitle("Tu reloj")
                .sheet(isPresented: $showingRawArchive) {
                    if let url = veepoo.archiveURL { RawArchiveView(url: url) }
                }
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject var veepoo: VeepooCapabilityProbe
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
                    Button("Borrar", role: .destructive) {
                        measurements.deleteAll()
                        if !veepoo.deleteManualRecords() { measurements.message = veepoo.historyStatus }
                    }
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
    @AppStorage("syncVerifiedAutomatically") private var syncAutomatically = false
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
                    Toggle("Enviar automáticamente las muestras verificadas", isOn: $syncAutomatically)
                    Text(health.lastResults).font(.caption)
                    ForEach(Array(health.details.suffix(30).enumerated()), id: \.offset) { _, detail in
                        Text(detail).font(.caption).foregroundStyle(.secondary)
                    }
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
                    Text("Se declara el modo Bluetooth en segundo plano para la conexión existente. iOS controla su ejecución; no se garantiza tras cierre forzado.").font(.caption)
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
                    LabeledContent("Versión candidata", value: "0.5")
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
    init(records: [Measurement], kind: Measurement.Kind = .heartRate) {
        self.records = records
        _kind = State(initialValue: kind)
    }
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


/// Read-only presentation of real vendor records, including fields with no HealthKit equivalent.
struct RawArchiveView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var object: [String: Any] = [:]
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Datos originales del SDK. Los nombres y valores del fabricante no constituyen un diagnóstico ni implican que puedan enviarse a Salud.").font(.footnote)
                    if let error { Text(error).foregroundStyle(.red) }
                }
                ForEach(object.keys.sorted(), id: \.self) { key in
                    RawJSONNode(label: key, value: object[key] ?? NSNull(), depth: 0)
                }
            }.navigationTitle("Datos originales")
                .toolbar { Button("Cerrar") { dismiss() } }
                .task {
                    do {
                        let data = try Data(contentsOf: url)
                        object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                    } catch { self.error = error.localizedDescription }
                }
        }
    }
}

struct RawJSONNode: View {
    let label: String
    let value: Any
    let depth: Int
    @State private var limit = 50
    var body: some View {
        Group {
            if depth >= 12 {
                Text("\(label): nivel máximo de visualización; consulta el archivo exportado").font(.caption)
            } else if let dictionary = value as? [String: Any] {
                DisclosureGroup("\(label) · \(dictionary.count) campos") {
                    ForEach(Array(dictionary.keys.sorted().prefix(limit)), id: \.self) { key in
                        AnyView(RawJSONNode(label: key, value: dictionary[key] ?? NSNull(), depth: depth + 1))
                    }
                    if dictionary.count > limit { Button("Mostrar más campos") { limit += 50 } }
                }
            } else if let array = value as? [Any] {
                DisclosureGroup("\(label) · \(array.count) elementos") {
                    ForEach(0..<min(limit, array.count), id: \.self) { index in
                        AnyView(RawJSONNode(label: "[\(index)]", value: array[index], depth: depth + 1))
                    }
                    if array.count > limit { Button("Mostrar 50 elementos más") { limit += 50 } }
                }
            } else {
                VStack(alignment: .leading) {
                    Text(label).font(.caption).foregroundStyle(.secondary)
                    Text(String(describing: value)).textSelection(.enabled)
                }
            }
        }
    }
}
