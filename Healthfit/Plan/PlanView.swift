//
//  PlanView.swift
//  Container — switches between Input and Generated using a top picker.
//

import SwiftUI

struct PlanView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Picker("Plan", selection: $appState.planMode) {
                    ForEach(PlanMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 18)
                .padding(.top, 8)

                switch appState.planMode {
                case .input:     PlanInputView()
                case .generated: PlanGeneratedView()
                }
            }
        }
    }
}

#Preview {
    NavigationStack { PlanView() }
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
