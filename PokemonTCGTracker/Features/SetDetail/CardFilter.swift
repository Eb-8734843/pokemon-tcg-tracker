//
//  CardFilter.swift
//  PokemonTCGTracker
//

import Foundation

/// The search text and filters chosen on a set's card grid.
nonisolated struct CardFilter: Equatable, Sendable {
    enum Ownership: String, CaseIterable, Identifiable, Sendable {
        case all = "All cards"
        case owned = "Owned"
        case missing = "Missing"
        var id: Self { self }
    }

    var searchText = ""
    var rarity: String?
    var type: String?
    var ownership = Ownership.all

    /// True when anything other than the search box is narrowing the grid.
    var hasActiveFilters: Bool {
        rarity != nil || type != nil || ownership != .all
    }

    func apply(to cards: [TCGCard], ownedIDs: Set<String>) -> [TCGCard] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return cards.filter { card in
            if !query.isEmpty,
               !card.name.localizedCaseInsensitiveContains(query),
               card.number.caseInsensitiveCompare(query) != .orderedSame {
                return false
            }
            if let rarity, card.rarity != rarity { return false }
            if let type, !card.typeCategories.contains(type) { return false }
            switch ownership {
            case .all: break
            case .owned: if !ownedIDs.contains(card.id) { return false }
            case .missing: if ownedIDs.contains(card.id) { return false }
            }
            return true
        }
    }

    /// Rarities in the set, in the order they first appear. Cards are in
    /// collector-number order, so this runs roughly common → rarest.
    static func rarities(in cards: [TCGCard]) -> [String] {
        uniqueInOrder(cards.compactMap(\.rarity))
    }

    /// Energy types first (in the order they appear), then Trainer and Energy.
    static func types(in cards: [TCGCard]) -> [String] {
        let all = uniqueInOrder(cards.flatMap(\.typeCategories))
        let others = ["Pokémon", "Trainer", "Energy", "Other"]
        return all.filter { !others.contains($0) } + others.filter(all.contains)
    }

    private static func uniqueInOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
