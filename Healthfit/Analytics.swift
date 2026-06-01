//
//  Analytics.swift
//  Lightweight analytics event bus.
//
//  Currently a no-op so the app ships without any external dependency.
//  To wire in a real provider, add its SDK as a Swift Package and replace
//  the send(_:_:) stub below.
//
//  Recommended providers:
//  • TelemetryDeck (privacy-first, free ≤100k signals/mo)
//    https://github.com/TelemetryDeck/SwiftClient
//    Setup: TelemetryManager.initialize(with: .init(appID: "YOUR-APP-ID"))
//    Send:  TelemetryManager.send(eventName, with: payload)
//
//  • PostHog (open-source, self-hostable)
//    https://github.com/PostHog/posthog-ios
//    Setup: PostHogSDK.shared.setup(.init(apiKey: "YOUR-KEY"))
//    Send:  PostHogSDK.shared.capture(eventName, properties: payload)
//

import Foundation

enum Analytics {

    // MARK: - Event catalogue

    /// Fires when the user completes the five-step onboarding flow.
    static func onboardingCompleted(trainingType: String?, strengthSplit: String?) {
        send("onboarding_completed", [
            "training_type":   trainingType ?? "unknown",
            "strength_split":  strengthSplit ?? "none",
        ])
    }

    /// Fires when "Generate my week" produces a plan (FM or mock fallback).
    static func planGenerated(source: String) {
        // source: "foundation_models" | "mock_fallback"
        send("plan_generated", ["source": source])
    }

    /// Fires when a workout session starts (user taps Start / Accept).
    static func workoutStarted(kind: String, readinessState: String) {
        send("workout_started", ["kind": kind, "readiness": readinessState])
    }

    /// Fires when a workout session is marked complete.
    static func workoutCompleted(kind: String, elapsedSeconds: Int, setsLogged: Int) {
        send("workout_completed", [
            "kind":            kind,
            "elapsed_seconds": String(elapsedSeconds),
            "sets_logged":     String(setsLogged),
        ])
    }

    /// Fires when the user logs a food entry from any source.
    static func foodLogged(source: String) {
        // source: "search" | "camera" | "barcode" | "manual"
        send("food_logged", ["source": source])
    }

    /// Fires when the user sends a message in the Coach tab.
    static func coachMessageSent() {
        send("coach_message_sent", [:])
    }

    // MARK: - Internal dispatcher

    private static func send(_ event: String, _ payload: [String: String] = [:]) {
        // Replace this stub with your provider's call.
        // Example for TelemetryDeck:
        //   TelemetryManager.send(event, with: payload)
        #if DEBUG
        let pairs = payload.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        print("[Analytics] \(event) \(pairs)")
        #endif
    }
}
