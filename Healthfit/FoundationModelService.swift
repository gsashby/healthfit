//
//  FoundationModelService.swift
//  All AI capabilities powered by Apple's on-device Foundation Models.
//  Requires Apple Intelligence (iPhone 15 Pro / M-series iPad, iOS 18.1+).
//  Falls back gracefully when the model is unavailable.
//
//  Capabilities:
//   • generateWeekPlan   — structured weekly training plan from free-text input
//   • parseInput         — NLP extraction of goals, activities, constraints
//   • streamCoachReply   — streaming conversational coach response
//   • enhanceReasoning   — richer readiness explanation from raw metrics
//

import FoundationModels
import SwiftUI

// MARK: - Structured output types

@Generable
struct GeneratedPlan {
    @Guide(description: "One sentence summarising the week's structure and philosophy")
    var summary: String
    @Guide(description: "Two sentences explaining the sequencing logic")
    var approach: String
    @Guide(description: "Exactly 7 days, Monday through Sunday")
    var days: [GeneratedDay]
}

@Generable
struct GeneratedDay {
    @Guide(description: "Three-letter abbreviation: Mon Tue Wed Thu Fri Sat Sun")
    var weekday: String
    @Guide(description: "Short label e.g. 'Strength · Upper' or 'Easy aerobic'")
    var tag: String
    var sessions: [GeneratedSession]
}

@Generable
struct GeneratedSession {
    var name: String
    @Guide(description: "Duration in minutes, between 15 and 90")
    var durationMin: Int
    @Guide(description: "Exactly one of: lift run yoga rest")
    var kind: String
}

@Generable
struct ParsedUserInput {
    @Guide(description: "Key fitness goals extracted from the text")
    var goals: [String]
    @Guide(description: "Activities the user mentioned enjoying")
    var preferredActivities: [String]
    @Guide(description: "Desired session length in minutes; use 45 if not specified")
    var sessionLengthMinutes: Int
    @Guide(description: "Any constraints or preferences not captured above")
    var otherConstraints: [String]
}

// MARK: - Chat message

struct ChatMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    var text: String
}

// MARK: - FoundationModelService

@MainActor
final class FoundationModelService: ObservableObject {

    @Published var isAvailable: Bool = false
    @Published var unavailableReason: String = ""

    // Persistent session for the Coach Chat tab (maintains history)
    private var coachSession: LanguageModelSession?

    private static let coachInstructions = """
    You are HealthFit's personal AI coach — evidence-based, motivating, and concise.
    You know the user's fitness goals, current training plan, daily readiness score,
    and nutrition targets. Always give specific, actionable advice tailored to them.
    Use plain text only — no markdown. Keep responses under 120 words unless the user
    asks for a detailed plan.
    """

    init() {
        switch SystemLanguageModel.default.availability {
        case .available:
            isAvailable = true
            coachSession = LanguageModelSession(instructions: Self.coachInstructions)
        case .unavailable(let reason):
            isAvailable = false
            unavailableReason = String(describing: reason)
        }
    }

    // MARK: - Plan generation

    /// Generates a structured 7-day training plan from the user's free-text description.
    /// Creates a fresh session each call to avoid context bleed between plans.
    func generateWeekPlan(
        userDescription: String,
        profile: UserProfile,
        goals: Set<FitnessGoal>,
        trainingType: TrainingType?,
        strengthSplit: StrengthSplit?,
        readinessState: ReadinessState
    ) async throws -> GeneratedPlan {
        guard isAvailable else { throw FMError.notAvailable }

        let session = LanguageModelSession(instructions: """
            You are a certified strength and conditioning coach. Generate structured,
            periodised weekly training plans. Be specific about exercise names.
            Strictly honour the training type and strength split structure the athlete has chosen.
            """)

        var promptLines = [
            "Create a 7-day workout plan for this athlete:",
            "• Age: \(profile.age), Sex: \(profile.sexAtBirth)",
            "• Current weight: \(Int(profile.weightLb)) lbs → Goal: \(Int(profile.goalWeightLb)) lbs",
            "• Training type: \(trainingType?.planDescription ?? "General fitness")",
        ]

        if let split = strengthSplit {
            promptLines.append("• Strength structure: \(split.planDescription)")
            switch split {
            case .fullBody:
                promptLines.append(
                    "  CRITICAL: Every single lift session MUST be a full-body workout — " +
                    "do NOT create separate upper-body or lower-body days. " +
                    "Every strength session must include a lower-body compound (squat or hinge), " +
                    "an upper-body push (press), and an upper-body pull (row or pull). " +
                    "Name each lift session starting with 'Full body strength —' followed by the main movements, " +
                    "e.g. 'Full body strength — squat, bench, row, RDL'.")
            case .ppl:
                promptLines.append(
                    "  Cycle lift sessions strictly through Push → Pull → Lower in order, then repeat. " +
                    "Push = chest, shoulders, triceps. Pull = back, biceps. Lower = quads, hamstrings, glutes. " +
                    "Name each session to reflect the day: 'Push — bench, OHP, triceps', " +
                    "'Pull — row, pull-ups, curls', 'Lower — squat, RDL, lunges'.")
            case .upperLower:
                promptLines.append(
                    "  Alternate lift sessions strictly between upper body and lower body. " +
                    "Upper = chest, back, shoulders, arms. Lower = quads, hamstrings, glutes, calves. " +
                    "Name each session accordingly: 'Upper — bench, row, OHP' or 'Lower — squat, RDL, lunges'.")
            }
        }

        promptLines += [
            "• Goals: \(goals.map(\.rawValue).joined(separator: ", "))",
            "• Today's readiness: \(readinessState.label) — \(readinessState.verdict)",
            "• Athlete's own description: \"\(userDescription)\"",
        ]

        return try await session.respond(
            to: promptLines.joined(separator: "\n"),
            generating: GeneratedPlan.self
        ).content
    }

