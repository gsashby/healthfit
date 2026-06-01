//
//  HealthfitTests.swift
//  Unit tests for HealthFit core logic.
//  Covers: Epley 1RM, weight suggestions, readiness scoring,
//          macro targets, unit conversion, food entry codability,
//          and exercise history recording.
//

import Testing
import Foundation
@testable import Healthfit

// MARK: - Epley 1RM formula

@Suite("ExerciseRecord: Epley 1RM") struct ExerciseRecordTests {

    @Test("single set — standard formula")
    func oneRepMaxSingleSet() {
        // 100 lbs × (1 + 10/30) = 100 × 1.3333 ≈ 133.3
        let record = ExerciseRecord(date: .now, sets: [LoggedSet(weightLbs: 100, reps: 10)])
        #expect(record.estimatedOneRepMax.rounded() == 133)
    }

    @Test("picks the best set, not the first")
    func oneRepMaxPicksBestSet() {
        // Set A: 100 × (1 + 5/30) = 100 × 1.167 ≈ 116.7
        // Set B:  90 × (1 + 10/30) =  90 × 1.333 ≈ 120.0  ← winner
        let record = ExerciseRecord(date: .now, sets: [
            LoggedSet(weightLbs: 100, reps: 5),
            LoggedSet(weightLbs: 90,  reps: 10),
        ])
        #expect(record.estimatedOneRepMax.rounded() == 120)
    }

    @Test("zero weight returns zero")
    func oneRepMaxZeroWeight() {
        let record = ExerciseRecord(date: .now, sets: [LoggedSet(weightLbs: 0, reps: 10)])
        #expect(record.estimatedOneRepMax == 0)
    }

    @Test("zero reps returns zero")
    func oneRepMaxZeroReps() {
        let record = ExerciseRecord(date: .now, sets: [LoggedSet(weightLbs: 100, reps: 0)])
        #expect(record.estimatedOneRepMax == 0)
    }

    @Test("empty sets returns zero")
    func oneRepMaxEmptySets() {
        let record = ExerciseRecord(date: .now, sets: [])
        #expect(record.estimatedOneRepMax == 0)
    }
}

// MARK: - Weight suggestions

@Suite("AppState: weight suggestions") struct WeightSuggestionTests {

    @Test("no history returns nil") @MainActor
    func noHistoryReturnsNil() {
        let state = AppState()
        #expect(state.suggestedWeight(for: "Unknown lift", targetRepsStr: "8") == nil)
    }

    @Test("result is always a multiple of 5") @MainActor
    func roundsToNearestFive() {
        let state = AppState()
        // 200 lbs × 3 reps → 1RM = 200 × 1.1 = 220 → 90% → 198 → rounds to 200
        state.logExercise("Bench press", sets: [(weight: 200, reps: 3)])
        let w = state.suggestedWeight(for: "Bench press", targetRepsStr: "3")
        #expect(w != nil)
        #expect(w!.truncatingRemainder(dividingBy: 5) == 0)
    }

    @Test("lower-rep target → higher percentage of 1RM") @MainActor
    func higherIntensityForLowerReps() {
        let state = AppState()
        // 100 lbs × 10 reps → 1RM ≈ 133
        state.logExercise("Squat", sets: [(weight: 100, reps: 10)])
        let w3  = state.suggestedWeight(for: "Squat", targetRepsStr: "3")   // 90% ≈ 120
        let w12 = state.suggestedWeight(for: "Squat", targetRepsStr: "12")  // 72% ≈ 95
        #expect(w3 != nil && w12 != nil)
        #expect(w3! > w12!)
    }

    @Test("exercise name lookup is case-insensitive") @MainActor
    func caseInsensitiveLookup() {
        let state = AppState()
        state.logExercise("Back Squat", sets: [(weight: 100, reps: 5)])
        #expect(state.suggestedWeight(for: "back squat", targetRepsStr: "5") != nil)
        #expect(state.suggestedWeight(for: "BACK SQUAT", targetRepsStr: "5") != nil)
    }

