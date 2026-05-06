//
//  MockData.swift
//  All simulated data the prototype needs. When wiring real APIs, swap these
//  out individually — nothing else in the app touches data construction.
//

import Foundation

enum MockData {

    // MARK: - User

    static let demoUser = UserProfile(
        name: "Gerald",
        age: 50,
        sexAtBirth: "Male",
        weightLb: 198,
        goalWeightLb: 178,
        description: """
        I am a 50-year-old male. I like to run and lift weights. \
        My primary goal is to stay in shape, retain muscle (and build a bit), \
        I would like to lose about 20 pounds. Keep my workouts to 45 minutes \
        on average. I would like a 15-minute stretching recommendation every \
        day (based on yoga).
        """
    )

    // MARK: - Readiness snapshots, one per state

    static func readiness(for state: ReadinessState) -> ReadinessSnapshot {
        switch state {
        case .green:
            return ReadinessSnapshot(
                state: .green,
                score: 87,
                vitals: [
                    Vital(label: "HRV", value: "62", unit: "ms", trend: "↑ 8% vs 14d", trendDir: .up),
                    Vital(label: "Sleep", value: "7h 42m", unit: nil, trend: "89 score", trendDir: .up),
                    Vital(label: "Resting HR", value: "52", unit: "bpm", trend: "at baseline", trendDir: .flat)
                ],
                workoutTitle: "Today · Week 1 of 12",
                workoutName: "Lower body strength",
                workoutMeta: "~45 min · Lift · Moderate-high",
                workoutChips: ["Back squat 4×6", "RDL 3×8", "Walking lunge 3×10", "Calf raise 3×12"],
                workoutTag: "As planned",
                reasoning: "Week 1 of your hybrid plan, lower-body day. HRV trend is strong and you slept deep — the planned lift stands.",
                kcalTarget: 2180,
                macros: Macros(carbsG: 220, proteinG: 175, fatG: 75),
                macroTag: "Lift day · +protein"
            )
        case .yellow:
            return ReadinessSnapshot(
                state: .yellow,
                score: 62,
                vitals: [
                    Vital(label: "HRV", value: "54", unit: "ms", trend: "−2% vs 14d", trendDir: .flat),
                    Vital(label: "Sleep", value: "6h 04m", unit: nil, trend: "62 score", trendDir: .down),
                    Vital(label: "Resting HR", value: "55", unit: "bpm", trend: "+3 bpm", trendDir: .down)
                ],
                workoutTitle: "Today · Week 1 of 12",
                workoutName: "Lower body, lighter",
                workoutMeta: "~38 min · Lift · Moderate",
                workoutChips: ["Goblet squat 3×8", "RDL 3×8 (lighter)", "Lunge 3×8", "Skip calves"],
                workoutTag: "Adjusted",
                reasoning: "Original was a heavier back-squat day. Sleep dropped below your 7-day average and resting HR is up — we cut load by ~20% and dropped the accessory volume. Plan stays on track.",
                kcalTarget: 2080,
                macros: Macros(carbsG: 200, proteinG: 170, fatG: 75),
                macroTag: "Moderate day"
            )
        case .red:
            return ReadinessSnapshot(
                state: .red,
                score: 38,
                vitals: [
                    Vital(label: "HRV", value: "38", unit: "ms", trend: "↓ 18% vs 14d", trendDir: .down),
                    Vital(label: "Sleep", value: "5h 12m", unit: nil, trend: "54 score", trendDir: .down),
                    Vital(label: "Resting HR", value: "59", unit: "bpm", trend: "+7 bpm", trendDir: .down)
                ],
                workoutTitle: "Today · Week 1 of 12",
                workoutName: "Easy Z2 walk + mobility",
                workoutMeta: "~30 min · Recovery",
                workoutChips: ["20 min easy walk", "~110 bpm cap", "10 min mobility"],
                workoutTag: "Adjusted",
                reasoning: "Original was a heavy lower-body lift. With HRV down 18% and only 5h of sleep, that load would compound the deficit. Easy movement keeps the habit, lets you recover, and we'll move the lift to Friday.",
                kcalTarget: 1920,
                macros: Macros(carbsG: 160, proteinG: 175, fatG: 75),
                macroTag: "Recovery · −carbs"
            )
        }
    }

    // MARK: - Plan: hybrid week matching the demo user's goals

