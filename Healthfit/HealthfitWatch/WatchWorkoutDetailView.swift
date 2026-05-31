//
//  WatchWorkoutDetailView.swift
//  watchOS — numbered exercise list for today's session.
//

import SwiftUI

struct WatchWorkoutDetailView: View {
    let workoutName: String
    let exercises: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(exercises.enumerated()), id: \.offset) { i, exercise in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(width: 18, alignment: .trailing)
                        Text(exercise)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 8)
                    if i < exercises.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(workoutName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
