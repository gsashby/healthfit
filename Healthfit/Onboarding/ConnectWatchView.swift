//
//  ConnectWatchView.swift
//  Apple Watch / HealthKit connect step — requests HKHealthStore authorization
//  for HRV, sleep stages, RHR, and workout types, then kicks off the first
//  readiness fetch.
//

import SwiftUI
import HealthKit

struct ConnectWatchView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var readinessService: ReadinessService
    let next: () -> Void

    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("Step 6 of 6")
                    .eyebrow()
                    .padding(.top, 16)

                Text("Connect Apple Watch")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.text)
                    .padding(.top, 6)

                Text("This is what makes daily adjustments possible. We read overnight HRV, sleep stages, and resting heart rate. We don't share your health data with anyone.")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textMuted)
                    .lineSpacing(3)
                    .padding(.top, 6)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    permissionRow(icon: "❤️", title: "Heart rate variability", subtitle: "Daily readiness signal")
                    permissionRow(icon: "🌙", title: "Sleep stages",            subtitle: "Recovery context")
                    permissionRow(icon: "💓", title: "Resting heart rate",      subtitle: "Baseline tracking")
                    permissionRow(icon: "🏃", title: "Workouts",                subtitle: "Two-way sync")
                }
                .padding(.top, 22)

                if let err = errorMessage {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.red)
                        .padding(.top, 12)
                }

                Spacer()

                if appState.watchConnected {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.green)
                        Text("Connected")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)

                    PrimaryButton(title: "Continue", tint: Theme.green, action: next)

                } else {
                    PrimaryButton(
                        title: isConnecting ? "Requesting access…" : "Connect Apple Watch",
                        tint: Theme.green,
                        action: connect
                    )
                    .disabled(isConnecting)

                    Button("I'll do this later") { next() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)
                }

                Spacer().frame(height: 30)
            }
            .padding(.horizontal, 22)
        }
    }

    private func permissionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Text(icon)
                .font(.system(size: 22))
                .frame(width: 44, height: 44)
                .background(Theme.card2)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text)
                Text(subtitle).font(.system(size: 12)).foregroundColor(Theme.textMuted)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func connect() {
        guard !isConnecting else { return }
        isConnecting = true
        errorMessage = nil
        Task {
            do {
                try await readinessService.requestAuthorization()
                appState.setWatchConnected(true)
            } catch {
                errorMessage = "Couldn't connect — please allow access in Settings."
            }
            isConnecting = false
        }
    }
}

#Preview {
    ConnectWatchView(next: {})
        .environmentObject(AppState())
        .environmentObject(ReadinessService())
}
