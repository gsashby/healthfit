//
//  Components.swift
//  Small reusable building blocks used across views.
//

import SwiftUI

// MARK: - Buttons

struct PrimaryButton: View {
    let title: String
    var tint: Color = Theme.green
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.card2)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chip / Pill

struct Chip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Theme.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.card2)
            .clipShape(Capsule())
    }
}

struct Pill: View {
    let text: String
    let selected: Bool
    var tint: Color = Theme.blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(selected ? tint : Theme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? tint.opacity(0.18) : Theme.card2)
                .overlay(
                    Capsule().stroke(selected ? tint : Color.white.opacity(0.06), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag (workoutTag, etc.)

struct StatusTag: View {
    let text: String
    let tint: Color
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(tint)
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Reasoning callout

struct ReasoningCallout: View {
    let title: String
    let message: String
    var tint: Color = Theme.blue
    var iconText: String = "i"

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(iconText)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 22, height: 22)
                .background(tint.opacity(0.18))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                (Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.text)
                 + Text(" \(message)").font(.system(size: 13)).foregroundColor(Theme.textMuted))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Macro chip block

struct MacroBlock: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Theme.text)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
