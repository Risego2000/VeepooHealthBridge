import Foundation
import HealthKit

@MainActor final class HealthBridge: ObservableObject {
    @Published private(set) var status = "Sin comprobar"
    @Published private(set) var lastResults = "Sin transferencia"
    @Published private(set) var isSyncing = false
    private let store = HKHealthStore()
    private let origin = "Veepoo Health Bridge"

    private var typeMapping: [(Measurement.Kind, HKQuantityTypeIdentifier, HKUnit, Double)] {
        [(.heartRate, .heartRate, HKUnit.count().unitDivided(by: .minute()), 1),
         (.hrvSDNN, .heartRateVariabilitySDNN, .secondUnit(with: .milli), 1),
         (.steps, .stepCount, .count(), 1),
         (.weightKg, .bodyMass, .gramUnit(with: .kilo), 1),
         (.bodyFatFraction, .bodyFatPercentage, .percent(), 1),
         (.leanMassKg, .leanBodyMass, .gramUnit(with: .kilo), 1),
         (.oxygenFraction, .oxygenSaturation, .percent(), 1),
         (.bodyTemperatureC, .bodyTemperature, .degreeCelsius(), 1),
         (.systolic, .bloodPressureSystolic, .millimeterOfMercury(), 1),
         (.diastolic, .bloodPressureDiastolic, .millimeterOfMercury(), 1)]
    }

    func requestPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else { status = "HealthKit no disponible"; return }
        var types = Set<HKSampleType>()
        for (_, identifier, _, _) in typeMapping {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) { types.insert(type) }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        store.requestAuthorization(toShare: types, read: types) { [weak self] ok, error in
            Task { @MainActor in
                self?.status = error.map { "Error: \($0.localizedDescription)" }
                    ?? (ok ? "Solicitud realizada; verifica permisos en Salud" : "No autorizado")
            }
        }
    }

    func sync(_ records: [Measurement]) {
        guard !isSyncing else { return }
        guard HKHealthStore.isHealthDataAvailable() else { lastResults = "HealthKit no disponible"; return }
        // Require explicit per-sample validation; never publish speculative biomarkers.
        let accepted = records.filter { $0.validated && $0.kind.writable && $0.source != "demo" }
        isSyncing = true
        Task {
            defer { isSyncing = false }
            var saved = 0, skipped = 0, errors = 0
            for record in accepted {
                guard isValid(record) else { skipped += 1; continue }
                guard let sample = sample(for: record),
                      store.authorizationStatus(for: sample.sampleType) == .sharingAuthorized else { skipped += 1; continue }
                do {
                    if try await alreadySaved(id: record.id, type: sample.sampleType, date: record.start) { skipped += 1; continue }
                    try await save(sample)
                    saved += 1
                } catch { errors += 1 }
            }
            lastResults = "Guardados: \(saved) · omitidos: \(skipped) · errores: \(errors)"
        }
    }

    private func isValid(_ m: Measurement) -> Bool {
        MeasurementValidation.accepts(m)
    }

    private func sample(for m: Measurement) -> HKSample? {
        let metadata: [String: Any] = [HKMetadataKeyExternalUUID: m.id,
            HKMetadataKeySyncIdentifier: "veepoo-bridge-\(m.id)", HKMetadataKeySyncVersion: 1,
            "DeviceOrigin": m.source, "DeviceMethod": m.method]
        if m.kind == .sleepAsleep {
            guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
            return HKCategorySample(type: type, value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                start: m.start, end: m.end, metadata: metadata)
        }
        guard let (_, identifier, unit, multiplier) = typeMapping.first(where: { $0.0 == m.kind }),
              let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        return HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: m.value * multiplier),
            start: m.start, end: m.end, metadata: metadata)
    }

    private func save(_ sample: HKSample) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.save(sample) { success, error in
                if success { continuation.resume() }
                else { continuation.resume(throwing: error ?? NSError(domain: "HealthKit", code: -1)) }
            }
        }
    }

    private func alreadySaved(id: String, type: HKSampleType, date: Date) async throws -> Bool {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: date.addingTimeInterval(-1), end: date.addingTimeInterval(1)),
            HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier,
                operatorType: .equalTo, value: "veepoo-bridge-\(id)")
        ])
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: !(samples ?? []).isEmpty) }
            }
            store.execute(query)
        }
    }
}
