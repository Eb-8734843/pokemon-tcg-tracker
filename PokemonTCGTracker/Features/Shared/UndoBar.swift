//
//  UndoBar.swift
//  PokemonTCGTracker
//

import SwiftUI
import SwiftData

/// A small bar at the bottom of the screen: "Unmarked Tropius   Undo".
/// It disappears a few seconds after the last change.
struct UndoBar: View {
    let editor: OwnershipEditor
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if !editor.pending.isEmpty {
                HStack(spacing: 16) {
                    Text(editor.message)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button("Undo") {
                        withAnimation { editor.undo(in: modelContext) }
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: editor.lastChangeID) {
                    // Restarts on every change; only the latest one gets to hide the bar.
                    try? await Task.sleep(for: OwnershipEditor.undoWindow)
                    guard !Task.isCancelled else { return }
                    withAnimation { editor.dismiss() }
                }
            }
        }
        .animation(.snappy, value: editor.pending.isEmpty)
    }
}
