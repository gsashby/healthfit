//
//  WelcomeView.swift
//  First screen — sets the value prop in one sentence.
//

import SwiftUI

struct WelcomeView: View {
    let next: () -> Void
    @State private var animateIn = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            // Soft hero glow
            RadialGradient(
                colors: [Theme.green.opacity(0.20), .clear],
                center: .top, startRadius: 0, endRadius: 380
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                Text("HealthFit")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.green)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Text("Train smart.\nFuel smart.\nRecover smarter.")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(Theme.text)
                    .lineSpacing(2)
                    .padding(.top, 12)
                    .fixedSize(horizontal: false, vertical: true)

                Text("A fitness coach that listens to your Apple Watch and adapts your training, nutrition, and recovery — every day.")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textMuted)
                    .lineSpacing(4)
                    .padding(.top, 16)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                PrimaryButton(title: "Get started", tint: Theme.green, action: next)

                Button("I already have an account") {
                    // Stub — would route to sign-in.
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)

                Spacer().frame(height: 30)
            }
            .padding(.horizontal, 28)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 16)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) { animateIn = true }
            }
        }
    }
}

#Preview {
    WelcomeView(next: {})
}
