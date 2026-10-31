import Foundation

@MainActor final class MeasurementStore: ObservableObject {
    @Published private(set) var records: [Measurement] = []
    @Published var message = "Sin importaciones"
    private let fileURL: URL

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("measurements.json")
        if let bytes = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder.iso8601.decode([Measurement].self, from: bytes) {
            records = decoded
        }
    }

    func importJSON(_ url: URL) {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 20_000_000 else { message = "Archivo superior a 20 MB"; return }
            let data = try Data(contentsOf: url)
            let envelope = try JSONDecoder.iso8601.decode(ImportEnvelope.self, from: data)
            guard envelope.schemaVersion == 1 else { message = "Versión de esquema desconocida"; return }
            guard envelope.measurements.count <= 100_000 else { message = "Archivo demasiado grande"; return }
            let originalCount = records.count
            let updated = MeasurementValidation.merge(records, incoming: envelope.measurements)
            try commit(updated)
            message = "Importados \(records.count - originalCount) registros nuevos sin verificar"

        } catch { message = "No se pudo leer JSON: \(error.localizedDescription)" }
    }

    func addSDKPreview(_ samples: [Measurement]) {
        do {
            let oldCount = records.count
            try commit(MeasurementValidation.merge(records, incoming: samples))
            message = "SDK: \(records.count - oldCount) muestras nuevas sin verificar"
        } catch { message = "No se guardaron las muestras: \(error.localizedDescription)" }
    }

    func verify(id: String) {
        guard let index = records.firstIndex(where: { $0.id == id }),
              MeasurementValidation.accepts(records[index]) else { return }
        var updated = records
        updated[index].validated = true
        do { try commit(updated); message = "Registro verificado por el usuario" }
        catch { message = "No se pudo guardar la verificación" }
    }

    func deleteAll() {
        do { try commit([]); message = "Historial local vaciado" }
        catch { message = "No se pudo borrar el historial" }
    }

    func exportJSON() throws -> URL {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("VeepooBridge-export.json")
        let data = try JSONEncoder.prettyISO8601.encode(ImportEnvelope(schemaVersion: 1, device: "A2", measurements: records))
        try data.write(to: output, options: [.atomic, .completeFileProtection])
        return output
    }

    private func commit(_ updated: [Measurement]) throws {
        try JSONEncoder.prettyISO8601.encode(updated).write(to: fileURL, options: [.atomic, .completeFileProtection])
        var resource = fileURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try resource.setResourceValues(values)
        records = updated
    }

}

extension JSONDecoder {
    static var iso8601: JSONDecoder { let coder = JSONDecoder(); coder.dateDecodingStrategy = .iso8601; return coder }
}
extension JSONEncoder {
    static var prettyISO8601: JSONEncoder {
        let coder = JSONEncoder(); coder.dateEncodingStrategy = .iso8601
        coder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return coder
    }
}
