//
//  BarcodeScannerView.swift
//  Scans a product barcode with DataScannerViewController, looks it up in
//  Open Food Facts, then hands the result to SearchResultSheet for serving
//  selection and logging.
//

import SwiftUI
import VisionKit

struct BarcodeScannerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @StateObject private var offService = OpenFoodFactsService()
    @State private var scannedResult: FoodSearchResult?
    @State private var isLooking = false
    @State private var errorMessage: String?
    @State private var scannerActive = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if DataScannerViewController.isSupported {
                DataScannerRepresentable(
                    isActive: scannerActive,
                    onBarcode: { barcode in
                        guard scannerActive else { return }
                        scannerActive = false
                        Task { await lookup(barcode) }
                    }
                )
                .ignoresSafeArea()
            }

            overlayUI
        }
        .sheet(item: $scannedResult) { result in
            SearchResultSheet(result: result)
                .presentationDetents([.medium, .large])
                .onDisappear { dismiss() }
        }
    }

    // MARK: - Overlay

    private var overlayUI: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(.black.opacity(0.55))
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(20)

            Spacer()

            // Finder frame
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.8), lineWidth: 2)
                    .frame(width: 280, height: 110)

                // Corner accents
                CornerAccents()
                    .frame(width: 280, height: 110)
            }

            Text("Align barcode within the frame")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
                .padding(.top, 14)

            Spacer()

            // Status bar
            statusBar
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
    }

    @ViewBuilder
    private var statusBar: some View {
        if isLooking {
            HStack(spacing: 10) {
                ProgressView().tint(.white)
                Text("Looking up product…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.black.opacity(0.6))
            .clipShape(Capsule())
        } else if let err = errorMessage {
            VStack(spacing: 10) {
                Text(err)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                HStack(spacing: 16) {
                    Button("Try again") {
                        errorMessage = nil
                        scannerActive = true
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.green)

                    Button("Search instead") { dismiss() }
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.black.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Lookup

    private func lookup(_ barcode: String) async {
        isLooking = true
        let result = await offService.lookup(barcode: barcode)
        isLooking = false
        if let result {
            scannedResult = result
        } else {
            errorMessage = offService.errorMessage
                ?? "Product not found. Try searching manually."
        }
    }
}

// MARK: - Corner accent decoration

private struct CornerAccents: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let len: CGFloat = 22
            let thick: CGFloat = 3


            ZStack {
                ForEach([
                    (CGPoint(x: 0, y: 0),   CGSize(width: len, height: thick), CGSize(width: thick, height: len)),   // TL
                    (CGPoint(x: w - len, y: 0),  CGSize(width: len, height: thick), CGSize(width: thick, height: len)),  // TR (adjusted)
                    (CGPoint(x: 0, y: h - thick), CGSize(width: len, height: thick), CGSize(width: thick, height: len)), // BL
                    (CGPoint(x: w - len, y: h - thick), CGSize(width: len, height: thick), CGSize(width: thick, height: len)), // BR
                ].indices, id: \.self) { _ in EmptyView() }

                // Top-left
                accent(x: 0,     y: 0,          hLen: len, vLen: len, thick: thick)
                // Top-right
                accent(x: w - len, y: 0,         hLen: len, vLen: len, thick: thick)
                // Bottom-left
                accent(x: 0,     y: h - thick,   hLen: len, vLen: len, thick: thick)
                // Bottom-right
                accent(x: w - len, y: h - thick, hLen: len, vLen: len, thick: thick)
            }
        }
    }

    private func accent(x: CGFloat, y: CGFloat, hLen: CGFloat, vLen: CGFloat, thick: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Theme.green).frame(width: hLen, height: thick)
            Rectangle().fill(Theme.green).frame(width: thick, height: vLen)
        }
        .offset(x: x, y: y)
    }
}

// MARK: - DataScanner wrapper

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    var isActive: Bool
    var onBarcode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [
                .upce, .ean8, .ean13,
                .code39, .code93, .code128,
                .qr, .dataMatrix
            ])],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        if isActive {
            try? vc.startScanning()
        } else {
            vc.stopScanning()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onBarcode: onBarcode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onBarcode: (String) -> Void
        init(onBarcode: @escaping (String) -> Void) { self.onBarcode = onBarcode }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            for item in addedItems {
                if case .barcode(let barcode) = item,
                   let value = barcode.payloadStringValue {
                    DispatchQueue.main.async { self.onBarcode(value) }
                    return
                }
            }
        }
    }
}
