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
