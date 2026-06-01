//
//  WatchActiveWorkoutView.swift
//  Healthfit Watch Watch App — live heart rate + elapsed timer during a workout.
//

import SwiftUI

struct WatchActiveWorkoutView: View {
    let workoutName: String

    @StateObject private var hrService = WatchHeartRateService()
    @State private var elapsed: Int = 0

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {

                // Heart rate
                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 15))
                        Text(hrService.currentBPM.map { "\($0)" } ?? "—")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.3), value: hrService.currentBPM)
                    }
                    Text("BPM")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                }

                Divider()

                // Elapsed time
                VStack(spacing: 2) {
                    Text(formatElapsed(elapsed))
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                    Text("Elapsed")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                // Session name
                Text(workoutName)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(clock) { _ in elapsed += 1 }
        .onAppear { hrService.start() }
        .onDisappear { hrService.stop() }
    }

    private func formatElapsed(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
