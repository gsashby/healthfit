//
//  Theme.swift
//  Color palette + common modifiers. Kept small on purpose so the prototype
//  feels iOS-native without needing a full design system.
//

import SwiftUI

enum Theme {
    // Surfaces
    static let bg          = Color(red: 0.00, green: 0.00, blue: 0.00)
    static let card        = Color(red: 0.110, green: 0.110, blue: 0.118) // #1c1c1e
    static let card2       = Color(red: 0.173, green: 0.173, blue: 0.180) // #2c2c2e
    static let separator   = Color.white.opacity(0.08)

    // Text
    static let text        = Color(red: 0.949, green: 0.949, blue: 0.969) // #f2f2f7
    static let textMuted   = Color(red: 0.557, green: 0.557, blue: 0.576) // #8e8e93

    // Accent
    static let green       = Color(red: 0.188, green: 0.820, blue: 0.345) // #30d158
    static let yellow      = Color(red: 1.000, green: 0.839, blue: 0.039) // #ffd60a
    static let red         = Color(red: 1.000, green: 0.271, blue: 0.227) // #ff453a
    static let blue        = Color(red: 0.039, green: 0.518, blue: 1.000) // #0a84ff
    static let orange      = Color(red: 1.000, green: 0.624, blue: 0.039) // #ff9f0a
    static let purple      = Color(red: 0.749, green: 0.353, blue: 0.949) // #bf5af2

    static func accent(for state: ReadinessState) -> Color {
        switch state {
        case .green:  return green
        case .yellow: return yellow
        case .red:    return red
        }
    }

    static func accentSoft(for state: ReadinessState) -> Color {
        accent(for: state).opacity(0.18)
    }
}

// MARK: - View modifiers

struct CardStyle: ViewModifier {
    var padding: CGFloat = 18
    var cornerRadius: CGFloat = 22
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func card(padding: CGFloat = 18, cornerRadius: CGFloat = 22) -> some View {
        modifier(CardStyle(padding: padding, cornerRadius: cornerRadius))
    }

    /// Eyebrow caption — small uppercase muted text used above section titles.
    func eyebrow() -> some View {
        self
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.textMuted)
            .textCase(.uppercase)
            .tracking(0.6)
    }
}
