import XCTest
@testable import BridgeCore

final class BridgeCoreTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1793404800)
    func measurement(_ value: Double = 70) -> BridgeCore.Measurement {
        BridgeCore.Measurement(id: "fixture", kind: .heartRate, value: value, start: now.addingTimeInterval(-600), end: now.addingTimeInterval(-600), source: "unit-test fixture", method: "fixture", validated: true)
    }
    func testRejectsNonFiniteAndOutOfRange() {
        for value in [Double.nan, Double.infinity, -1, 0, 241] {
            XCTAssertFalse(MeasurementValidation.accepts(measurement(value), now: now))
        }
    }
    func testRejectsFutureAndReversedDates() {
        var m = measurement(); m.end = now.addingTimeInterval(1)
        XCTAssertFalse(MeasurementValidation.accepts(m, now: now))
        m.end = m.start.addingTimeInterval(-1)
        XCTAssertFalse(MeasurementValidation.accepts(m, now: now))
    }
    func testImportNeverTrustsValidationAndKeepsExisting() {
        let m = measurement()
        let imported = MeasurementValidation.merge([], incoming: [m, m], now: now)
        XCTAssertEqual(imported.count, 1); XCTAssertFalse(imported[0].validated)
        var different = m; different.value = 90
        XCTAssertEqual(MeasurementValidation.merge([m], incoming: [different], now: now)[0].value, 70)
    }
    func testHRVRequiresSDNN() {
        var m = measurement(); m.kind = .hrvSDNN; m.method = "RMSSD"
        XCTAssertFalse(MeasurementValidation.accepts(m, now: now))
        m.method = "SDNN"; XCTAssertTrue(MeasurementValidation.accepts(m, now: now))
    }
    func testOriginalRejectsMalformedAndBoolean() {
        let d = VendorHistoryDecoder(device: "fixture", timeZone: TimeZone(secondsFromGMT: 0)!, now: now)
        let rows: [String: Any] = ["12:00": ["heartValue": "72"], "25:00": ["heartValue": 70], "12:05": ["heartValue": true], "12:10": ["heartValue": 0]]
        let result = d.original(day: "2026-10-30", rows: rows)
        XCTAssertEqual(result.count, 1); XCTAssertEqual(result.first?.value, 72)
        XCTAssertFalse(result[0].validated)
        XCTAssertEqual(result[0].id, d.original(day: "2026-10-30", rows: rows)[0].id)
    }
    func testOxygenConvertsPercentOnce() {
        let d = VendorHistoryDecoder(device: "fixture", timeZone: TimeZone(secondsFromGMT: 0)!, now: now)
        let r = d.oxygen(day: "2026-10-30", rows: [["Time": "12:00", "OxygenValue": 98], ["Time": "12:01", "OxygenValue": 0.98]])
        XCTAssertEqual(r.count, 1); XCTAssertEqual(r[0].value, 0.98, accuracy: 0.00001)
    }
    func testSleepPreservesAwakeAndRejectsMismatchedDuration() {
        let d = VendorHistoryDecoder(device: "fixture", timeZone: TimeZone(secondsFromGMT: 0)!, now: now)
        let row: [String: Any] = ["SLEEP_TIME": "2026/10/30 01:00", "WAKE_TIME": "2026/10/30 01:15", "SLE_LINE": "021"]
        XCTAssertEqual(d.ordinarySleep(rows: [row]).count, 2)
        var bad = row; bad["SLE_LINE"] = "01"
        XCTAssertTrue(d.ordinarySleep(rows: [bad]).isEmpty)
    }
    func testTemperatureRejectsFractionalHour() {
        let d = VendorHistoryDecoder(device: "fixture", timeZone: TimeZone(secondsFromGMT: 0)!, now: now)
        XCTAssertTrue(d.temperature(day: "2026-10-30", rows: [["hour": 1.5, "minute": 0, "value": 36.5]]).isEmpty)
    }
    func testStepsAreNonOverlappingWholeIntervals() {
        let d = VendorHistoryDecoder(device: "fixture", timeZone: TimeZone(secondsFromGMT: 0)!, now: now)
        let rows: [String: Any] = ["12:00": ["stepValue": 123], "12:30": ["stepValue": 45], "12:15": ["stepValue": 10], "13:00": ["stepValue": 2.5]]
        let r = d.halfHourSteps(day: "2026-10-30", rows: rows).sorted { $0.start < $1.start }
        XCTAssertEqual(r.count, 2); XCTAssertEqual(r[0].end, r[1].start)
        XCTAssertEqual(r[0].value + r[1].value, 168)
    }

    func testCompositionDoesNotTurnProfileWeightIntoMeasurement() {
        let d = VendorHistoryDecoder(device: "fixture", timeZone: TimeZone(secondsFromGMT: 0)!, now: now)
        let rows: [[String: Any]] = [["date": "2026-10-30", "testTime": "12:00:00", "bodyFatPercentage": "23.5", "leanBodyMass": "65", "weight": 85]]
        let r = d.bodyComposition(rows: rows)
        XCTAssertEqual(r.count, 2)
        XCTAssertFalse(r.contains { $0.kind == .weightKg })
        XCTAssertEqual(r.first { $0.kind == .bodyFatFraction }!.value, 0.235, accuracy: 0.00001)
    }

    func testAccurateSleepSkipsInsomniaAndAwake() {
        let d = VendorHistoryDecoder(device: "fixture", timeZone: TimeZone(secondsFromGMT: 0)!, now: now)
        let row: [String: Any] = ["sleepTime": "2026/10/30 01:00", "wakeTime": "2026/10/30 01:05", "onePointDuration": "60", "sleepLine": "00002000400060008000"]
        let result = d.accurateSleep(rows: [row])
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.last!.end.timeIntervalSince(result.first!.start), 180)
        var invalid = row; invalid["sleepLine"] = "0000ZZZZ"
        XCTAssertTrue(d.accurateSleep(rows: [invalid]).isEmpty)
    }

    func testSameSourceIntervalDeduplicatesEvenWhenExternalIDChanges() {
        let first = measurement()
        var second = first; second.id = "changed-export-id"
        let result = MeasurementValidation.merge([], incoming: [first, second], now: now)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(first.syncIdentity, second.syncIdentity)
        second.source = "another physical source"
        XCTAssertEqual(MeasurementValidation.merge([], incoming: [first, second], now: now).count, 2)
        XCTAssertNotEqual(first.syncIdentity, second.syncIdentity)
    }

}
