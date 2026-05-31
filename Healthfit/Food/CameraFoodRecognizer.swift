//
//  CameraFoodRecognizer.swift
//  UIImagePickerController wrapper and on-device Vision food classification.
//  Falls back to photo library on the simulator (camera unavailable).
//

import SwiftUI
@preconcurrency import Vision

// MARK: - Camera / library picker

struct CameraPickerView: UIViewControllerRepresentable {
    var onImageSelected: (UIImage) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera)
            ? .camera : .photoLibrary
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject,
                              UIImagePickerControllerDelegate,
                              UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            } else {
                parent.onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}

// MARK: - On-device food classification

/// Runs VNClassifyImageRequest on the image and returns the most specific
/// food-related label found, or nil when no confident food label exists.
func classifyFoodInImage(_ image: UIImage) async -> String? {
    await withCheckedContinuation { continuation in
        guard let cgImage = image.cgImage else {
            continuation.resume(returning: nil)
            return
        }

        // Labels too generic to produce useful USDA search results
        let skipLabels = Set([
            "food", "meal", "dish", "cuisine", "ingredient", "snack food",
            "plant", "produce", "fruit", "vegetable", "meat", "seafood",
            "baked goods", "drink", "beverage", "dairy product", "fast food",
        ])

        let request = VNClassifyImageRequest { request, _ in
            let observations = (request.results as? [VNClassificationObservation]) ?? []

            let label = observations
                .filter { $0.confidence > 0.05 }
                .compactMap { obs -> String? in
                    // Vision identifiers use snake_case and parenthetical qualifiers,
                    // e.g. "fried_chicken" → "fried chicken", "orange_(fruit)" → "orange"
                    let clean = obs.identifier
                        .replacingOccurrences(of: "_", with: " ")
                        .components(separatedBy: "(").first?
                        .trimmingCharacters(in: .whitespaces) ?? obs.identifier
                    return skipLabels.contains(clean.lowercased()) ? nil : clean
                }
                .first

            continuation.resume(returning: label)
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
}
