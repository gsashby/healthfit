//
//  MainTabView.swift
//  Tab container for the main app. Today / Plan / Eat / Coach.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var readinessService: ReadinessService
    @EnvironmentObject var fmService: FoundationModelService

    var body: some View {
        TabView {
            NavigationStack { TodayView() }
                .tabItem { Label("Today", systemImage: "sun.max.fill") }

            NavigationStack { PlanView() }
                .tabItem { Label("Plan",  systemImage: "calendar") }

            NavigationStack { FoodView() }
                .tabItem { Label("Eat",   systemImage: "leaf.fill") }

            NavigationStack { CoachView() }
                .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right.fill") }
        }
        .tint(Theme.green)
    }
}

// MARK: - Coach Chat (powered by Apple Foundation Models)

struct CoachView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var readinessService: ReadinessService
    @EnvironmentObject var fmService: FoundationModelService

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var streamTask: Task<Void, Never>?
    @FocusState private var inputFocused: Bool

    private var isStreaming: Bool { streamTask != nil }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if fmService.isAvailable {
                    messageList
                    inputBar
                } else {
                    unavailableState
                }
            }
        }
        .onAppear {
            if messages.isEmpty { addWelcomeMessage() }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Coach").font(.system(size: 22, weight: .bold)).foregroundColor(Theme.text)
                if fmService.isAvailable {
                    Label("Apple Intelligence · On-device", systemImage: "apple.intelligence")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.green)
                }
            }
            Spacer()
            Button {
                messages = []
                fmService.resetCoachSession()
                addWelcomeMessage()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.textMuted)
            }
            // Long-press to reset onboarding (dev affordance)
            .onLongPressGesture(minimumDuration: 1.0) {
                appState.resetOnboarding()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { msg in
                        ChatBubble(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: messages.last?.text) { _, _ in
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask your coach…", text: $inputText, axis: .vertical)
                .font(.system(size: 15))
                .foregroundColor(Theme.text)
                .padding(12)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .lineLimit(1...5)
                .focused($inputFocused)

            Button {
                if isStreaming {
                    streamTask?.cancel()
                } else {
                    sendMessage()
                }
            } label: {
                Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(!isStreaming && inputText.isEmpty ? Theme.textMuted : Theme.green)
            }
            .disabled(!isStreaming && inputText.isEmpty)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Theme.card.opacity(0.6))
    }

    // MARK: Unavailable state

    private var unavailableState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "apple.intelligence")
                .font(.system(size: 44))
                .foregroundColor(Theme.textMuted)
            Text("Apple Intelligence Required")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.text)
            Text("Coach Chat runs entirely on-device using Apple's Foundation Models.\nRequires iPhone 15 Pro or later with iOS 18.1+.")
                .font(.system(size: 14))
                .foregroundColor(Theme.textMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 32)
            Text("Long-press to reset onboarding")
                .font(.system(size: 12))
                .foregroundColor(Theme.textMuted.opacity(0.5))
                .padding(.top, 40)
                .onLongPressGesture(minimumDuration: 0.6) { appState.resetOnboarding() }
            Spacer()
        }
    }

    // MARK: Logic

    private func addWelcomeMessage() {
        let name = appState.user.name.isEmpty ? "there" : appState.user.name
        messages.append(ChatMessage(role: .assistant,
            text: "Hey \(name) 👋 I'm your HealthFit coach, running privately on your device. " +
                  "Ask me anything about your training, recovery, or nutrition."))
    }

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let userText = inputText
        inputText = ""
        inputFocused = false
        messages.append(ChatMessage(role: .user, text: userText))

        let context = CoachContext(
            readinessScore: readinessService.latestData?.score ?? 70,
            readinessState: readinessService.latestData?.state.label ?? "Unknown",
            planWeek: appState.currentPlan.weekIndex,
            planTotalWeeks: appState.currentPlan.totalWeeks
        )

        messages.append(ChatMessage(role: .assistant, text: ""))
        let idx = messages.count - 1

        streamTask = Task {
            defer { streamTask = nil }
            do {
                for try await partial in fmService.streamCoachReply(to: userText, context: context) {
                    messages[idx].text += partial
                }
            } catch is CancellationError {
                // Cancelled by the user via the stop button — leave the partial reply as-is.
            } catch {
                messages[idx].text = "Sorry, something went wrong. Try again."
            }
        }
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var age = ""
    @State private var sex = "Male"
    @State private var weight = ""
    @State private var goalWeight = ""
    @State private var showDeleteConfirm = false
    @State private var selectedAllergies: Set<String> = []
    @State private var selectedPreferences: Set<String> = []
    private let sexOptions = ["Male", "Female", "Other"]

    private static let allergyOptions = [
        "Dairy", "Eggs", "Gluten", "Tree nuts",
        "Peanuts", "Soy", "Shellfish", "Fish",
    ]
    private static let preferenceOptions = [
        "High-protein", "Low-carb", "Vegetarian", "Vegan",
        "Dairy-free", "Gluten-free", "Keto", "Paleo",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        sectionLabel("Profile")
                        VStack(spacing: 12) {
                            ProfileField(label: "Name", placeholder: "Your first name", text: $name)
                            #if canImport(UIKit)
                            ProfileField(label: "Age", placeholder: "e.g. 32", text: $age, keyboard: .numberPad)
                            #else
                            ProfileField(label: "Age", placeholder: "e.g. 32", text: $age)
                            #endif
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Sex at birth").eyebrow()
                                Picker("Sex", selection: $sex) {
                                    ForEach(sexOptions, id: \.self) { Text($0).tag($0) }
                                }.pickerStyle(.segmented)
                            }
                            #if canImport(UIKit)
                            ProfileField(label: "Current weight (lbs)", placeholder: "e.g. 185", text: $weight, keyboard: .decimalPad)
                            ProfileField(label: "Goal weight (lbs)", placeholder: "e.g. 165", text: $goalWeight, keyboard: .decimalPad)
                            #else
                            ProfileField(label: "Current weight (lbs)", placeholder: "e.g. 185", text: $weight)
                            ProfileField(label: "Goal weight (lbs)", placeholder: "e.g. 165", text: $goalWeight)
                            #endif
                        }
                        PrimaryButton(title: "Save changes", tint: Theme.green) {
                            appState.saveUserProfile(UserProfile(
                                name: name.trimmingCharacters(in: .whitespaces),
                                age: Int(age) ?? appState.user.age,
                                sexAtBirth: sex,
                                weightLb: Double(weight) ?? appState.user.weightLb,
                                goalWeightLb: Double(goalWeight) ?? appState.user.goalWeightLb,
                                description: appState.user.description))
                            appState.dietaryProfile = DietaryProfile(
                                allergies: Array(selectedAllergies).sorted(),
                                preferences: Array(selectedPreferences).sorted(),
                                dislikes: appState.dietaryProfile.dislikes)
                            appState.saveDietaryProfile()
                            dismiss()
                        }

                        sectionLabel("Dietary profile").padding(.top, 8)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Allergies").eyebrow()
                            FlowLayout(spacing: 8) {
                                ForEach(Self.allergyOptions, id: \.self) { option in
                                    Pill(text: option,
                                         selected: selectedAllergies.contains(option),
                                         tint: Theme.red) {
                                        if selectedAllergies.contains(option) {
                                            selectedAllergies.remove(option)
                                        } else {
                                            selectedAllergies.insert(option)
                                        }
                                    }
                                }
                            }
                            Text("Preferences").eyebrow().padding(.top, 4)
                            FlowLayout(spacing: 8) {
                                ForEach(Self.preferenceOptions, id: \.self) { option in
                                    Pill(text: option,
                                         selected: selectedPreferences.contains(option),
                                         tint: Theme.green) {
                                        if selectedPreferences.contains(option) {
                                            selectedPreferences.remove(option)
                                        } else {
                                            selectedPreferences.insert(option)
                                        }
                                    }
                                }
                            }
                        }

                        sectionLabel("Account").padding(.top, 8)
                        Button {
                            authService.signOut(); appState.resetOnboarding()
                        } label: {
                            Text("Sign out").font(.system(size: 16, weight: .semibold)).foregroundColor(Theme.text)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Theme.card2).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }.buttonStyle(.plain)
                        Button { showDeleteConfirm = true } label: {
                            Text("Delete account").font(.system(size: 16, weight: .semibold)).foregroundColor(Theme.red)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Theme.red.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(Theme.green)
                }
            }
            .alert("Delete account?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) { authService.signOut(); appState.resetOnboarding() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This will erase all your data and cannot be undone.") }
        }
        .onAppear {
            name = appState.user.name; sex = appState.user.sexAtBirth
            age = appState.user.age == 0 ? "" : "\(appState.user.age)"
            weight = appState.user.weightLb == 0 ? "" : "\(Int(appState.user.weightLb))"
            goalWeight = appState.user.goalWeightLb == 0 ? "" : "\(Int(appState.user.goalWeightLb))"
            selectedAllergies = Set(appState.dietaryProfile.allergies)
            selectedPreferences = Set(appState.dietaryProfile.preferences)
        }
    }

    private func sectionLabel(_ t: String) -> some View {
        Text(t).font(.system(size: 18, weight: .bold)).foregroundColor(Theme.text)
    }
}
