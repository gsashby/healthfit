//
//  HealthFitApp.swift
//  HealthFit Prototype
//
//  App entry point.
//

import SwiftUI

@main
struct HealthFitApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}
