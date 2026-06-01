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
        TabView(selection: $appState.selectedTab) {
            NavigationStack { TodayView() }
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(0)

            NavigationStack { PlanView() }
                .tabItem { Label("Plan",  systemImage: "calendar") }
                .tag(1)

            NavigationStack { FoodView() }
                .tabItem { Label("Eat",   systemImage: "leaf.fill") }
                .tag(2)

            NavigationStack { CoachView() }
                .tabItem { Label("Coach", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(3)
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
    @State private var notifyMorning = true
    @State private var notifyWorkout = true
    @State private var notifyNutrition = true
    @State private var workoutTime = Date()
    @State private var useMetric = false
    @State private var exportItems: [Any] = []
    @State private var showingExport = false
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
                            ProfileField(label: "Current weight (\(appState.useMetric ? "kg" : "lbs"))", placeholder: appState.useMetric ? "e.g. 84" : "e.g. 185", text: $weight, keyboard: .decimalPad)
                            ProfileField(label: "Goal weight (\(appState.useMetric ? "kg" : "lbs"))", placeholder: appState.useMetric ? "e.g. 75" : "e.g. 165", text: $goalWeight, keyboard: .decimalPad)
                            #else
                            ProfileField(label: "Current weight (\(appState.useMetric ? "kg" : "lbs"))", placeholder: appState.useMetric ? "e.g. 84" : "e.g. 185", text: $weight)
                            ProfileField(label: "Goal weight (\(appState.useMetric ? "kg" : "lbs"))", placeholder: appState.useMetric ? "e.g. 75" : "e.g. 165", text: $goalWeight)
                            #endif
                        }
                        PrimaryButton(title: "Save changes", tint: Theme.green) {
                            appState.saveUserProfile(UserProfile(
                                name: name.trimmingCharacters(in: .whitespaces),
                                age: Int(age) ?? appState.user.age,
                                sexAtBirth: sex,
                                weightLb: (Double(weight) ?? 0) > 0 ? appState.storedWeightLbs(Double(weight)!) : appState.user.weightLb,
                                goalWeightLb: (Double(goalWeight) ?? 0) > 0 ? appState.storedWeightLbs(Double(goalWeight)!) : appState.user.goalWeightLb,
                                description: appState.user.description))
                            appState.dietaryProfile = DietaryProfile(
                                allergies: Array(selectedAllergies).sorted(),
                                preferences: Array(selectedPreferences).sorted(),
                                dislikes: appState.dietaryProfile.dislikes)
                            appState.saveDietaryProfile()
                            let wc = Calendar.current.dateComponents([.hour, .minute], from: workoutTime)
                            appState.notifyMorning   = notifyMorning
                            appState.notifyWorkout   = notifyWorkout
                            appState.notifyNutrition = notifyNutrition
                            appState.preferredWorkoutHour   = wc.hour   ?? 7
                            appState.preferredWorkoutMinute = wc.minute ?? 0
                            appState.saveNotificationPreferences()
                            appState.useMetric = useMetric
                            appState.saveUnitPreference()
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

                        sectionLabel("Preferences").padding(.top, 8)
                        VStack(spacing: 0) {
                            Toggle(isOn: $useMetric) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Use metric units")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Theme.text)
                                    Text("Weights in kg, distances in km")
                                        .font(.system(size: 12)).foregroundColor(Theme.textMuted)
                                }
                            }
                            .tint(Theme.green)
                            .padding(.horizontal, 16).padding(.vertical, 12)
                        }
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        sectionLabel("Notifications").padding(.top, 8)
                        VStack(spacing: 0) {
                            notifRow(title: "Morning briefing",
                                     subtitle: "Readiness score at 7:00 AM",
                                     binding: $notifyMorning)
                            Divider().padding(.leading, 16)
                            notifRow(title: "Workout reminder",
                                     subtitle: "30 min before your workout",
                                     binding: $notifyWorkout)
                            if notifyWorkout {
                                Divider().padding(.leading, 16)
                                HStack {
                                    Text("Workout time")
                                        .font(.system(size: 15)).foregroundColor(Theme.text)
                                    Spacer()
                                    DatePicker("", selection: $workoutTime,
                                               displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                            }
                            Divider().padding(.leading, 16)
                            notifRow(title: "Nutrition check",
                                     subtitle: "Midday reminder when behind on macros",
                                     binding: $notifyNutrition)
                        }
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        sectionLabel("Account").padding(.top, 8)
                        // 7.2 HealthKit permissions deep-link
                        Button {
                            #if canImport(UIKit)
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                            #endif
                        } label: {
                            Label("Manage Health permissions", systemImage: "heart.text.square")
                                .font(.system(size: 16, weight: .semibold)).foregroundColor(Theme.text)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Theme.card2).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }.buttonStyle(.plain)
                        // 7.3 Export data
                        Button {
                            if let data = appState.exportData() {
                                let fmt = DateFormatter()
                                fmt.dateFormat = "yyyy-MM-dd"
                                let name = "healthfit-export-\(fmt.string(from: Date())).json"
                                let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                                try? data.write(to: url)
                                exportItems = [url]
                                showingExport = true
                            }
                        } label: {
                            Label("Export my data", systemImage: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold)).foregroundColor(Theme.text)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Theme.card2).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }.buttonStyle(.plain)
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
            .sheet(isPresented: $showingExport) {
                #if canImport(UIKit)
                ActivityView(items: exportItems)
                #endif
            }
            .alert("Delete account?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) { authService.signOut(); appState.resetOnboarding() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This will erase all your data and cannot be undone.") }
        }
        .onAppear {
            name = appState.user.name; sex = appState.user.sexAtBirth
            age = appState.user.age == 0 ? "" : "\(appState.user.age)"
            let wDisplay = appState.displayWeight(appState.user.weightLb)
            let gDisplay = appState.displayWeight(appState.user.goalWeightLb)
            weight     = appState.user.weightLb == 0    ? "" : String(format: "%.1f", wDisplay)
            goalWeight = appState.user.goalWeightLb == 0 ? "" : String(format: "%.1f", gDisplay)
            selectedAllergies = Set(appState.dietaryProfile.allergies)
            selectedPreferences = Set(appState.dietaryProfile.preferences)
            notifyMorning   = appState.notifyMorning
            notifyWorkout   = appState.notifyWorkout
            notifyNutrition = appState.notifyNutrition
            var wc = DateComponents()
            wc.hour = appState.preferredWorkoutHour
            wc.minute = appState.preferredWorkoutMinute
            workoutTime = Calendar.current.date(from: wc) ?? Date()
            useMetric = appState.useMetric
        }
    }

    private func sectionLabel(_ t: String) -> some View {
        Text(t).font(.system(size: 18, weight: .bold)).foregroundColor(Theme.text)
    }

    private func notifRow(title: String, subtitle: String, binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text)
                Text(subtitle).font(.system(size: 12)).foregroundColor(Theme.textMuted)
            }
        }
        .tint(Theme.green)
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

// MARK: - UIActivityViewController wrapper (7.3 Export my data)

#if canImport(UIKit)
private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
#endif
