//
//  OpenFoodFactsService.swift
//  Looks up packaged foods by barcode using the Open Food Facts API.
//  No API key required. https://world.openfoodfacts.org
//

import Foundation

@MainActor
final class OpenFoodFactsService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    func lookup(barcode: String) async -> FoodSearchResult? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let fields = "product_name,brands,nutriments,serving_quantity"
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=\(fields)") else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OFFResponse.self, from: data)
            guard response.status == 1, let product = response.product else {
                errorMessage = "Product not found in database."
                return nil
            }

            let n = product.nutriments
            // Prefer kcal; fall back to kJ ÷ 4.184
            let kcalPer100g = n.energyKcal100g
                ?? n.energyKj100g.map { $0 / 4.184 }
                ?? 0

            let servingSizeG = product.servingQuantity.flatMap { $0 > 0 ? $0 : nil } ?? 100.0

            return FoodSearchResult(
                id: abs(barcode.hashValue),
                name: product.productName ?? "Unknown Product",
                brand: product.brands.map { $0.trimmingCharacters(in: .whitespaces) },
                kcalPer100g: kcalPer100g,
                carbsPer100g: n.carbohydrates100g ?? 0,
                proteinPer100g: n.proteins100g ?? 0,
                fatPer100g: n.fat100g ?? 0,
                servingSizeG: servingSizeG
            )
        } catch {
            errorMessage = "Couldn't reach the food database. Check your connection."
            return nil
        }
    }
}

// MARK: - Response models

private struct OFFResponse: Decodable {
    let status: Int
    let product: OFFProduct?
}

private struct OFFProduct: Decodable {
    let productName: String?
    let brands: String?
    let nutriments: OFFNutriments
    let servingQuantity: Double?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case nutriments
        case servingQuantity = "serving_quantity"
    }
}

private struct OFFNutriments: Decodable {
    let energyKcal100g: Double?
    let energyKj100g: Double?
    let carbohydrates100g: Double?
    let proteins100g: Double?
    let fat100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case energyKj100g   = "energy-kj_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case proteins100g   = "proteins_100g"
        case fat100g        = "fat_100g"
    }
}
