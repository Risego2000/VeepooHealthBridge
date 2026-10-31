import Foundation

// Values are never manufactured; only imported from a genuine source.
struct Measurement: Codable, Identifiable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case heartRate, hrvSDNN, steps, weightKg, bodyFatFraction, leanMassKg
        case oxygenFraction, bodyTemperatureC, systolic, diastolic, sleepAsleep
        case ecgWaveform, qtMilliseconds, uricAcidEstimate, lipidEstimate, glucoseEstimate
        var title: String {
            switch self {
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
}

struct ImportEnvelope: Codable {
    var schemaVersion: Int
    var device: String
    var measurements: [Measurement]
}
