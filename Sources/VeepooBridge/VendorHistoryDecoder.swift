import Foundation

/// Decodes only fields documented in VPDataBaseOperation.h at the pinned vendor revision.
/// Time zone must describe the watch's recording zone, not an assumed UTC offset.
struct VendorHistoryDecoder {
    let device: String
    let timeZone: TimeZone
    var now = Date()

    private func date(_ text: String, format: String = "yyyy-MM-dd HH:mm") -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = timeZone
        f.dateFormat = format
        f.isLenient = false
        guard let date = f.date(from: text), f.string(from: date) == text else { return nil }
        return date
    }

    private func number(_ value: Any?) -> Double? {
        if let string = value as? String { return Double(string) }
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() { return number.doubleValue }
        return nil
    }

    private func sample(_ kind: Measurement.Kind, _ value: Double, _ start: Date, _ end: Date, _ method: String) -> Measurement? {
        let m = Measurement(id: "veepoo-\(device)-\(kind.rawValue)-\(Int(start.timeIntervalSince1970))-\(Int(end.timeIntervalSince1970))",
            kind: kind, value: value, start: start, end: end, source: "Veepoo \(device)",
            method: method, validated: false, note: "Zona de registro: \(timeZone.identifier). Pendiente de cotejo físico.")
        return MeasurementValidation.accepts(m, now: now) ? m : nil
    }

    func original(day: String, rows: [String: Any]) -> [Measurement] {
        rows.sorted { $0.key < $1.key }.compactMap { time, fields in
            guard let fields = fields as? [String: Any], let value = number(fields["heartValue"]),
                  let instant = date(day + " " + time) else { return nil }
            return sample(.heartRate, value, instant, instant, "SDK original-data heartValue")
        }
    }

    /// Vendor documents each half-hour key as the start of a non-overlapping sum.
    func halfHourSteps(day: String, rows: [String: Any]) -> [Measurement] {
        rows.compactMap { time, fields in
            guard let fields = fields as? [String: Any], let value = number(fields["stepValue"]),
                  let start = date(day + " " + time), time.hasSuffix(":00") || time.hasSuffix(":30") else { return nil }
            return sample(.steps, value, start, start.addingTimeInterval(1800), "SDK half-hour step sum")
        }
    }

    func oxygen(day: String, rows: [[String: Any]]) -> [Measurement] {
        rows.compactMap { row in
            guard let time = row["Time"] as? String, let instant = date(day + " " + time),
                  let value = number(row["OxygenValue"]), (50...100).contains(value) else { return nil }
            return sample(.oxygenFraction, value / 100, instant, instant, "SDK OxygenValue percent")
        }
    }

    func temperature(day: String, rows: [[String: Any]]) -> [Measurement] {
        rows.compactMap { row in
            guard let hour = number(row["hour"]), let minute = number(row["minute"]),
                  hour.rounded() == hour, minute.rounded() == minute,
                  (0...23).contains(hour), (0...59).contains(minute),
                  let value = number(row["value"]),
                  let instant = date(day + String(format: " %02d:%02d", Int(hour), Int(minute))) else { return nil }
            // Only body temperature may be verified for HealthKit; sensor location needs hardware confirmation.
            return sample(.bodyTemperatureC, value, instant, instant, "SDK temperature Celsius; sensor location unconfirmed")
        }
    }

    func bodyComposition(rows: [[String: Any]]) -> [Measurement] {
        rows.flatMap { row -> [Measurement] in
            guard let day = row["date"] as? String, let time = row["testTime"] as? String,
                  let instant = date(day + " " + time, format: "yyyy-MM-dd HH:mm:ss") else { return [] }
            var result: [Measurement] = []
            if let percent = number(row["bodyFatPercentage"]), percent > 0,
               let m = sample(.bodyFatFraction, percent / 100, instant, instant, "SDK estimated body composition percent") { result.append(m) }
            if let kg = number(row["leanBodyMass"]),
               let m = sample(.leanMassKg, kg, instant, instant, "SDK estimated lean mass kg") { result.append(m) }
            if let bmi = number(row["bmi"]),
               let m = sample(.bodyMassIndex, bmi, instant, instant, "SDK estimated BMI; profile-derived") { result.append(m) }
            // weight/stature/gender are profile inputs, not measurements provided by the SDK.
            return result
        }
    }

    func accurateSleep(rows: [[String: Any]]) -> [Measurement] {
        rows.flatMap { row -> [Measurement] in
            guard let beginText = row["sleepTime"] as? String, let endText = row["wakeTime"] as? String,
                  let begin = date(beginText, format: "yyyy/MM/dd HH:mm") ?? date(beginText),
                  let end = date(endText, format: "yyyy/MM/dd HH:mm") ?? date(endText),
                  let duration = number(row["onePointDuration"]), duration > 0, duration <= 300,
                  let hex = row["sleepLine"] as? String, !hex.isEmpty, hex.count <= 23040,
                  hex.count % 4 == 0, hex.allSatisfy({ $0.isHexDigit }),
                  abs(end.timeIntervalSince(begin) - Double(hex.count / 4) * duration) < 1 else { return [] }
            let chars = Array(hex)
            var output: [Measurement] = []
            for offset in stride(from: 0, to: chars.count, by: 4) {
                guard let word = UInt16(String(chars[offset..<offset+4]), radix: 16) else { return [] }
                let state = word >> 13
                guard state <= 4 else { return [] }
                // Vendor: deep 0, light 1, REM 2, insomnia 3, awake 4.
                // Keep only unspecified sleep; no equivalence to Apple's sleep-stage algorithms.
                if state <= 2 {
                    let start = begin.addingTimeInterval(Double(offset / 4) * duration)
                    if let m = sample(.sleepAsleep, 1, start, start.addingTimeInterval(duration), "SDK accurate sleep; stages not equated to Apple") { output.append(m) }
                }
            }
            return output
        }
    }

    func ordinarySleep(rows: [[String: Any]]) -> [Measurement] {
        rows.flatMap { row -> [Measurement] in
            guard let text = row["SLEEP_TIME"] as? String, let start = date(text, format: "yyyy/MM/dd HH:mm"),
                  let wakeText = row["WAKE_TIME"] as? String, let wake = date(wakeText, format: "yyyy/MM/dd HH:mm"),
                  let line = row["SLE_LINE"] as? String, !line.isEmpty, line.count <= 288,
                  line.allSatisfy({ "012".contains($0) }),
                  abs(wake.timeIntervalSince(start) - Double(line.count) * 300) < 1 else { return [] }
            // Preserve awakenings. Do not equate the vendor's deep/light stages to Apple's stages.
            return line.enumerated().compactMap { offset, stage in
                guard stage != "2" else { return nil }
                let begin = start.addingTimeInterval(Double(offset) * 300)
                return sample(.sleepAsleep, 1, begin, begin.addingTimeInterval(300), "SDK ordinary sleep 5-minute segment")
            }
        }
    }
}
import CoreFoundation

