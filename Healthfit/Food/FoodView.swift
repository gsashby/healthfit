//
//  FoodView.swift
//  Macro tracker tied to today's training, meal list, photo-log mock,
//  allergen flagging.
//

import SwiftUI

struct FoodView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var readinessService: ReadinessService
    @State private var showingPhotoLog = false
    @State private var showingSearch = false
    @State private var entryToEdit: FoodEntry? = nil

    // Mirror TodayView's readiness resolution so targets stay in sync.
    private var activeReadiness: ReadinessState {
        if appState.todayForcesOriginalPlan { return .green }
        return readinessService.latestData?.state ?? appState.readinessState
    }

    // Targets from plan/readiness; eaten values computed from the real food log.
    private var nutrition: DayNutrition {
        let adj = appState.adjustedTodayWorkout(readiness: activeReadiness)
        let logged = appState.todayFoodLog
        let kcalEaten = logged.reduce(0) { $0 + $1.kcal }
        let macroEaten = Macros(
            carbsG:   logged.reduce(0) { $0 + $1.macros.carbsG },
            proteinG: logged.reduce(0) { $0 + $1.macros.proteinG },
            fatG:     logged.reduce(0) { $0 + $1.macros.fatG }
        )
        return DayNutrition(
            kcalTarget: adj.kcalTarget,
            kcalEaten: kcalEaten,
            macroTarget: adj.macros,
            macroEaten: macroEaten,
            allergyAlerts: [],
            dayContext: adj.macroTag,
            entries: logged
        )
    }

    // Dynamic rationale based on today's session type and readiness state.
    private var macroRationale: (title: String, message: String) {
        let adj = appState.adjustedTodayWorkout(readiness: activeReadiness)
        let todayKind = appState.currentPlan.days
            .first(where: { $0.isToday })?
            .sessions
            .first(where: { $0.kind == .lift || $0.kind == .run })?
            .kind ?? .rest

        switch activeReadiness {
        case .red:
            return (
                "Recovery day — targets reduced.",
                "Readiness is suppressed. Carbs drop to match the lighter load; " +
                "protein holds at \(adj.macros.proteinG)g to protect muscle while you recover."
            )
        case .yellow:
            switch todayKind {
            case .lift:
                return (
                    "Lighter lift day targets.",
                    "Today's session is dialled back ~20%. Protein is set at \(adj.macros.proteinG)g " +
                    "to support repair, with moderate carbs to fuel the reduced intensity."
                )
            case .run:
                return (
                    "Easy run day targets.",
                    "Readiness is mixed so the run is easier today. Carbs are moderate at " +
                    "\(adj.macros.carbsG)g; protein stays at \(adj.macros.proteinG)g."
                )
            default:
                return (
                    "Moderate targets today.",
                    "Targets are adjusted to match your readiness. Protein stays elevated " +
                    "at \(adj.macros.proteinG)g to support recovery."
                )
            }
        case .green:
            switch todayKind {
            case .lift:
                return (
                    "Why protein is high today.",
                    "Lift days prioritise muscle protein synthesis — you're targeting " +
                    "\(adj.macros.proteinG)g. Carbs are set at \(adj.macros.carbsG)g " +
                    "to fuel the session and restore glycogen."
                )
            case .run:
                return (
                    "Why carbs are high today.",
                    "Running depletes glycogen — \(adj.macros.carbsG)g carbs fuel your output " +
                    "and top up stores post-run. Protein holds at \(adj.macros.proteinG)g for recovery."
                )
            default:
                return (
                    "Rest day targets.",
                    "Carbs are lower today since glycogen isn't being depleted. Protein stays " +
                    "at \(adj.macros.proteinG)g to keep muscle protein synthesis elevated."
                )
            }
        }
    }

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

            // Floating "Log food" FAB — menu offers search or camera
            Menu {
                Button {
                    showingSearch = true
                } label: {
                    Label("Search food database", systemImage: "magnifyingglass")
                }
                Button {
                    showingPhotoLog = true
                } label: {
                    Label("Scan with camera", systemImage: "camera")
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
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
        }
        .sheet(isPresented: $showingSearch) {
            FoodSearchView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showingPhotoLog) {
            PhotoLogSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $entryToEdit) { entry in
            EditEntrySheet(entry: entry)
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
                Text(nutrition.dayContext)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.green)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }

            // Calorie ring + remaining
            HStack(spacing: 18) {
                CalorieRing(eaten: nutrition.kcalEaten, target: nutrition.kcalTarget)
                    .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(max(0, nutrition.kcalTarget - nutrition.kcalEaten)) kcal")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Theme.text)
                    Text("remaining today")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textMuted)
                    Text("Target: \(nutrition.kcalTarget) · Eaten: \(nutrition.kcalEaten)")
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
                    eaten: nutrition.macroEaten.carbsG,
                    target: nutrition.macroTarget.carbsG,
                    color: Theme.orange
                )
                MacroBar(
                    label: "Protein",
                    eaten: nutrition.macroEaten.proteinG,
                    target: nutrition.macroTarget.proteinG,
                    color: Theme.green
                )
                MacroBar(
                    label: "Fat",
                    eaten: nutrition.macroEaten.fatG,
                    target: nutrition.macroTarget.fatG,
                    color: Theme.yellow
                )
            }
        }
        .padding(20)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var pickerHint: some View {
        let r = macroRationale
        return ReasoningCallout(
            title: r.title,
            message: r.message,
            tint: Theme.green
        )
    }

    // MARK: Meals

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's meals").eyebrow().padding(.bottom, 2)

            if appState.todayFoodLog.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(Theme.textMuted)
                    Text("Nothing logged yet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                    Text("Tap \"Log food\" to add your first meal.")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textMuted.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ForEach(appState.todayFoodLog) { entry in
                    MealRow(entry: entry,
                            userAllergens: Set(appState.dietaryProfile.allergies))
                        .swipeActions(edge: .leading) {
                            Button {
                                entryToEdit = entry
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(Theme.blue)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    appState.removeFoodEntry(id: entry.id)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
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
    var userAllergens: Set<String> = []

    private var hasUserAllergen: Bool {
        entry.allergens.contains { userAllergens.contains($0) }
    }

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
                    Text("·").foregroundColor(Theme.textMuted)
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

                if hasUserAllergen {
                    Label("Contains your allergens", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.red)
                        .padding(.top, 2)
                }

                if !entry.allergens.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(entry.allergens, id: \.self) { tag in
                            let isMatch = userAllergens.contains(tag)
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(isMatch ? Theme.red.opacity(0.18) : Theme.yellow.opacity(0.18))
                                .foregroundColor(isMatch ? Theme.red : Theme.yellow)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(hasUserAllergen ? Theme.red.opacity(0.06) : Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(hasUserAllergen ? Theme.red.opacity(0.3) : .clear, lineWidth: 1)
        )
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

// MARK: - Photo-log sheet

private struct PhotoLogSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    enum Phase { case scanning, suggestions, manual }
    @State private var phase: Phase = .scanning
    @State private var mealType: String = {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<10: return "Breakfast"
        case 10..<15: return "Lunch"
        case 15..<21: return "Dinner"
        default:      return "Snack"
        }
    }()

    private let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snack"]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 16) {
                Capsule()
                    .fill(Theme.textMuted.opacity(0.4))
                    .frame(width: 36, height: 4)
                    .padding(.top, 8)

                switch phase {
                case .scanning:    scanningPhase
                case .suggestions: suggestionsPhase
                case .manual:      manualPhase
                }
            }
            .padding(.horizontal, 22)
        }
    }

    // MARK: Scanning

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

    // MARK: Suggestions

    private var suggestionsPhase: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Is this it?").eyebrow().padding(.top, 6)
            Text("Pick the closest match — I'll log macros and flag allergens.")
                .font(.system(size: 14))
                .foregroundColor(Theme.textMuted)

            Picker("Meal", selection: $mealType) {
                ForEach(mealTypes, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 4)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(MockData.foodPickerSuggestions.enumerated()), id: \.offset) { _, item in
                        let userAllergens = Set(appState.dietaryProfile.allergies)
                        let hasMatch = item.allergens.contains { userAllergens.contains($0) }
                        Button { logSuggestion(item) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Theme.text)
                                        .multilineTextAlignment(.leading)
                                    Text("~\(item.kcal) kcal")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textMuted)
                                    if hasMatch {
                                        Label("Contains your allergens",
                                              systemImage: "exclamationmark.triangle.fill")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(Theme.red)
                                            .padding(.top, 2)
                                    }
                                    if !item.allergens.isEmpty {
                                        FlowLayout(spacing: 4) {
                                            ForEach(item.allergens, id: \.self) { a in
                                                let isMatch = userAllergens.contains(a)
                                                Text(a)
                                                    .font(.system(size: 10, weight: .medium))
                                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                                    .background(isMatch ? Theme.red.opacity(0.18) : Theme.yellow.opacity(0.18))
                                                    .foregroundColor(isMatch ? Theme.red : Theme.yellow)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        .padding(.top, 2)
                                    }
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(Theme.green)
                                    .font(.system(size: 20))
                            }
                            .padding(14)
                            .background(hasMatch ? Theme.red.opacity(0.06) : Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(hasMatch ? Theme.red.opacity(0.3) : .clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            SecondaryButton(title: "None of these — type it") {
                withAnimation { phase = .manual }
            }
            .padding(.bottom, 8)
        }
    }

    private func logSuggestion(_ item: (name: String, kcal: Int, allergens: [String])) {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        appState.logFood(FoodEntry(
            mealType: mealType,
            name: item.name,
            kcal: item.kcal,
            macros: Macros(carbsG: 0, proteinG: 0, fatG: 0),
            allergens: item.allergens,
            time: fmt.string(from: Date())
        ))
        dismiss()
    }

    // MARK: Manual entry

    private var manualPhase: some View {
        FoodEntryForm(defaultMealType: mealType, onDone: { dismiss() })
    }
}

