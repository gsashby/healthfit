//
//  HealthfitWatchApp.swift
//  Healthfit Watch — companion app for the Healthfit iOS app.
//  Displays today's workout and readiness score pushed from the iPhone via WCSession.
//

import SwiftUI

@main
struct HealthfitWatchApp: App {
    @StateObject private var receiver = WatchConnectivityReceiver()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchRootView()
            }
            .environmentObject(receiver)
        }
    }
}
