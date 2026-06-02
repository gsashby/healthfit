//
//  ContentView.swift
//  Healthfit Watch Watch App — Today screen: readiness + 3 health metrics + workout.
//

import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject var receiver: WatchConnectivityReceiver
    @State private var autoLaunchWorkout = false

    var body: some View {
        // Hidden NavigationLink for auto-launching active workout from phone
        NavigationLink(isActive: $autoLaunchWorkout) {
            WatchActiveWorkoutView(
                workoutName: receiver.activeWorkout?.workoutName
                             ?? receiver.workout?.workoutName ?? "Workout",
                exercises: receiver.workout?.exercises ?? []
            )
        } label: { EmptyView() }
        .onChange(of: receiver.activeWorkout) { _, payload in
            if let payload, payload.isActive, payload.source == "phone" {
                autoLaunchWorkout = true
            } else if payload?.isActive == false {
                autoLaunchWorkout = false
            }
        }

        if let data = receiver.workout {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    readinessSection(data)
                    divider
                    metricsSection(data.vitals)
                    divider
                    workoutSection(data)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .toolbar(.hidden)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                Text("Open Healthfit\non your iPhone")
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding()
            .toolbar(.hidden)
        }
    }

    // MARK: - Readiness

    private func readinessSection(_ data: WatchWorkoutData) -> some View {
        HStack(alignment: .center, spacing: 8) {
            // Color ring
            Circle()
                .stroke(accentColor(data.readinessState), lineWidth: 3)
                .frame(width: 36, height: 36)
                .overlay(
                    Text("\(data.readinessScore)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor(data.readinessState))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(data.readinessLabel)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(accentColor(data.readinessState))
                Text("Readiness")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Health metrics (up to 3 vitals)

    private func metricsSection(_ vitals: [WatchVital]) -> some View {
        let displayed = vitals.isEmpty ? placeholderVitals : Array(vitals.prefix(3))
        return VStack(spacing: 0) {
            ForEach(Array(displayed.enumerated()), id: \.offset) { i, vital in
                HStack {
                    Text(vital.label)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(vital.value)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        if let unit = vital.unit {
                            Text(unit)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 7)
                if i < displayed.count - 1 {
                    Divider().opacity(0.4)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var placeholderVitals: [WatchVital] {
        [
            WatchVital(label: "HRV",        value: "—", unit: "ms"),
            WatchVital(label: "Sleep",       value: "—", unit: nil),
            WatchVital(label: "Resting HR",  value: "—", unit: "bpm"),
        ]
    }

    // MARK: - Workout

    private func workoutSection(_ data: WatchWorkoutData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(data.workoutName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if data.isAdjusted {
                        Spacer()
                        Text("Adjusted")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                Text(data.workoutMeta)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)

            NavigationLink {
                WatchActiveWorkoutView(workoutName: data.workoutName,
                                       exercises: data.exercises)
            } label: {
                Label("Start", systemImage: "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            NavigationLink {
                WatchWorkoutDetailView(workoutName: data.workoutName,
                                       exercises: data.exercises)
            } label: {
                Label("Exercises", systemImage: "list.bullet")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(accentColor(data.readinessState))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private var divider: some View {
        Divider().opacity(0.5)
    }

    private func accentColor(_ state: String) -> Color {
        switch state {
        case "green":  return .green
        case "yellow": return .yellow
        default:       return .red
        }
    }
}