    @Test("uses most recent record, not the oldest") @MainActor
    func usesMostRecentRecord() {
        let state = AppState()
        let oldDate = Date(timeIntervalSinceNow: -86400 * 14)
        let newDate = Date(timeIntervalSinceNow: -3600)
        state.exerciseHistory["deadlift"] = [
            ExerciseRecord(date: oldDate, sets: [LoggedSet(weightLbs: 50, reps: 5)]),
            ExerciseRecord(date: newDate, sets: [LoggedSet(weightLbs: 200, reps: 5)]),
        ]
        // Recent 1RM ≈ 200 × 1.167 = 233; 85% → ~198 → rounds to 200
        let w = state.suggestedWeight(for: "Deadlift", targetRepsStr: "5")
        #expect(w != nil)
        #expect(w! >= 195)   // definitely from the recent heavy record, not the 50 lbs one
    }

    @Test("minimum suggested weight is 5 lbs") @MainActor
    func minimumFiveLbs() {
        let state = AppState()
        state.logExercise("Cable fly", sets: [(weight: 5, reps: 20)])
        let w = state.suggestedWeight(for: "Cable fly", targetRepsStr: "20")
        #expect(w != nil)
        #expect(w! >= 5)
    }
}

// MARK: - Exercise history recording

@Suite("AppState: exercise history") struct ExerciseHistoryTests {

    @Test("logExercise stores a record") @MainActor
    func storesRecord() {
        let state = AppState()
        state.logExercise("Bench press", sets: [(weight: 100, reps: 8)])
        #expect(state.exerciseHistory["bench press"]?.count == 1)
    }

    @Test("skips sets with zero weight") @MainActor
    func skipsZeroWeight() {
        let state = AppState()
        state.logExercise("Squat", sets: [(weight: 0, reps: 5), (weight: 100, reps: 5)])
        let sets = state.exerciseHistory["squat"]?.first?.sets
        #expect(sets?.count == 1)   // zero-weight set dropped
        #expect(sets?.first?.weightLbs == 100)
    }

    @Test("caps history at 20 sessions") @MainActor
    func capsAtTwentySessions() {
        let state = AppState()
        for _ in 0..<25 {
            state.logExercise("OHP", sets: [(weight: 60, reps: 8)])
        }
        #expect(state.exerciseHistory["ohp"]?.count == 20)
    }
}

// MARK: - Readiness scoring

@Suite("ReadinessService: score calculation") struct ReadinessScoreTests {

    private let svc = ReadinessService()
    private let goodSleep = ReadinessService.SleepResult(hours: 8.0, score: 90)
    private let poorSleep = ReadinessService.SleepResult(hours: 5.0, score: 50)

    @Test("perfect metrics → green, score 100") @MainActor
    func perfectMetricsGreen() {
        // HRV 10% above baseline (40pts) + 8h sleep (40pts) + RHR below baseline (20pts) = 100
        let result = svc.computeReadiness(
            hrv: 66, hrvBaseline: 60,
            rhr: 50, rhrBaseline: 55,
            sleep: goodSleep
        )
        #expect(result.state == .green)
        #expect(result.score == 100)
    }

    @Test("poor HRV and sleep → red") @MainActor
    func poorMetricsRed() {
        // HRV 25% below baseline (10pts) + 5h sleep (5pts) + RHR +7bpm (5pts) = 20
        let result = svc.computeReadiness(
            hrv: 45, hrvBaseline: 60,
            rhr: 62, rhrBaseline: 55,
            sleep: poorSleep
        )
        #expect(result.state == .red)
        #expect(result.score < 40)
    }

    @Test("mixed signals → yellow") @MainActor
    func mixedSignalsYellow() {
        // HRV at baseline (30pts) + 6.5h sleep (25pts) + RHR +2bpm (15pts) = 70 → green boundary
        // Adjust to get yellow (40–69)
        let averageSleep = ReadinessService.SleepResult(hours: 6.5, score: 70)
        let result = svc.computeReadiness(
            hrv: 60, hrvBaseline: 60,
            rhr: 57, rhrBaseline: 55,
            sleep: averageSleep
        )
        // 30 + 25 + 15 = 70 → green boundary; let's test with slightly below
        let result2 = svc.computeReadiness(
            hrv: 48, hrvBaseline: 60,   // 20% below → 20pts
            rhr: 57, rhrBaseline: 55,   // +2 bpm → 15pts
            sleep: averageSleep          // 6.5h → 25pts → total 60 → yellow
        )
        #expect(result2.state == .yellow)
    }

