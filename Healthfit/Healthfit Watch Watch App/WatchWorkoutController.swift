//
//  WatchWorkoutController.swift
//  Healthfit Watch Watch App — manages exercise/set state for a strength session.
//

import Combine
import Foundation

struct WatchSetData {
    let targetReps: Int
    var completedReps: Int
    var weightLbs: Double
    var isLogged: Bool = false
}

struct WatchExerciseData: Identifiable {
    let id = UUID()
    let name: String
    var sets: [WatchSetData]

    var nextSetIndex: Int?  { sets.indices.first { !sets[$0].isLogged } }
    var loggedCount: Int    { sets.filter(\.isLogged).count }
    var isComplete: Bool    { sets.allSatisfy(\.isLogged) }
}

final class WatchWorkoutController: ObservableObject {

    @Published var exercises: [WatchExerciseData] = []
    @Published var exerciseIndex: Int = 0
    @Published var allDone: Bool = false

    var onStateChanged: ((WorkoutSyncPayload) -> Void)?
    private var workoutName: String = ""
    private var elapsed: Int = 0

    var currentExercise: WatchExerciseData? {
        guard exerciseIndex < exercises.count else { return nil }
        return exercises[exerciseIndex]
    }

    var currentSetIndex: Int? { currentExercise?.nextSetIndex }

    // MARK: - Setup

    func setup(from chips: [String], name: String = "") {
        exercises = chips.compactMap(Self.parse)
        exerciseIndex = 0
        allDone = false
        workoutName = name
    }

    func applySync(_ payload: WorkoutSyncPayload) {
        workoutName = payload.workoutName
        elapsed     = payload.elapsed

        // Sync each exercise's set state
        for (ei, syncEx) in payload.exercises.enumerated() {
            if ei < exercises.count {
                for (si, syncSet) in syncEx.sets.enumerated() {
                    guard si < exercises[ei].sets.count else { continue }
                    exercises[ei].sets[si].weightLbs    = syncSet.weightLbs
                    exercises[ei].sets[si].completedReps = syncSet.completedReps
                    if syncSet.isLogged && !exercises[ei].sets[si].isLogged {
                        exercises[ei].sets[si].isLogged = true
                    }
                }
            } else {
                // Phone has more exercises — append them
                if let ex = Self.parse("\(syncEx.name) \(syncEx.sets.count)×\(syncEx.sets.first?.targetReps ?? 8)") {
                    exercises.append(ex)
                }
            }
        }

        // Advance exercise index to match phone
        if payload.exerciseIndex < exercises.count {
            exerciseIndex = payload.exerciseIndex
        }
        allDone = !payload.isActive && exercises.allSatisfy(\.isComplete)
    }

    func toSyncPayload(elapsed: Int) -> WorkoutSyncPayload {
        WorkoutSyncPayload(
            workoutName: workoutName,
            exercises: exercises.map { ex in
                SyncExercise(name: ex.name,
                             sets: ex.sets.map { s in
                                 SyncSet(targetReps: s.targetReps,
                                         completedReps: s.completedReps,
                                         weightLbs: s.weightLbs,
                                         isLogged: s.isLogged)
                             })
            },
            exerciseIndex: exerciseIndex,
            elapsed: elapsed,
            isActive: !allDone,
            source: "watch"
        )
    }

    // MARK: - Set editing

    @Published var editingSetIndex: Int? = nil
    @Published var editWeight: Double = 0
    @Published var editReps: Int = 0

    func startEditing(setIndex: Int) {
        guard exerciseIndex < exercises.count,
              setIndex < exercises[exerciseIndex].sets.count else { return }
        let s = exercises[exerciseIndex].sets[setIndex]
        editWeight      = s.weightLbs
        editReps        = s.completedReps
        editingSetIndex = setIndex
    }

    func cancelEdit() { editingSetIndex = nil }

    func saveEdit() {
        guard let si = editingSetIndex, exerciseIndex < exercises.count else { return }
        exercises[exerciseIndex].sets[si].weightLbs    = editWeight
        exercises[exerciseIndex].sets[si].completedReps = editReps
        editingSetIndex = nil
    }

    func adjustEditWeight(by delta: Double) { editWeight = max(0, editWeight + delta) }
    func adjustEditReps(by delta: Int)      { editReps   = max(0, editReps + delta) }

    // MARK: - Mutations

    func adjustWeight(by delta: Double) {
        guard exerciseIndex < exercises.count,
              let si = currentSetIndex else { return }
        let new = max(0, exercises[exerciseIndex].sets[si].weightLbs + delta)
        exercises[exerciseIndex].sets[si].weightLbs = new
    }

    func adjustReps(by delta: Int) {
        guard exerciseIndex < exercises.count,
              let si = currentSetIndex else { return }
        let new = max(0, exercises[exerciseIndex].sets[si].completedReps + delta)
        exercises[exerciseIndex].sets[si].completedReps = new
    }

    func logCurrentSet() {
        guard exerciseIndex < exercises.count,
              let si = currentSetIndex else { return }

        exercises[exerciseIndex].sets[si].isLogged = true

        // Carry weight forward to the next set in the same exercise
        if let nextSi = exercises[exerciseIndex].nextSetIndex {
            exercises[exerciseIndex].sets[nextSi].weightLbs =
                exercises[exerciseIndex].sets[si].weightLbs
        }

        // If this exercise is now complete, advance to the next
        if exercises[exerciseIndex].isComplete {
            if let next = exercises.indices
                .first(where: { $0 > exerciseIndex && !exercises[$0].isComplete }) {
                exerciseIndex = next
            } else {
                allDone = exercises.allSatisfy(\.isComplete)
            }
        }
    }

    // MARK: - Parsing

    private nonisolated static func parse(_ chip: String) -> WatchExerciseData? {
        guard let xRange = chip.range(of: "×") else { return nil }
        let parts = String(chip[..<xRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: " ")
        guard let setCount = Int(parts.last ?? ""), setCount > 0 else { return nil }
        let name = parts.dropLast().joined(separator: " ")
        guard !name.isEmpty else { return nil }
        let repsStr = String(chip[xRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        let reps = Int(repsStr) ?? 8
        let sets = (0..<setCount).map { _ in
            WatchSetData(targetReps: reps, completedReps: reps, weightLbs: 0)
        }
        return WatchExerciseData(name: name, sets: sets)
    }
}