    // MARK: - Input parsing

    /// Extracts structured intent from the plan free-text input card.
    func parseInput(_ description: String) async throws -> ParsedUserInput {
        guard isAvailable else { throw FMError.notAvailable }

        let session = LanguageModelSession(instructions:
            "You extract structured fitness preferences from natural language.")
        let prompt = "Extract fitness preferences from: \"\(description)\""
        return try await session.respond(to: prompt, generating: ParsedUserInput.self).content
    }

    // MARK: - Coach chat (streaming)

    /// Streams a coach response, yielding partial strings as they arrive.
    func streamCoachReply(
        to message: String,
        context: CoachContext
    ) -> AsyncThrowingStream<String, Error> {
        guard isAvailable, let session = coachSession else {
            return AsyncThrowingStream { $0.finish(throwing: FMError.notAvailable) }
        }

        let contextualPrompt = """
            [Context — Readiness: \(context.readinessScore) (\(context.readinessState)) | \
            Plan: week \(context.planWeek) of \(context.planTotalWeeks)]
            User: \(message)
            """

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await partial in session.streamResponse(to: contextualPrompt) {
                        continuation.yield(partial.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            // Cancel the inner Task when the consumer cancels or the stream finishes,
            // so the model stops generating even if the caller's for-try-await loop exits.
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Resets the coach conversation history.
    func resetCoachSession() {
        guard isAvailable else { return }
        coachSession = LanguageModelSession(instructions: Self.coachInstructions)
    }

    // MARK: - Readiness reasoning enhancement

    /// Takes the rule-based reasoning string and rewrites it to be more natural
    /// and personalised for the specific user.
    func enhanceReadinessReasoning(
        _ reasoning: String,
        userName: String,
        state: ReadinessState
    ) async -> String {
        guard isAvailable else { return reasoning }
        let session = LanguageModelSession(instructions:
            "Rewrite the following fitness readiness message in a warm, personal tone. " +
            "Address the user by first name. Keep it under 40 words. Plain text only.")
        let prompt = "User's name: \(userName). Readiness state: \(state.label). " +
                     "Original message: \(reasoning)"
        return (try? await session.respond(to: prompt).content) ?? reasoning
    }

    // MARK: - Proactive nutrition nudge

    /// Generates one concise coaching sentence about the user's nutrition progress today.
    /// Falls back to an empty string — callers provide their own rule-based fallback.
    func generateCoachNudge(
        kcalLogged: Int,
        kcalTarget: Int,
        proteinLoggedG: Int,
        proteinTargetG: Int,
        sessionKind: String,
        userName: String
    ) async -> String {
        guard isAvailable else { return "" }
        let session = LanguageModelSession(instructions:
            "You are a concise personal fitness coach. Write exactly one motivating sentence " +
            "(under 25 words) about the user's nutrition progress today. " +
            "Be specific and actionable. Plain text only. Address the user by first name.")
        let prompt = """
            Name: \(userName). Today's session: \(sessionKind).
            Logged so far: \(kcalLogged) kcal, \(proteinLoggedG)g protein.
            Daily targets: \(kcalTarget) kcal, \(proteinTargetG)g protein.
            """
        return (try? await session.respond(to: prompt).content) ?? ""
    }

    // MARK: - Daily coach insight

    /// Generates a brief, encouraging coach check-in based on today's health vitals.
    func generateCoachInsight(
        userName: String,
        state: ReadinessState,
        vitals: [Vital],
        workoutSessionName: String
    ) async -> String {
        guard isAvailable else { return "" }
        let vitalsDesc = vitals.map { v in
            "\(v.label): \(v.value)\(v.unit.map { " \($0)" } ?? "") (\(v.trend), trending \(v.trendDir == .up ? "up" : v.trendDir == .down ? "down" : "flat"))"
        }.joined(separator: "; ")
        let session = LanguageModelSession(instructions:
            "You are a warm, encouraging personal fitness coach writing a brief daily check-in. " +
            "Write 2–3 sentences (under 70 words). Comment on one or two specific metrics the user will recognise, " +
            "explain what they mean in plain language, and give one concrete positive recommendation. " +
            "If metrics are trending down, be honest but encouraging — frame it as information, not failure. " +
            "Plain text only. No bullet points. Address the user by first name.")
        let prompt = """
            Name: \(userName). Readiness: \(state.label).
            Today's vitals: \(vitalsDesc).
            Planned session: \(workoutSessionName).
            """
        return (try? await session.respond(to: prompt).content) ?? ""
    }

    // MARK: - End-of-week summary

    /// Generates a short end-of-week coaching summary for the Today tab.
    func generateWeekSummary(
        weekIndex: Int,
        totalWeeks: Int,
        phase: String,
        userName: String
    ) async -> String {
        guard isAvailable else { return "" }
        let session = LanguageModelSession(instructions:
            "You are a motivating fitness coach. Write 1–2 sentences (under 40 words) " +
            "celebrating the user completing a training week and encouraging them to keep going. " +
            "Plain text only. Address the user by first name.")
        let prompt = "Name: \(userName). Just completed week \(weekIndex) of \(totalWeeks) " +
                     "(\(phase) phase). Encourage them to generate their next week's plan."
        return (try? await session.respond(to: prompt).content) ?? ""
    }
}

// MARK: - Supporting types

struct CoachContext {
    let readinessScore: Int
    let readinessState: String
    let planWeek: Int
    let planTotalWeeks: Int
}

enum FMError: LocalizedError {
    case notAvailable
    var errorDescription: String? {
        "Apple Intelligence isn't available on this device. " +
        "Requires iPhone 15 Pro or later running iOS 18.1+."
    }
}
