//
//  Models.swift
//  All data models for the prototype. Kept in one file because there aren't
//  many of them and the prototype's complexity doesn't warrant a Models/ folder.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - User

struct UserProfile: Codable {
    var name: String
    var age: Int
    var sexAtBirth: String
    var weightLb: Double
    var goalWeightLb: Double
    var description: String     // free-text from Plan input
}

// MARK: - Goals

enum FitnessGoal: String, Codable, CaseIterable, Identifiable {
    case getStrong       = "Get strong"
    case race            = "Train for a race"
    case sAndC           = "Strength & conditioning"
    case loseWeight      = "Lose weight, retain muscle"
    case general         = "Stay in shape"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .getStrong:  return "🏋️"
        case .race:       return "🏃"
        case .sAndC:      return "🤸"
        case .loseWeight: return "⚖️"
        case .general:    return "💪"
        }
    }

    var subtitle: String {
        switch self {
        case .getStrong:  return "Compound lifts, progressive overload"
        case .race:       return "5K, 10K, half, or full marathon"
        case .sAndC:      return "Hybrid lifting + conditioning"
        case .loseWeight: return "Calorie deficit, preserve muscle"
        case .general:    return "Mixed, maintain habits"
        }
    }
}

// MARK: - Training Type (onboarding)

enum TrainingType: String, Codable, CaseIterable, Identifiable {
    case strength           = "Strength training"
    case running            = "Running"
    case functionalFitness  = "Functional fitness"
    case hybridRunStrength  = "Hybrid: Running & strength"
    case biking             = "Biking"
    case hybridRunBiking    = "Hybrid: Running & biking"
    case hybridAll          = "Hybrid: Running, biking & strength"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .strength:          return "🏋️"
        case .running:           return "🏃"
        case .functionalFitness: return "🤸"
        case .hybridRunStrength: return "⚡️"
        case .biking:            return "🚴"
        case .hybridRunBiking:   return "🚵"
        case .hybridAll:         return "🔥"
        }
    }

    var subtitle: String {
        switch self {
        case .strength:          return "Compound lifts, progressive overload"
        case .running:           return "Road, track, or trail — all distances"
        case .functionalFitness: return "Bodyweight, HIIT, and mobility work"
        case .hybridRunStrength: return "Balance running and weight training"
        case .biking:            return "Road cycling, mountain bike, or indoor"
        case .hybridRunBiking:   return "Combine two endurance disciplines"
        case .hybridAll:         return "Run, ride, and lift — the full picture"
        }
    }

    var isHybrid: Bool {
        switch self {
        case .hybridRunStrength, .hybridRunBiking, .hybridAll: return true
        default: return false
        }
    }

    var includesStrength: Bool {
        switch self {
        case .strength, .hybridRunStrength, .hybridAll: return true
        default: return false
        }
    }

    var includesRun: Bool {
        switch self {
        case .running, .hybridRunStrength, .hybridRunBiking, .hybridAll: return true
        default: return false
        }
    }

    /// Human-readable description passed to the AI prompt.
    var planDescription: String {
        switch self {
        case .strength:          return "Pure strength training — no aerobic sessions"
        case .running:           return "Running / endurance only — no lifting"
        case .functionalFitness: return "Functional fitness — bodyweight, HIIT, and mobility"
        case .hybridRunStrength: return "Hybrid: running and strength training combined"
        case .biking:            return "Cycling — road, indoor, or mountain bike"
        case .hybridRunBiking:   return "Hybrid: running and cycling combined"
        case .hybridAll:         return "Hybrid: running, cycling, and strength training combined"
        }
    }

    var priorityOptions: [(label: String, emoji: String)] {
        switch self {
        case .hybridRunStrength: return [("Running", "🏃"), ("Strength", "🏋️")]
        case .hybridRunBiking:   return [("Running", "🏃"), ("Biking", "🚴")]
        case .hybridAll:         return [("Running", "🏃"), ("Biking", "🚴"), ("Strength", "🏋️")]
        default: return []
        }
    }
}

// MARK: - Strength Split (onboarding)

enum StrengthSplit: String, Codable, CaseIterable, Identifiable {
    case fullBody   = "Full body"
    case ppl        = "Push, Pull, Lower (PPL)"
    case upperLower = "Upper & lower split"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .fullBody:   return "💪"
        case .ppl:        return "🔁"
        case .upperLower: return "↕️"
        }
    }

    var subtitle: String {
        switch self {
        case .fullBody:   return "Train all muscle groups in every session"
        case .ppl:        return "Rotate through push, pull, and lower days"
        case .upperLower: return "Alternate upper and lower body sessions"
        }
    }

    /// Injected verbatim into the AI prompt so the model understands the split structure.
    var planDescription: String {
        switch self {
        case .fullBody:
            return "Full body — every strength session trains all major muscle groups " +
                   "(squat, hinge, push, pull, carry pattern)"
        case .ppl:
            return "Push/Pull/Lower (PPL) — cycle strength days through " +
                   "Push (chest, shoulders, triceps), Pull (back, biceps), " +
                   "and Lower (quads, hamstrings, glutes) in that order"
        case .upperLower:
            return "Upper & lower split — alternate strength days between " +
                   "upper body (chest, back, shoulders, arms) and " +
                   "lower body (quads, hamstrings, glutes, calves)"
        }
    }
}

