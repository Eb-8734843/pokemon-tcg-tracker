//
//  TCGCard.swift
//  PokemonTCGTracker
//

import Foundation

/// A single card, as returned by `GET /v2/cards`.
nonisolated struct TCGCard: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// Collector number. Usually "12" but can be "TG05", "SV001", "12a".
    let number: String
    let supertype: String?
    /// Missing for a few promo cards.
    let rarity: String?
    /// Energy types such as "Fire". Only Pokémon cards have them.
    let types: [String]?
    let images: Images

    nonisolated struct Images: Codable, Hashable, Sendable {
        let small: URL
        let large: URL
    }
}

extension TCGCard {
    /// What the type filter matches on: the energy type for Pokémon,
    /// otherwise "Trainer" or "Energy".
    nonisolated var typeCategories: [String] {
        if let types, !types.isEmpty { return types }
        return [supertype ?? "Other"]
    }

    /// Orders cards the way they're numbered in the binder: 2 before 10, TG01 after 200.
    nonisolated static func byCollectorNumber(_ a: TCGCard, _ b: TCGCard) -> Bool {
        let aNumeric = Int(a.number) != nil, bNumeric = Int(b.number) != nil
        if aNumeric != bNumeric { return aNumeric }   // plain numbers before prefixed ones
        return a.number.localizedStandardCompare(b.number) == .orderedAscending
    }
}
