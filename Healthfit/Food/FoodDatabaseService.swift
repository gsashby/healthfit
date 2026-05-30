//
//  FoodDatabaseService.swift
//  Queries the USDA FoodData Central API (free, no payment required).
//  Uses DEMO_KEY which allows ~30 req/hour. Register a free key at
//  fdc.nal.usda.gov/api-key-signup.html for production use.
//

import Foundation

// MARK: - Search result

struct FoodSearchResult: Identifiable {
    let id: Int             // USDA fdcId — globally unique
    let name: String
    let brand: String?
    let kcalPer100g: Double
    let carbsPer100g: Double
    let proteinPer100g: Double
    let fatPer100g: Double
    let servingSizeG: Double  // defaults to 100 g when API omits it

    var displayName: String {
        guard let b = brand, !b.isEmpty else { return name }
        return "\(name) — \(b)"
    }

    // Scaled to one serving
    var kcalPerServing:    Int { scaled(kcalPer100g) }
    var carbsPerServing:   Int { scaled(carbsPer100g) }
    var proteinPerServing: Int { scaled(proteinPer100g) }
    var fatPerServing:     Int { scaled(fatPer100g) }

    private func scaled(_ per100: Double) -> Int {
        Int((per100 * servingSizeG / 100).rounded())
    }
}

// MARK: - Service

@MainActor
final class FoodDatabaseService: ObservableObject {
    @Published var results: [FoodSearchResult] = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    private let apiKey = "DEMO_KEY"
    private var searchTask: Task<Void, Never>?

    /// Debounced (0.5 s) search — cancels any in-flight request.
    func search(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            errorMessage = nil
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await performSearch(trimmed)
        }
    }

    private func performSearch(_ query: String) async {
        isSearching = true
        errorMessage = nil

        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
        components.queryItems = [
            URLQueryItem(name: "query",    value: query),
            URLQueryItem(name: "api_key",  value: apiKey),
            URLQueryItem(name: "pageSize", value: "25"),
            URLQueryItem(name: "dataType", value: "Foundation,Branded,SR Legacy"),
        ]

        guard let url = components.url else { isSearching = false; return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response  = try JSONDecoder().decode(USDASearchResponse.self, from: data)
            results = response.foods.compactMap(parseFood)
        } catch {
            if !Task.isCancelled {
                errorMessage = "Search unavailable — check your connection and try again."
                results = []
            }
        }

        isSearching = false
    }

    private func parseFood(_ food: USDAFood) -> FoodSearchResult? {
        func nutrient(_ id: Int) -> Double {
            food.foodNutrients.first { $0.nutrientId == id }?.value ?? 0
        }
        let energy = nutrient(1008)
        guard energy > 0 else { return nil }

        return FoodSearchResult(
            id: food.fdcId,
            name: food.description.localizedCapitalized,
            brand: food.brandOwner,
            kcalPer100g:    energy,
            carbsPer100g:   nutrient(1005),
            proteinPer100g: nutrient(1003),
            fatPer100g:     nutrient(1004),
            servingSizeG:   food.servingSize ?? 100
        )
    }
}

// MARK: - USDA API response models

private struct USDASearchResponse: Codable {
    let foods: [USDAFood]
}

private struct USDAFood: Codable {
    let fdcId: Int
    let description: String
    let brandOwner: String?
    let servingSize: Double?
    let foodNutrients: [USDANutrient]
}

private struct USDANutrient: Codable {
    let nutrientId: Int
    let value: Double
}
