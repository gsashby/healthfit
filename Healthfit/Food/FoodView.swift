//
//  FoodView.swift
//  Macro tracker tied to today's training, meal list, photo-log mock,
//  allergen flagging.
//

import SwiftUI

struct FoodView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingPhotoLog = false

    private var n: DayNutrition { MockData.dayNutrition }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    macroCard
                    pickerHint
                    mealsSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 110)
            }

            // Floating photo-log FAB
            Button {
                showingPhotoLog = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                    Text("Log food")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Theme.green)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
            }
            .padding(.trailing, 18)
            .padding(.bottom, 18)
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingPhotoLog) {
            PhotoLogSheet()
                .presentationDetents([.medium, .large])
        }
    }

    private var todayEyebrow: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM d"
        return "Today · \(fmt.string(from: Date.now))"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(todayEyebrow).eyebrow()
            Text("Eat")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.text)
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: - Macro card

    private var macroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today's fuel").eyebrow()
                Spacer()
                Text(n.dayContext)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.green)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }

            // Calorie ring + remaining
            HStack(spacing: 18) {
                CalorieRing(eaten: n.kcalEaten, target: n.kcalTarget)
                    .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(n.kcalTarget - n.kcalEaten) kcal")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Theme.text)
                    Text("remaining today")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textMuted)
                    Text("Target: \(n.kcalTarget) · Eaten: \(n.kcalEaten)")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textMuted)
                        .padding(.top, 2)
                }

                Spacer()
            }

            // Macro bars
            VStack(spacing: 10) {
                MacroBar(
                    label: "Carbs",
                    eaten: n.macroEaten.carbsG,
                    target: n.macroTarget.carbsG,
                    color: Theme.orange
                )
                MacroBar(
                    label: "Protein",
                    eaten: n.macroEaten.proteinG,
                    target: n.macroTarget.proteinG,
                    color: Theme.green
                )
                MacroBar(
                    label: "Fat",
                    eaten: n.macroEaten.fatG,
                    target: n.macroTarget.fatG,
                    color: Theme.yellow
                )
            }
        }
        .padding(20)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var pickerHint: some View {
        ReasoningCallout(
            title: "Why your protein is high today.",
            message: "It's a lift day — you're targeting 175g protein to support muscle preservation through the cut. Tomorrow drops to 140g (run day).",
            tint: Theme.green
        )
    }

    // MARK: Meals

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's meals").eyebrow()
                .padding(.bottom, 2)

            ForEach(n.entries) { entry in
                MealRow(entry: entry)
            }
        }
    }
}

// MARK: - Calorie ring

private struct CalorieRing: View {
    let eaten: Int
    let target: Int

    private var progress: CGFloat {
        guard target > 0 else { return 0 }
        return min(1, CGFloat(eaten) / CGFloat(target))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.card2, lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [Theme.green, Theme.blue], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
            VStack(spacing: 0) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.text)
                Text("of goal")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textMuted)
            }
        }
    }
}

// MARK: - Macro bar

private struct MacroBar: View {
    let label: String
    let eaten: Int
    let target: Int
    let color: Color

    private var progress: CGFloat {
        guard target > 0 else { return 0 }
        return min(1, CGFloat(eaten) / CGFloat(target))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.text)
                Spacer()
                Text("\(eaten) / \(target)g")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textMuted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.card2)
                    Capsule().fill(color)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Meal row

private struct MealRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji)
                .font(.system(size: 22))
                .frame(width: 44, height: 44)
                .background(Theme.card2)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.mealType)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                        .textCase(.uppercase)
                        .tracking(0.6)
                    Text("·")
                        .foregroundColor(Theme.textMuted)
                    Text(entry.time)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textMuted)
                }
                Text(entry.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.text)
                Text("\(entry.kcal) kcal · C \(entry.macros.carbsG)  P \(entry.macros.proteinG)  F \(entry.macros.fatG)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textMuted)

                if !entry.allergens.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(entry.allergens, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.yellow.opacity(0.18))
                                .foregroundColor(Theme.yellow)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var emoji: String {
        switch entry.mealType.lowercased() {
        case "breakfast": return "🥣"
        case "lunch":     return "🥗"
        case "dinner":    return "🍽️"
        case "snack":     return "🍎"
        default:          return "🍽️"
        }
    }
}

// MARK: - Photo-log sheet (mock)

private struct PhotoLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .scanning

    enum Phase { case scanning, suggestions }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 16) {
                Capsule()
                    .fill(Theme.textMuted.opacity(0.4))
                    .frame(width: 36, height: 4)
                    .padding(.top, 8)

                if phase == .scanning {
                    scanningPhase
                } else {
                    suggestionsPhase
                }
            }
            .padding(.horizontal, 22)
        }
    }

    private var scanningPhase: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(Theme.green)
            Text("Reading the plate…")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.text)
            Text("Identifying ingredients, estimating portions, checking allergens.")
                .font(.system(size: 14))
                .foregroundColor(Theme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .lineSpacing(2)
            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation { phase = .suggestions }
            }
        }
    }

    private var suggestionsPhase: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Is this it?").eyebrow()
                .padding(.top, 6)
            Text("Pick the closest match — I'll log macros and flag allergens.")
                .font(.system(size: 14))
                .foregroundColor(Theme.textMuted)
                .padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(MockData.foodPickerSuggestions.enumerated()), id: \.offset) { _, item in
                        Button {
                            dismiss()
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Theme.text)
                                        .multilineTextAlignment(.leading)
                                    Text("~\(item.kcal) kcal")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textMuted)
                                    if !item.allergens.isEmpty {
                                        HStack(spacing: 4) {
                                            ForEach(item.allergens, id: \.self) { a in
                                                Text(a)
                                                    .font(.system(size: 10, weight: .medium))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Theme.yellow.opacity(0.18))
                                                    .foregroundColor(Theme.yellow)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        .padding(.top, 2)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Theme.textMuted)
                            }
                            .padding(14)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            SecondaryButton(title: "None of these — type it") { dismiss() }
                .padding(.bottom, 8)
        }
    }
}

#Preview {
    NavigationStack { FoodView() }
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
