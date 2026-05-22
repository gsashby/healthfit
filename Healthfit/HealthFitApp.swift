//
//  HealthFitApp.swift
//  HealthFit Prototype
//
//  App entry point.
//

import SwiftUI
import SwiftData

@main
struct HealthFitApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authService = AuthService()
    @StateObject private var readinessService = ReadinessService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(authService)
                .environmentObject(readinessService)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: PersistedProfile.self)
    }
}