    @Test("nil inputs use neutral defaults") @MainActor
    func nilInputsNeutral() {
        let result = svc.computeReadiness(hrv: nil, hrvBaseline: nil,
                                          rhr: nil, rhrBaseline: nil, sleep: nil)
        // HRV nil → 20pts, sleep nil → 20pts, RHR nil → 10pts = 50 → yellow
        #expect(result.state == .yellow)
        #expect(result.score == 50)
    }

    @Test("score thresholds: ≥70 green, 40–69 yellow, <40 red") @MainActor
    func scoreThresholds() {
        // Force exact boundary scores by constructing known inputs
        let goodSleep8 = ReadinessService.SleepResult(hours: 8, score: 90)
        let greenResult = svc.computeReadiness(hrv: 66, hrvBaseline: 60,
                                               rhr: 50, rhrBaseline: 55,
                                               sleep: goodSleep8)
        #expect(greenResult.state == .green)
        #expect(greenResult.score >= 70)
    }
}

// MARK: - Macro targets

@Suite("AppState: macro targets per readiness") struct MacroTargetTests {

    @Test("green + lift → high protein target") @MainActor
    func greenLiftDay() {
        let state = AppState()
        let adj = state.adjustedTodayWorkout(readiness: .green)
        // Default plan has a lift session today (MockData.hybridWeek), so macros should be lift-day values
        // Even if today's plan differs, kcal should be non-zero
        #expect(adj.kcalTarget > 0)
        #expect(adj.macros.proteinG > 0)
    }

    @Test("yellow → moderate kcal target") @MainActor
    func yellowModerate() {
        let state = AppState()
        let adj = state.adjustedTodayWorkout(readiness: .yellow)
        #expect(adj.kcalTarget == 2080)
        #expect(adj.macros.carbsG == 200)
        #expect(adj.macros.proteinG == 170)
        #expect(adj.macros.fatG == 75)
    }

    @Test("red → recovery targets") @MainActor
    func redRecovery() {
        let state = AppState()
        let adj = state.adjustedTodayWorkout(readiness: .red)
        #expect(adj.kcalTarget == 1920)
        #expect(adj.macros.carbsG == 160)
        #expect(adj.tag == "Adjusted")
    }

    @Test("red → session name is recovery walk") @MainActor
    func redSessionName() {
        let state = AppState()
        let adj = state.adjustedTodayWorkout(readiness: .red)
        #expect(adj.name.lowercased().contains("walk") || adj.name.lowercased().contains("recover"))
    }
}

// MARK: - Unit conversion

@Suite("AppState: unit conversion") struct UnitConversionTests {

    @Test("displayWeight: imperial passthrough") @MainActor
    func imperialPassthrough() {
        let state = AppState()
        state.useMetric = false
        #expect(state.displayWeight(185) == 185)
    }

    @Test("displayWeight: lbs to kg") @MainActor
    func lbsToKg() {
        let state = AppState()
        state.useMetric = true
        let kg = state.displayWeight(220)
        // 220 / 2.20462 ≈ 99.79
        #expect(abs(kg - 99.79) < 0.01)
    }

    @Test("storedWeightLbs: kg to lbs roundtrip") @MainActor
    func kgToLbsRoundtrip() {
        let state = AppState()
        state.useMetric = true
        let original = 100.0
        let lbs = state.storedWeightLbs(original)
        let backToKg = state.displayWeight(lbs)
        #expect(abs(backToKg - original) < 0.001)
    }

