//
//  WatchRootView.swift
//  watchOS — main screen: readiness state + today's workout summary.
//  Navigates to WatchWorkoutDetailView for the full exercise list.
//

import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject var receiver: WatchConnectivityReceiver

    var body: some View {
        if let data = receiver.workout {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    readinessHeader(data)
                    Divider()
                    workoutSummary(data)
                    NavigationLink {
                        WatchWorkoutDetailView(
                            workoutName: data.workoutName,
                            exercises: data.exercises
                        )
                    } label: {
                        Label("Exercises", systemImage: "list.bullet")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor(data.readinessState))
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
                Text("Open Healthfit on your iPhone")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("Healthfit")
        }
    }

    @ViewBuilder
    private func readinessHeader(_ data: WatchWorkoutData) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Circle()
                .fill(accentColor(data.readinessState))
                .frame(width: 8, height: 8)
                .offset(y: -1)
            Text(data.readinessLabel.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(accentColor(data.readinessState))
                .tracking(0.5)
            Spacer()
            Text("\(data.readinessScore)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(accentColor(data.readinessState))
        }
    }

    @ViewBuilder
    private func workoutSummary(_ data: WatchWorkoutData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.workoutName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(data.workoutMeta)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            if data.isAdjusted {
                Text("Adjusted")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.2))
                    .clipShape(Capsule())
                    .padding(.top, 2)
            }
        }
    }

    private func accentColor(_ state: String) -> Color {
        switch state {
        case "green":  return .green
        case "yellow": return .yellow
        default:       return .red
        }
    }
}
