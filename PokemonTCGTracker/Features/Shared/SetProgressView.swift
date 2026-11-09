//
//  SetProgressView.swift
//  PokemonTCGTracker
//

import SwiftUI

/// A progress bar for how much of a set is owned, e.g. "12 / 120".
struct SetProgressView: View {
    let owned: Int
    let total: Int
    var showsPercentage = false

    private var fraction: Double {
        total > 0 ? min(Double(owned) / Double(total), 1) : 0
    }
    private var isComplete: Bool { total > 0 && owned >= total }

    var body: some View {
        HStack(spacing: 8) {
            ProgressView(value: fraction)
                .tint(isComplete ? .green : .accentColor)
            Group {
                if isComplete {
                    Label("Complete", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else if showsPercentage {
                    Text("\(owned) / \(total) · \(fraction, format: .percent.precision(.fractionLength(0)))")
                } else {
                    Text("\(owned) / \(total)")
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(isComplete ? .green : .secondary)
            .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Collection progress")
        .accessibilityValue(isComplete ? "Complete, \(total) cards" : "\(owned) of \(total) cards owned")
    }
}

#Preview {
    VStack(spacing: 20) {
        SetProgressView(owned: 0, total: 120)
        SetProgressView(owned: 34, total: 120, showsPercentage: true)
        SetProgressView(owned: 120, total: 120)
    }
    .padding()
}
