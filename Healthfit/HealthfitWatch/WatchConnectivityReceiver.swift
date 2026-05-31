//
//  WatchConnectivityReceiver.swift
//  watchOS — receives the workout payload pushed by the iOS app via
//  WCSession.updateApplicationContext and publishes it for the UI.
//

import WatchConnectivity
import SwiftUI

struct WatchWorkoutData {
    let workoutName: String
    let workoutMeta: String
    let exercises: [String]
    let readinessState: String   // "green" | "yellow" | "red"
    let readinessScore: Int
    let readinessLabel: String
    let kcalTarget: Int
    let isAdjusted: Bool
}

@MainActor
final class WatchConnectivityReceiver: NSObject, ObservableObject {

    @Published var workout: WatchWorkoutData? = nil

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func parse(_ context: [String: Any]) {
        guard
            let name   = context["workoutName"]    as? String,
            let meta   = context["workoutMeta"]    as? String,
            let exs    = context["exercises"]      as? [String],
            let state  = context["readinessState"] as? String,
            let score  = context["readinessScore"] as? Int,
            let label  = context["readinessLabel"] as? String
        else { return }

        workout = WatchWorkoutData(
            workoutName: name,
            workoutMeta: meta,
            exercises: exs,
            readinessState: state,
            readinessScore: score,
            readinessLabel: label,
            kcalTarget: context["kcalTarget"] as? Int ?? 0,
            isAdjusted: context["isAdjusted"] as? Bool ?? false
        )
    }
}

extension WatchConnectivityReceiver: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        let cached = session.receivedApplicationContext
        guard !cached.isEmpty else { return }
        Task { @MainActor in self.parse(cached) }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.parse(applicationContext) }
    }
}
