//
//  WatchConnectivityReceiver.swift
//  Healthfit Watch Watch App — receives workout payload from the iPhone via WCSession
//  and sends workout-sync updates back.
//

import Combine
import WatchConnectivity
import SwiftUI

// Shared workout-sync types — duplicated from AppState.swift on the iOS side.
struct SyncSet: Codable, Equatable {
    let targetReps: Int
    var completedReps: Int
    var weightLbs: Double
    var isLogged: Bool
}

struct SyncExercise: Codable, Equatable {
    let name: String
    var sets: [SyncSet]
}

struct WorkoutSyncPayload: Codable, Equatable {
    let workoutName: String
    var exercises: [SyncExercise]
    var exerciseIndex: Int
    var elapsed: Int
    var isActive: Bool
    var source: String   // "phone" | "watch"
}

struct WatchVital {
    let label: String
    let value: String
    let unit: String?
}

// Today's planned workout (pushed on app load from TodayView).
struct WatchWorkoutData {
    let workoutName: String
    let workoutMeta: String
    let exercises: [String]
    let readinessState: String
    let readinessScore: Int
    let readinessLabel: String
    let kcalTarget: Int
    let isAdjusted: Bool
    let vitals: [WatchVital]
}

final class WatchConnectivityReceiver: NSObject, ObservableObject {

    @Published var workout: WatchWorkoutData? = nil
    @Published var activeWorkout: WorkoutSyncPayload? = nil

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Send sync to iPhone

    func sendWorkoutSync(_ payload: WorkoutSyncPayload) {
        guard WCSession.default.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(payload),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let message = ["workoutSync": dict]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.transferUserInfo(message)
        }
    }

    // MARK: - Parsing

    private func parseContext(_ context: [String: Any]) {
        // Workout-day summary (from applicationContext)
        if let name   = context["workoutName"]    as? String,
           let meta   = context["workoutMeta"]    as? String,
           let exs    = context["exercises"]      as? [String],
           let state  = context["readinessState"] as? String,
           let score  = context["readinessScore"] as? Int,
           let label  = context["readinessLabel"] as? String {
            let vitals: [WatchVital] = (context["vitals"] as? [[String: Any]] ?? [])
                .compactMap { d in
                    guard let l = d["label"] as? String,
                          let v = d["value"] as? String else { return nil }
                    return WatchVital(label: l, value: v, unit: d["unit"] as? String)
                }
            workout = WatchWorkoutData(
                workoutName: name, workoutMeta: meta, exercises: exs,
                readinessState: state, readinessScore: score, readinessLabel: label,
                kcalTarget: context["kcalTarget"] as? Int ?? 0,
                isAdjusted: context["isAdjusted"] as? Bool ?? false,
                vitals: vitals
            )
        }
        // Active workout sync (also stored in applicationContext)
        applySync(from: context)
    }

    private func applySync(from dict: [String: Any]) {
        guard let syncDict = dict["workoutSync"] as? [String: Any] ?? dict as? [String: Any],
              let data    = try? JSONSerialization.data(withJSONObject: syncDict),
              let payload = try? JSONDecoder().decode(WorkoutSyncPayload.self, from: data),
              payload.source != "watch"
        else { return }
        activeWorkout = payload
    }
}

extension WatchConnectivityReceiver: WCSessionDelegate {

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        let ctx = session.receivedApplicationContext
        guard !ctx.isEmpty else { return }
        DispatchQueue.main.async { self.parseContext(ctx) }
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { self.parseContext(applicationContext) }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let dict = message["workoutSync"] as? [String: Any],
              let data = try? JSONSerialization.data(withJSONObject: dict),
              let payload = try? JSONDecoder().decode(WorkoutSyncPayload.self, from: data),
              payload.source != "watch"
        else { return }
        DispatchQueue.main.async { self.activeWorkout = payload }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let dict = userInfo["workoutSync"] as? [String: Any],
              let data = try? JSONSerialization.data(withJSONObject: dict),
              let payload = try? JSONDecoder().decode(WorkoutSyncPayload.self, from: data),
              payload.source != "watch"
        else { return }
        DispatchQueue.main.async { self.activeWorkout = payload }
    }
}
