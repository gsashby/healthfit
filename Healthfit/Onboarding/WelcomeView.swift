//
//  WelcomeView.swift
//  First screen — sets the value prop in one sentence.
//

import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    let next: () -> Void
    @State private var animateIn = false
    @State private var showSignIn = false

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
                    showSignIn = true
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
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
    }
}

// MARK: - SignInView

struct SignInView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold)).foregroundColor(Theme.textMuted)
                        .padding(10).background(Theme.card2).clipShape(Circle())
                }.padding(.top, 16)

                Text("Welcome back")
                    .font(.system(size: 28, weight: .bold)).foregroundColor(Theme.text).padding(.top, 20)
                Text("Sign in to continue your training.")
                    .font(.system(size: 15)).foregroundColor(Theme.textMuted).padding(.top, 6)

                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn,
                        onRequest: { $0.requestedScopes = [.fullName, .email] },
                        onCompletion: { authService.handleAppleSignIn($0) })
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    HStack {
                        Rectangle().fill(Theme.separator).frame(height: 1)
                        Text("or").font(.system(size: 13)).foregroundColor(Theme.textMuted).padding(.horizontal, 8)
                        Rectangle().fill(Theme.separator).frame(height: 1)
                    }.padding(.vertical, 4)

                    AuthFieldWelcome(placeholder: "Email", text: $email, isSecure: false)
                    AuthFieldWelcome(placeholder: "Password", text: $password, isSecure: true)
                    if let err = errorMessage {
                        Text(err).font(.system(size: 13)).foregroundColor(Theme.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(.top, 28)

                Spacer()
                PrimaryButton(title: isLoading ? "Signing in…" : "Sign in", tint: Theme.green) {
                    errorMessage = nil; isLoading = true
                    do { try authService.signIn(email: email, password: password) }
                    catch let e as AuthError { errorMessage = e.errorDescription }
                    catch { errorMessage = error.localizedDescription }
                    isLoading = false
                }.disabled(isLoading)
                Spacer().frame(height: 30)
            }.padding(.horizontal, 22)
        }
    }
}

// MARK: - Private auth text field (local to this file)

private struct AuthFieldWelcome: View {
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    var body: some View {
        Group {
            if isSecure { SecureField(placeholder, text: $text) }
            else {
                TextField(placeholder, text: $text)
                    #if canImport(UIKit)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
            }
        }
        .font(.system(size: 16)).foregroundColor(Theme.text)
        .padding(14).background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    WelcomeView(next: {})
        .environmentObject(AuthService())
}