// MARK: - Edit entry sheet (presented from FoodView)

private struct EditEntrySheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let entry: FoodEntry

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                FoodEntryForm(existingEntry: entry, defaultMealType: entry.mealType,
                              onDone: { dismiss() })
                    .padding(.horizontal, 22)
            }
            .navigationTitle("Edit meal")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(Theme.textMuted)
                }
            }
        }
    }
}

// MARK: - Shared entry form (add and edit)

private struct FoodEntryForm: View {
    @EnvironmentObject var appState: AppState

    let existingEntry: FoodEntry?
    let defaultMealType: String
    let onDone: () -> Void

    @State private var name: String
    @State private var kcalStr: String
    @State private var carbsStr: String
    @State private var proteinStr: String
    @State private var fatStr: String
    @State private var mealType: String

    private let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snack"]
    private var isEditing: Bool { existingEntry != nil }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && Int(kcalStr) != nil
    }

    init(existingEntry: FoodEntry? = nil, defaultMealType: String, onDone: @escaping () -> Void) {
        self.existingEntry = existingEntry
        self.defaultMealType = defaultMealType
        self.onDone = onDone
        if let e = existingEntry {
            _name       = State(initialValue: e.name)
            _kcalStr    = State(initialValue: "\(e.kcal)")
            _carbsStr   = State(initialValue: e.macros.carbsG   > 0 ? "\(e.macros.carbsG)"   : "")
            _proteinStr = State(initialValue: e.macros.proteinG > 0 ? "\(e.macros.proteinG)" : "")
            _fatStr     = State(initialValue: e.macros.fatG     > 0 ? "\(e.macros.fatG)"     : "")
            _mealType   = State(initialValue: e.mealType)
        } else {
            _name = State(initialValue: ""); _kcalStr = State(initialValue: "")
            _carbsStr = State(initialValue: ""); _proteinStr = State(initialValue: "")
            _fatStr = State(initialValue: ""); _mealType = State(initialValue: defaultMealType)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !isEditing {
                Text("Log manually").eyebrow().padding(.top, 6)
            }
            Text("Calories are required — macros are optional.")
                .font(.system(size: 14)).foregroundColor(Theme.textMuted)

            Picker("Meal", selection: $mealType) {
                ForEach(mealTypes, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)

            entryField("Food name", placeholder: "e.g. Chicken rice bowl", text: $name)
            entryField("Calories", placeholder: "e.g. 450", text: $kcalStr, isNumeric: true)
            HStack(spacing: 8) {
                entryField("Carbs (g)",   placeholder: "0", text: $carbsStr,   isNumeric: true)
                entryField("Protein (g)", placeholder: "0", text: $proteinStr, isNumeric: true)
                entryField("Fat (g)",     placeholder: "0", text: $fatStr,     isNumeric: true)
            }

            Spacer()

            PrimaryButton(
                title: canSave
                    ? (isEditing ? "Save changes" : "Log it")
                    : "Enter a name and calories",
                tint: canSave ? Theme.green : Theme.card2
            ) {
                guard canSave else { return }
                save()
            }
            .disabled(!canSave)
            .padding(.bottom, 8)
        }
    }

    private func entryField(_ label: String, placeholder: String,
                             text: Binding<String>, isNumeric: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textMuted)
                .textCase(.uppercase).tracking(0.5)
            TextField(placeholder, text: text)
                .font(.system(size: 15)).foregroundColor(Theme.text)
                .padding(12).background(Theme.card2)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                #if canImport(UIKit)
                .keyboardType(isNumeric ? .numberPad : .default)
                #endif
        }
    }

    private func save() {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        let entry = FoodEntry(
            id:        existingEntry?.id ?? UUID(),
            mealType:  mealType,
            name:      name.trimmingCharacters(in: .whitespaces),
            kcal:      Int(kcalStr) ?? 0,
            macros:    Macros(carbsG:   Int(carbsStr) ?? 0,
                              proteinG: Int(proteinStr) ?? 0,
                              fatG:     Int(fatStr) ?? 0),
            allergens: existingEntry?.allergens ?? [],
            time:      existingEntry?.time ?? fmt.string(from: Date())
        )
        if isEditing {
            appState.updateFoodEntry(entry)
        } else {
            appState.logFood(entry)
        }
        onDone()
    }
}

#Preview {
    NavigationStack { FoodView() }
        .environmentObject(AppState())
        .environmentObject(ReadinessService())
        .preferredColorScheme(.dark)
}
