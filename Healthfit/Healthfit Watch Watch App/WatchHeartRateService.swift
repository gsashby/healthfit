//
//  WatchHeartRateService.swift
//  Healthfit Watch Watch App — polls HealthKit for current heart rate every 5 s.
//  Uses the completion-handler HK API to avoid Swift 6 Sendable issues with
//  async/await across actor boundaries.
//

import Combine
import HealthKit

final class WatchHeartRateService: ObservableObject {

    @Published var currentBPM: Int? = nil

    private let store = HKHealthStore()
    private var timer: Timer?

    func start() {
        fetchHR()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.fetchHR()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        currentBPM = nil
    }

    private func fetchHR() {
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-300), end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: type, predicate: predicate,
            limit: 1, sortDescriptors: [sort]
        ) { [weak self] _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            let bpm = Int(sample.quantity.doubleValue(
                for: .count().unitDivided(by: .minute())))
            DispatchQueue.main.async { self?.currentBPM = bpm }
        }
        store.execute(query)
    }
}
