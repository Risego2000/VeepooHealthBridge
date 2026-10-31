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
            let data = try Data(contentsOf: url)
            let envelope = try JSONDecoder.iso8601.decode(ImportEnvelope.self, from: data)
            guard envelope.schemaVersion == 1 else { message = "Versión de esquema desconocida"; return }
            guard envelope.measurements.count <= 100_000 else { message = "Archivo demasiado grande"; return }
            var byID = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { old, _ in old })
            let originalCount = byID.count
            for record in envelope.measurements {
                guard !record.id.isEmpty, record.value.isFinite, record.end >= record.start,
                    record.start.timeIntervalSince1970 > 946684800,
                    record.end < Date().addingTimeInterval(86400),
                    record.source.count <= 160 else { continue }
                // Preserve existing values on duplicate identifiers.
                if byID[record.id] == nil { byID[record.id] = record }
            }
            records = Array(byID.values).sorted { $0.start > $1.start }
            persist()
            message = "Importados \(records.count - originalCount) registros nuevos"
        } catch { message = "No se pudo leer JSON: \(error.localizedDescription)" }
    }

    func deleteAll() { records = []; persist(); message = "Archivo local vaciado" }

    func exportJSON() throws -> URL {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("VeepooBridge-export.json")
        let data = try JSONEncoder.prettyISO8601.encode(ImportEnvelope(schemaVersion: 1, device: "A2", measurements: records))
        try data.write(to: output, options: .atomic)
        return output
    }

    private func persist() {
        do { try JSONEncoder.prettyISO8601.encode(records).write(to: fileURL, options: .atomic) }
        catch { message = "Error al guardar: \(error.localizedDescription)" }
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
