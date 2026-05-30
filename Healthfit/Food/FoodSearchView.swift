//
//  FoodSearchView.swift
//  Full-screen food database search backed by USDA FoodData Central.
//  Tapping a result opens SearchResultSheet where the user picks serving
//  count and meal type before logging.
//

import SwiftUI

// MARK: - Main search view

struct FoodSearchView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var db = FoodDatabaseService()

    @State private var query = ""
    @State private var selectedResult: FoodSearchResult? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchBar
                    resultContent
                }
            }
            .navigationTitle("Search food")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(Theme.textMuted)
                }
            }
        }
        .sheet(item: $selectedResult) { result in
            SearchResultSheet(result: result)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: db.isSearching ? "arrow.clockwise" : "magnifyingglass")
                .foregroundColor(db.isSearching ? Theme.green : Theme.textMuted)
                .symbolEffect(.rotate, isActive: db.isSearching)

            TextField("Search foods…", text: $query)
                .font(.system(size: 16))
                .foregroundColor(Theme.text)
                .autocorrectionDisabled()
                #if canImport(UIKit)
                .textInputAutocapitalization(.never)
                #endif
                .onChange(of: query) { _, new in db.search(query: new) }

            if !query.isEmpty {
                Button {
                    query = ""
                    db.results = []
                    db.errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Theme.textMuted)
                }
            }
        }
        .padding(12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: Result states

    @ViewBuilder
    private var resultContent: some View {
        if db.isSearching && db.results.isEmpty {
            Spacer()
            ProgressView("Searching…").tint(Theme.green)
            Spacer()
        } else if let err = db.errorMessage {
            emptyState(icon: "wifi.slash", message: err)
        } else if query.trimmingCharacters(in: .whitespaces).isEmpty {
            emptyState(icon: "magnifyingglass", message: "Type a food name to search")
        } else if db.results.isEmpty {
            emptyState(icon: "questionmark.circle", message: "No results for \"\(query)\"")
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(db.results) { result in
                        FoodResultRow(result: result)
                            .onTapGesture { selectedResult = result }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
            }
        }
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 38, weight: .light))
                    .foregroundColor(Theme.textMuted)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
    }
}

// MARK: - Result row

private struct FoodResultRow: View {
    let result: FoodSearchResult

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text("\(result.kcalPerServing) kcal")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.green)
                    Text("C \(result.carbsPerServing)g  P \(result.proteinPerServing)g  F \(result.fatPerServing)g")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textMuted)
                }
                Text("per \(Int(result.servingSizeG))g serving")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textMuted.opacity(0.7))
            }
            Spacer()
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(Theme.green)
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Serving picker + confirm sheet

private struct SearchResultSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let result: FoodSearchResult

    @State private var servings: Double = 1.0
    @State private var mealType: String

    private let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snack"]

    init(result: FoodSearchResult) {
        self.result = result
        let h = Calendar.current.component(.hour, from: Date())
        let auto: String
        switch h {
        case 5..<10:  auto = "Breakfast"
        case 10..<15: auto = "Lunch"
        case 15..<21: auto = "Dinner"
        default:      auto = "Snack"
        }
        _mealType = State(initialValue: auto)
    }

    private func scale(_ base: Int) -> Int { Int((Double(base) * servings).rounded()) }
    private var kcal:    Int { scale(result.kcalPerServing) }
    private var carbs:   Int { scale(result.carbsPerServing) }
    private var protein: Int { scale(result.proteinPerServing) }
    private var fat:     Int { scale(result.fatPerServing) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                // Handle
                Capsule()
                    .fill(Theme.textMuted.opacity(0.4))
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                // Food name
                VStack(alignment: .leading, spacing: 2) {
                    if let brand = result.brand, !brand.isEmpty {
                        Text(brand).font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.textMuted).textCase(.uppercase).tracking(0.5)
                    }
                    Text(result.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.text)
                }

                // Live macro summary
                HStack(spacing: 0) {
                    macroCell("\(kcal)",    "kcal",    Theme.green)
                    Divider().frame(height: 36)
                    macroCell("\(carbs)g",  "carbs",   Theme.orange)
                    Divider().frame(height: 36)
                    macroCell("\(protein)g","protein", Theme.green)
                    Divider().frame(height: 36)
                    macroCell("\(fat)g",    "fat",     Theme.yellow)
                }
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Serving picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("Servings").eyebrow()
                    HStack {
                        Button {
                            if servings > 0.5 { withAnimation { servings -= 0.5 } }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(servings > 0.5 ? Theme.blue : Theme.card2)
                        }
                        .disabled(servings <= 0.5)

                        Spacer()
                        VStack(spacing: 2) {
                            Text(servings.truncatingRemainder(dividingBy: 1) == 0
                                 ? "\(Int(servings))"
                                 : String(format: "%.1f", servings))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.text)
                                .contentTransition(.numericText())
                            Text("× \(Int(result.servingSizeG))g")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textMuted)
                        }
                        Spacer()

                        Button {
                            withAnimation { servings += 0.5 }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(Theme.blue)
                        }
                    }
                    .padding(.horizontal, 8)
                }

                // Meal type
                VStack(alignment: .leading, spacing: 8) {
                    Text("Meal").eyebrow()
                    Picker("Meal", selection: $mealType) {
                        ForEach(mealTypes, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Spacer()

                PrimaryButton(title: "Log it", tint: Theme.green, action: logAndDismiss)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 22)
            .animation(.spring(response: 0.3), value: servings)
        }
    }

    private func macroCell(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 10)).foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func logAndDismiss() {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        appState.logFood(FoodEntry(
            mealType:  mealType,
            name:      result.displayName,
            kcal:      kcal,
            macros:    Macros(carbsG: carbs, proteinG: protein, fatG: fat),
            allergens: [],
            time:      fmt.string(from: Date())
        ))
        dismiss()
    }
}
