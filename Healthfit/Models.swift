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

struct Macros {
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

struct FoodEntry: Identifiable {
    let id = UUID()
    let mealType: String      // "Breakfast"
    let name: String
    let kcal: Int
    let macros: Macros
    let allergens: [String]
    let time: String
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

    init() {}

    var asUserProfile: UserProfile {
        UserProfile(name: name, age: age, sexAtBirth: sexAtBirth,
                    weightLb: weightLb, goalWeightLb: goalWeightLb,
                    description: planDescription)
    }

    var selectedGoals: Set<FitnessGoal> {
        Set(selectedGoalIDs.compactMap { FitnessGoal(rawValue: $0) })
    }
}
