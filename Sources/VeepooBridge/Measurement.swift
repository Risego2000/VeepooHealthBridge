import Foundation
import CryptoKit

// Values are never manufactured; only imported from a genuine source.
struct Measurement: Codable, Identifiable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case heartRate, hrvSDNN, steps, weightKg, bodyFatFraction, leanMassKg
        case bodyMassIndex, respiratoryRate, walkingRunningMeters, activeEnergyKcal
        case oxygenFraction, bodyTemperatureC, systolic, diastolic, sleepAsleep
        case ecgWaveform, qtMilliseconds, uricAcidEstimate, lipidEstimate, glucoseEstimate
        var title: String {
            switch self {
            case .bodyMassIndex: return "Índice de masa corporal"
            case .respiratoryRate: return "Frecuencia respiratoria"
            case .walkingRunningMeters: return "Distancia caminando/corriendo"
            case .activeEnergyKcal: return "Energía activa"
            case .heartRate: return "Frecuencia cardíaca"
            case .hrvSDNN: return "HRV SDNN"
            case .steps: return "Pasos"
            case .weightKg: return "Peso"
            case .bodyFatFraction: return "Grasa corporal"
            case .leanMassKg: return "Masa magra"
            case .oxygenFraction: return "Oxígeno"
            case .bodyTemperatureC: return "Temperatura"
            case .systolic: return "Tensión sistólica"
            case .diastolic: return "Tensión diastólica"
            case .sleepAsleep: return "Sueño"
            case .ecgWaveform: return "ECG"
            case .qtMilliseconds: return "QT"
            case .uricAcidEstimate: return "Ácido úrico estimado"
            case .lipidEstimate: return "Lípidos estimados"
            case .glucoseEstimate: return "Glucosa estimada"
            }
        }
        var writable: Bool {
            switch self {
            case .ecgWaveform, .qtMilliseconds, .uricAcidEstimate, .lipidEstimate, .glucoseEstimate: return false
            default: return true
            }
        }
    }
    var id: String  // stable sample identifier provided by source
    var kind: Kind
    var value: Double
    var start: Date
    var end: Date
    var source: String
    var method: String // SDNN required for HRV; never equate RMSSD to SDNN
    var validated: Bool // user verification against an independent reference, where applicable
    var note: String?

    /// Identity of one source interval, independent of an importer's mutable external ID.
    var syncIdentity: String {
        let parts = [source, kind.rawValue, String(start.timeIntervalSince1970), String(end.timeIntervalSince1970)]
        let bytes = (try? JSONEncoder().encode(parts)) ?? Data()
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}

struct ImportEnvelope: Codable {
    var schemaVersion: Int
    var device: String
    var measurements: [Measurement]
}

/// Structural and semantic checks shared by import, storage and HealthKit.
enum MeasurementValidation {
    static func accepts(_ m: Measurement, now: Date = Date()) -> Bool {
        guard !m.id.isEmpty, m.id.utf8.count <= 512, !m.source.isEmpty,
              m.source.count <= 160, m.method.count <= 256,
              m.value.isFinite, m.end >= m.start,
              m.start.timeIntervalSince1970 > 946684800, m.end <= now,
              (m.note?.count ?? 0) <= 4096 else { return false }
        switch m.kind {
        case .bodyMassIndex: return (5...100).contains(m.value)
        case .respiratoryRate: return (3...80).contains(m.value)
        case .walkingRunningMeters: return (0...300000).contains(m.value) && m.end > m.start
        case .activeEnergyKcal: return (0...20000).contains(m.value) && m.end > m.start
        case .heartRate: return (25...240).contains(m.value)
        case .hrvSDNN: return m.method.lowercased() == "sdnn" && (1...300).contains(m.value)
        case .steps: return (0...100000).contains(m.value) && m.value.rounded() == m.value && m.end > m.start
        case .weightKg: return (10...350).contains(m.value)
        case .bodyFatFraction: return (0...1).contains(m.value)
        case .oxygenFraction: return (0.5...1).contains(m.value)
        case .leanMassKg: return (1...250).contains(m.value)
        case .bodyTemperatureC: return (30...44).contains(m.value)
        case .systolic: return (60...260).contains(m.value)
        case .diastolic: return (30...160).contains(m.value)
        case .sleepAsleep: return m.end > m.start && m.end.timeIntervalSince(m.start) <= 86400
        default: return false
        }
    }

    static func merge(_ existing: [Measurement], incoming: [Measurement], now: Date = Date()) -> [Measurement] {
        var byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { old, _ in old })
        var intervals = Set(existing.map(\.syncIdentity))
        for var record in incoming where accepts(record, now: now) && byID[record.id] == nil {
            guard intervals.insert(record.syncIdentity).inserted else { continue }
            // Trust is established inside the app, never by a JSON file or SDK callback.
            record.validated = false
            byID[record.id] = record
        }
        return byID.values.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start > $1.start }
    }
}
