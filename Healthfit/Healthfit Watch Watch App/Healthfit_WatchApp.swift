//
//  Healthfit_WatchApp.swift
//  Healthfit Watch Watch App
//

import SwiftUI

@main
struct Healthfit_Watch_Watch_AppApp: App {
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
