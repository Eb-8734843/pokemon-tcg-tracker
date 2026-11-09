//
//  OwnershipEditor.swift
//  PokemonTCGTracker
//

import Foundation
import Observation
import SwiftData

/// Marks cards owned or not, and remembers the recent changes so they can be
/// undone. Changes made close together are grouped: while the Undo bar is
/// showing, every new change joins the group, and Undo reverses them all.
/// That covers a run of accidental taps, not just the last one.
@Observable
final class OwnershipEditor {
    struct Change {
        let card: TCGCard
        let setID: String
        /// Set when the change removed an owned card, so Undo can put it back
        /// exactly as it was. `nil` when the change added the card.
        let removed: RemovedCard?

        var wasAdded: Bool { removed == nil }
    }

    struct RemovedCard {
        let dateAdded: Date
        let priceEUR: Double?
        let priceUpdated: Date?
    }

    /// The changes Undo would reverse, oldest first. Empty when there's nothing to undo.
    private(set) var pending: [Change] = []
    /// Changes whenever a change is made, so the Undo bar can restart its timer.
    private(set) var lastChangeID = UUID()

    /// How long the Undo bar stays after the last change.
    static let undoWindow: Duration = .seconds(8)

    /// Ticks the card if it isn't owned, unticks it if it is.
    func toggle(_ card: TCGCard, setID: String, in context: ModelContext) {
        if let existing = owned(card.id, in: context) {
            record(Change(card: card, setID: setID,
                          removed: RemovedCard(dateAdded: existing.dateAdded, priceEUR: existing.priceEUR,
                                               priceUpdated: existing.priceUpdated)))
            context.delete(existing)
        } else {
            context.insert(OwnedCard(card: card, setID: setID))
            record(Change(card: card, setID: setID, removed: nil))
        }
    }

    /// Ticks the card. Does nothing if it's already owned.
    func markOwned(_ card: TCGCard, setID: String, in context: ModelContext) {
        guard owned(card.id, in: context) == nil else { return }
        toggle(card, setID: setID, in: context)
    }

    /// Reverses every pending change, newest first.
    func undo(in context: ModelContext) {
        for change in pending.reversed() {
            if let removed = change.removed {
                guard owned(change.card.id, in: context) == nil else { continue }
                let restored = OwnedCard(card: change.card, setID: change.setID, dateAdded: removed.dateAdded)
                restored.priceEUR = removed.priceEUR
                restored.priceUpdated = removed.priceUpdated
                context.insert(restored)
            } else if let added = owned(change.card.id, in: context) {
                context.delete(added)
            }
        }
        pending = []
    }

    /// Hides the Undo bar; the changes stay.
    func dismiss() {
        pending = []
    }

    /// e.g. "Unmarked Tropius", "Marked Tropius as owned", "3 changes".
    var message: String {
        guard pending.count == 1, let change = pending.first else { return "\(pending.count) changes" }
        return change.wasAdded ? "Marked \(change.card.name) as owned" : "Unmarked \(change.card.name)"
    }

    private func record(_ change: Change) {
        pending.append(change)
        lastChangeID = UUID()
    }

    private func owned(_ cardID: String, in context: ModelContext) -> OwnedCard? {
        var descriptor = FetchDescriptor<OwnedCard>(predicate: #Predicate { $0.cardID == cardID })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
