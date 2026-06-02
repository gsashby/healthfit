//
//  WatchActiveWorkoutView.swift
//  Healthfit Watch Watch App — HR + elapsed + per-set exercise tracker
//  with bidirectional sync to the iPhone.
//

import Combine
import SwiftUI

struct WatchActiveWorkoutView: View {
    let workoutName: String
    let exercises: [String]

    @EnvironmentObject var receiver: WatchConnectivityReceiver
    @StateObject private var hrService  = WatchHeartRateService()
    @StateObject private var controller = WatchWorkoutController()
    @State       private var elapsed: Int = 0

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isStrength: Bool { exercises.contains { $0.contains("×") } }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                statsBar
                Divider().padding(.vertical, 8)
                if isStrength {
                    strengthBody
                } else {
                    cardioBody
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
        }
        .navigationTitle(workoutName)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(clock) { _ in elapsed += 1 }
        .onAppear {
            hrService.start()
            if isStrength {
                if let active = receiver.activeWorkout, active.isActive {
                    // Phone already has an active workout — sync from it
                    controller.setup(from: active.exercises.map {
                        "\($0.name) \($0.sets.count)×\($0.sets.first?.targetReps ?? 8)"
                    }, name: active.workoutName)
                    controller.applySync(active)
                    elapsed = active.elapsed
                } else {
                    controller.setup(from: exercises, name: workoutName)
                    sendSync()  // tell the phone we've started
                }
            }
        }
        .onDisappear { hrService.stop() }
        // Apply incoming phone updates
        .onChange(of: receiver.activeWorkout) { _, payload in
            guard let payload, payload.source == "phone", isStrength else { return }
            controller.applySync(payload)
        }
    }

    // MARK: - Stats bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 3) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 11))
                Text(hrService.currentBPM.map { "\($0)" } ?? "—")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: hrService.currentBPM)
                Text("bpm")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: "timer")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(fmt(elapsed))
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
            }
        }
    }

    // MARK: - Cardio

    private var cardioBody: some View {
        Text(workoutName)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }

    // MARK: - Strength

    @ViewBuilder
    private var strengthBody: some View {
        if controller.allDone {
            doneView
        } else if let ex = controller.currentExercise,
                  let si = controller.currentSetIndex {
            exerciseView(ex: ex, si: si)
        } else {
            Text("All sets logged")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }

    private func exerciseView(ex: WatchExerciseData, si: Int) -> some View {
        let set = ex.sets[si]
        return VStack(spacing: 10) {

            // Name + set counter
            VStack(spacing: 2) {
                Text(ex.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                if let editIdx = controller.editingSetIndex {
                    Text("Editing Set \(editIdx + 1)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange)
                } else {
                    Text("Set \(si + 1) of \(ex.sets.count)  ·  target \(set.targetReps) reps")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            if controller.editingSetIndex != nil {
                editPanel
            } else {
                logPanel(set: set, setNumber: si + 1)
            }

            // Logged sets — tap any to edit
            if ex.loggedCount > 0 {
                Divider()
                loggedSetsList(ex: ex, upTo: si)
            }
        }
    }

    // MARK: Log panel (next set)

    private func logPanel(set: WatchSetData, setNumber: Int) -> some View {
        VStack(spacing: 10) {
            weightStepper(
                value: set.weightLbs,
                minus: { controller.adjustWeight(by: -5); sendSync() },
                plus:  { controller.adjustWeight(by: +5); sendSync() }
            )

            Divider()

            repsStepper(
                value: set.completedReps,
                minus: { controller.adjustReps(by: -1); sendSync() },
                plus:  { controller.adjustReps(by: +1); sendSync() }
            )

            Divider()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    controller.logCurrentSet()
                    sendSync()
                }
            } label: {
                Text("Log Set \(setNumber)")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }

    // MARK: Edit panel (previously logged set)

    private var editPanel: some View {
        VStack(spacing: 10) {
            weightStepper(
                value: controller.editWeight,
                minus: { controller.adjustEditWeight(by: -5) },
                plus:  { controller.adjustEditWeight(by: +5) }
            )

            Divider()

            repsStepper(
                value: controller.editReps,
                minus: { controller.adjustEditReps(by: -1) },
                plus:  { controller.adjustEditReps(by: +1) }
            )

            Divider()

            HStack(spacing: 6) {
                Button("Cancel") { controller.cancelEdit() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                Button("Save") {
                    controller.saveEdit()
                    sendSync()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Logged sets list (tappable)

    private func loggedSetsList(ex: WatchExerciseData, upTo si: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(ex.sets.prefix(si).enumerated()), id: \.offset) { i, s in
                if s.isLogged {
                Button {
                    if controller.editingSetIndex == i { controller.cancelEdit() }
                    else { controller.startEditing(setIndex: i) }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: controller.editingSetIndex == i
                              ? "pencil.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(controller.editingSetIndex == i ? .orange : .green)
                            .font(.system(size: 11))
                        Text("Set \(i + 1):  \(s.weightLbs > 0 ? wStr(s.weightLbs) + " lbs × " : "")\(s.completedReps) reps")
                            .font(.system(size: 11))
                            .foregroundColor(controller.editingSetIndex == i ? .primary : .secondary)
                        Spacer()
                        Image(systemName: "pencil")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.4))
                    }
                }
                .buttonStyle(.plain)
                } // end if s.isLogged
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Shared steppers

    private func weightStepper(value: Double,
                                minus: @escaping () -> Void,
                                plus: @escaping () -> Void) -> some View {
        VStack(spacing: 4) {
            Text("WEIGHT")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.6)
            HStack(spacing: 0) {
                stepButton("−5", action: minus)
                Spacer()
                VStack(spacing: 1) {
                    Text(value > 0 ? wStr(value) : "—")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .animation(.easeInOut(duration: 0.15), value: value)
                    Text("lbs").font(.system(size: 10)).foregroundColor(.secondary)
                }
                Spacer()
                stepButton("+5", action: plus)
            }
        }
    }

    private func repsStepper(value: Int,
                              minus: @escaping () -> Void,
                              plus: @escaping () -> Void) -> some View {
        VStack(spacing: 4) {
            Text("REPS")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.6)
            HStack(spacing: 0) {
                stepButton("−", action: minus)
                Spacer()
                Text("\(value)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .animation(.easeInOut(duration: 0.15), value: value)
                Spacer()
                stepButton("+", action: plus)
            }
        }
    }

    private var doneView: some View {
        VStack(spacing: 8) {
            Text("Done!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.green)
            Text("\(controller.exercises.count) exercises complete")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.top, 12)
    }

    // MARK: - Sync

    private func sendSync() {
        let payload = controller.toSyncPayload(elapsed: elapsed)
        receiver.sendWorkoutSync(payload)
    }

    // MARK: - Helpers

    private func stepButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 40, height: 36)
        }
        .buttonStyle(.bordered)
    }

    private func fmt(_ s: Int)  -> String { String(format: "%d:%02d", s / 60, s % 60) }
    private func wStr(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
    }
}