/// Offline numerical analysis only. Never assumes raw RR are normal-to-normal intervals.
/// The caller must establish units, normal-beat classification and continuity first.
struct NNIntervalAnalysis {
    let sdnnMilliseconds: Double
    let rmssdMilliseconds: Double
    let durationSeconds: Double
    let count: Int

    static func calculate(milliseconds: [Double], normalBeatsConfirmed: Bool, continuous: Bool) -> NNIntervalAnalysis? {
        guard normalBeatsConfirmed, continuous, milliseconds.count >= 30,
              milliseconds.count <= 100_000,
              milliseconds.allSatisfy({ $0.isFinite && (250...2500).contains($0) }) else { return nil }
        let total = milliseconds.reduce(0, +)
        guard total >= 60_000, total <= 86_400_000 else { return nil }
        let mean = total / Double(milliseconds.count)
        let variance = milliseconds.reduce(0) { $0 + pow($1 - mean, 2) } / Double(milliseconds.count - 1)
        let squaredDifferences = zip(milliseconds.dropFirst(), milliseconds).reduce(0) { $0 + pow($1.0 - $1.1, 2) }
        return NNIntervalAnalysis(sdnnMilliseconds: sqrt(variance),
            rmssdMilliseconds: sqrt(squaredDifferences / Double(milliseconds.count - 1)),
            durationSeconds: total / 1000, count: milliseconds.count)
    }
}