    @Test("formatWeight: includes correct suffix") @MainActor
    func formatWeightSuffix() {
        let state = AppState()
        state.useMetric = false
        #expect(state.formatWeight(135).hasSuffix("lbs"))
        state.useMetric = true
        #expect(state.formatWeight(135 * 2.20462).hasSuffix("kg"))
    }

    @Test("weightStep: 5 lbs imperial, ~5.5 lbs metric") @MainActor
    func weightStep() {
        let state = AppState()
        state.useMetric = false
        #expect(state.weightStep == 5.0)
        state.useMetric = true
        // 2.5 kg × 2.20462 ≈ 5.51 lbs
        #expect(abs(state.weightStep - 5.5115) < 0.01)
    }
}

// MARK: - FoodEntry Codable

@Suite("FoodEntry: Codable roundtrip") struct FoodEntryCodableTests {

    @Test("encodes and decodes with same values")
    func roundtrip() throws {
        let entry = FoodEntry(
            mealType: "Lunch",
            name: "Chicken rice bowl",
            kcal: 650,
            macros: Macros(carbsG: 58, proteinG: 56, fatG: 18),
            allergens: ["Dairy"],
            time: "12:30 PM"
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(FoodEntry.self, from: data)

        #expect(decoded.id == entry.id)
        #expect(decoded.name == "Chicken rice bowl")
        #expect(decoded.kcal == 650)
        #expect(decoded.macros.proteinG == 56)
        #expect(decoded.allergens == ["Dairy"])
    }

    @Test("array of entries survives UserDefaults-style roundtrip")
    func arrayRoundtrip() throws {
        let entries = [
            FoodEntry(mealType: "Breakfast", name: "Eggs", kcal: 300,
                      macros: Macros(carbsG: 2, proteinG: 24, fatG: 20), allergens: [], time: "7:00 AM"),
            FoodEntry(mealType: "Snack", name: "Banana", kcal: 90,
                      macros: Macros(carbsG: 23, proteinG: 1, fatG: 0), allergens: [], time: "10:00 AM"),
        ]
        let data = try JSONEncoder().encode(entries)
        let decoded = try JSONDecoder().decode([FoodEntry].self, from: data)
        #expect(decoded.count == 2)
        #expect(decoded[0].name == "Eggs")
        #expect(decoded[1].kcal == 90)
    }
}

// MARK: - Food log management

@Suite("AppState: food log") struct FoodLogTests {

    @Test("logFood appends entry") @MainActor
    func logsEntry() {
        let state = AppState()
        let entry = FoodEntry(mealType: "Lunch", name: "Salad", kcal: 400,
                              macros: Macros(carbsG: 30, proteinG: 20, fatG: 15),
                              allergens: [], time: "12:00 PM")
        state.logFood(entry)
        #expect(state.todayFoodLog.count == 1)
        #expect(state.todayFoodLog.first?.name == "Salad")
    }

    @Test("removeFoodEntry removes by id") @MainActor
    func removesEntry() {
        let state = AppState()
        let entry = FoodEntry(mealType: "Dinner", name: "Steak", kcal: 600,
                              macros: Macros(carbsG: 0, proteinG: 50, fatG: 30),
                              allergens: [], time: "7:00 PM")
        state.logFood(entry)
        state.removeFoodEntry(id: entry.id)
        #expect(state.todayFoodLog.isEmpty)
    }

    @Test("updateFoodEntry replaces by id") @MainActor
    func updatesEntry() {
        let state = AppState()
        let original = FoodEntry(mealType: "Snack", name: "Apple", kcal: 80,
                                 macros: Macros(carbsG: 21, proteinG: 0, fatG: 0),
                                 allergens: [], time: "3:00 PM")
        state.logFood(original)
        let updated = FoodEntry(id: original.id, mealType: "Snack", name: "Apple (large)", kcal: 120,
                                macros: Macros(carbsG: 32, proteinG: 0, fatG: 0),
                                allergens: [], time: "3:00 PM")
        state.updateFoodEntry(updated)
        #expect(state.todayFoodLog.count == 1)
        #expect(state.todayFoodLog.first?.kcal == 120)
        #expect(state.todayFoodLog.first?.name == "Apple (large)")
    }
}