    static let hybridWeek = WeekPlan(
        weekIndex: 1,
        totalWeeks: 12,
        phase: "Base",
        days: [
            PlanDay(weekday: "Mon", dayNumber: 27, tag: "Strength · Upper", isToday: false, sessions: [
                PlanSession(kind: .lift, name: "Upper body lift", durationMin: 45),
                PlanSession(kind: .yoga, name: "Sun salutation flow", durationMin: 15)
            ]),
            PlanDay(weekday: "Tue", dayNumber: 28, tag: "Easy aerobic", isToday: false, sessions: [
                PlanSession(kind: .run, name: "Easy Z2 run", durationMin: 45),
                PlanSession(kind: .yoga, name: "Hip openers", durationMin: 15)
            ]),
            PlanDay(weekday: "Wed", dayNumber: 29, tag: "Today · Strength · Lower", isToday: true, sessions: [
                PlanSession(kind: .lift, name: "Lower body lift", durationMin: 45),
                PlanSession(kind: .yoga, name: "Hamstring + quad release", durationMin: 15)
            ]),
            PlanDay(weekday: "Thu", dayNumber: 30, tag: "Active recovery", isToday: false, sessions: [
                PlanSession(kind: .rest, name: "Easy walk + mobility", durationMin: 30),
                PlanSession(kind: .yoga, name: "Yin / restorative", durationMin: 15)
            ]),
            PlanDay(weekday: "Fri", dayNumber: 1, tag: "Quality run", isToday: false, sessions: [
                PlanSession(kind: .run, name: "Tempo intervals", durationMin: 45),
                PlanSession(kind: .yoga, name: "Lower-body release", durationMin: 15)
            ]),
            PlanDay(weekday: "Sat", dayNumber: 2, tag: "Strength · Full body", isToday: false, sessions: [
                PlanSession(kind: .lift, name: "Full-body circuit", durationMin: 45),
                PlanSession(kind: .yoga, name: "Power flow", durationMin: 15)
            ]),
            PlanDay(weekday: "Sun", dayNumber: 3, tag: "Long easy", isToday: false, sessions: [
                PlanSession(kind: .run, name: "Long easy run", durationMin: 45),
                PlanSession(kind: .yoga, name: "Restorative", durationMin: 15)
            ])
        ],
        summary: "Built around what you said: 45-min sessions, run + lift, yoga every day. Lifts come first when fresh; runs are split between easy aerobic and one quality session.",
        approach: "Two lifts before runs (fresh CNS), one quality run mid-week with a recovery day in front of it, long easy run on Sunday so Monday's lift starts the week strong. Yoga is short and matched to what you did that day."
    )

    static let parsedInput: [ParsedInput] = [
        ParsedInput(key: "Profile",        value: "50 · Male"),
        ParsedInput(key: "Goals",          value: "Lose 20 lb · Retain muscle · Build slightly"),
        ParsedInput(key: "Modalities",     value: "Run + Lift (hybrid) + daily yoga"),
        ParsedInput(key: "Workout length", value: "~45 min"),
        ParsedInput(key: "Daily mobility", value: "15 min yoga"),
        ParsedInput(key: "Cadence",        value: "5 sessions + 2 active recovery")
    ]

    // MARK: - Food / nutrition

    static let dayNutrition = DayNutrition(
        kcalTarget: 2180,
        kcalEaten: 1340,
        macroTarget: Macros(carbsG: 220, proteinG: 175, fatG: 75),
        macroEaten:  Macros(carbsG: 142, proteinG: 108, fatG: 48),
        allergyAlerts: [],
        dayContext: "Lift day · +protein",
        entries: [
            FoodEntry(mealType: "Breakfast", name: "Greek yogurt + berries + granola",
                      kcal: 410, macros: Macros(carbsG: 52, proteinG: 28, fatG: 11),
                      allergens: ["Dairy", "Gluten"], time: "7:14 AM"),
            FoodEntry(mealType: "Snack", name: "Banana + almond butter",
                      kcal: 280, macros: Macros(carbsG: 32, proteinG: 6, fatG: 16),
                      allergens: ["Tree nuts"], time: "10:02 AM"),
            FoodEntry(mealType: "Lunch", name: "Chicken rice bowl, broccoli",
                      kcal: 650, macros: Macros(carbsG: 58, proteinG: 56, fatG: 18),
                      allergens: [], time: "12:38 PM")
        ]
    )

    // Sample food picker for the photo-log mock
    static let foodPickerSuggestions: [(name: String, kcal: Int, allergens: [String])] = [
        ("Grilled salmon, sweet potato, asparagus", 540, []),
        ("Turkey + avocado wrap", 480, ["Gluten"]),
        ("Protein smoothie (whey, banana, oat milk)", 360, ["Dairy"]),
        ("Tofu stir-fry, brown rice", 510, ["Soy"]),
        ("Chicken Caesar salad", 470, ["Dairy", "Gluten", "Egg"])
    ]
}