// MARK: - Readiness (Today briefing)

enum ReadinessState: String, CaseIterable, Identifiable {
    case green
    case yellow
    case red
    var id: String { rawValue }

    var label: String {
        switch self {
        case .green:  return "Primed"
        case .yellow: return "Mixed"
        case .red:    return "Recover"
        }
    }

    var verdict: String {
        switch self {
        case .green:
            return "HRV is up, sleep was deep. Today's a green light to push."
        case .yellow:
            return "HRV is fine, but sleep was light. We'll dial intensity back a notch."
        case .red:
            return "Recovery is suppressed. Pushing today costs more than it earns."
        }
    }
}

struct Vital: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let unit: String?
    let trend: String
    let trendDir: TrendDir
}

enum TrendDir { case up, down, flat }

struct ReadinessSnapshot {
    let state: ReadinessState
    let score: Int
    let vitals: [Vital]
    let workoutTitle: String
    let workoutName: String
    let workoutMeta: String
    let workoutChips: [String]
    let workoutTag: String       // "As planned" / "Adjusted"
    let reasoning: String
    let kcalTarget: Int
    let macros: Macros
    let macroTag: String
}

struct Macros: Codable {
    let carbsG: Int
    let proteinG: Int
    let fatG: Int
}

// MARK: - Plan

struct WeekPlan: Identifiable {
    let id = UUID()
    let weekIndex: Int        // 1 of 12
    let totalWeeks: Int
    let phase: String         // "Base", "Build", "Peak"…
    var days: [PlanDay]
    let summary: String
    let approach: String
}

struct PlanDay: Identifiable {
    let id = UUID()
    let weekday: String       // "Mon"
    let dayNumber: Int        // 27
    let tag: String           // "Strength · Lower"
    let isToday: Bool
    let sessions: [PlanSession]
}

struct PlanSession: Identifiable {
    let id = UUID()
    let kind: SessionKind
    let name: String
    let durationMin: Int
}

enum SessionKind: String {
    case lift, run, yoga, rest

    var emoji: String {
        switch self {
        case .lift: return "🏋️"
        case .run:  return "🏃"
        case .yoga: return "🧘"
        case .rest: return "🚶"
        }
    }

    var tint: Color {
        switch self {
        case .lift: return Theme.orange
        case .run:  return Theme.green
        case .yoga: return Theme.purple
        case .rest: return Theme.textMuted
        }
    }
}

struct ParsedInput: Identifiable {
    let id = UUID()
    let key: String
    let value: String
}

// MARK: - Food / Nutrition

struct FoodEntry: Identifiable, Codable {
    let id: UUID
    let mealType: String      // "Breakfast"
    let name: String
    let kcal: Int
    let macros: Macros
    let allergens: [String]
    let time: String

    init(id: UUID = UUID(), mealType: String, name: String, kcal: Int,
         macros: Macros, allergens: [String], time: String) {
        self.id = id
        self.mealType = mealType
        self.name = name
        self.kcal = kcal
        self.macros = macros
        self.allergens = allergens
        self.time = time
    }
}

struct DayNutrition {
    let kcalTarget: Int
    let kcalEaten: Int
    let macroTarget: Macros
    let macroEaten: Macros
    let allergyAlerts: [String]
    let dayContext: String     // "Lift day · +protein"
    let entries: [FoodEntry]
}

// MARK: - Allergies / preferences

struct DietaryProfile: Codable {
    var allergies: [String]
    var preferences: [String]   // "vegetarian", "high-protein", etc.
    var dislikes: [String]
}

// MARK: - Persistence

@Model
final class PersistedProfile {
    var name: String = ""
    var age: Int = 0
    var sexAtBirth: String = "Male"
    var weightLb: Double = 0
    var goalWeightLb: Double = 0
    var planDescription: String = ""
    var selectedGoalIDs: [String] = []
    var hasOnboarded: Bool = false
    var watchConnected: Bool = false
    var trainingTypeID: String = ""
    var daysPerWeek: Int = 4
    var prioritizedDiscipline: String = ""
    var strengthSplitID: String = ""
    var dietaryAllergies: [String] = []
    var dietaryPreferences: [String] = []
    var dietaryDislikes: [String] = []

    init() {}

    var asUserProfile: UserProfile {
        UserProfile(name: name, age: age, sexAtBirth: sexAtBirth,
                    weightLb: weightLb, goalWeightLb: goalWeightLb,
                    description: planDescription)
    }

    var selectedGoals: Set<FitnessGoal> {
        Set(selectedGoalIDs.compactMap { FitnessGoal(rawValue: $0) })
    }

    var trainingType: TrainingType? {
        TrainingType(rawValue: trainingTypeID)
    }

    var strengthSplit: StrengthSplit? {
        StrengthSplit(rawValue: strengthSplitID)
    }

    var dietaryProfile: DietaryProfile {
        DietaryProfile(allergies: dietaryAllergies,
                       preferences: dietaryPreferences,
                       dislikes: dietaryDislikes)
    }
}
