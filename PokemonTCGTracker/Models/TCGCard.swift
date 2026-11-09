//
//  TCGCard.swift
//  PokemonTCGTracker
//

import Foundation

/// A single card, from TCGdex.
nonisolated struct TCGCard: Codable, Identifiable, Hashable, Sendable {
    /// TCGdex card ID, e.g. "me05-008".
    let id: String
    let name: String
    /// Collector number as printed, e.g. "008", "TG05", "SV001".
    let number: String
    /// "Pokemon", "Trainer" or "Energy".
    let category: String?
    /// Missing for a few promo cards, or when only the short card details loaded.
    let rarity: String?
    /// Energy types such as "Fire". Only Pokémon cards have them.
    let types: [String]?
    /// Base URL of the card image (no size or extension). Missing for some cards.
    let imageBase: URL?
    /// Cardmarket price in euros (see `CardmarketPrice.bestEUR`). Missing when
    /// Cardmarket has no sales, or when only the short card details loaded.
    var priceEUR: Double? = nil

    var smallImageURL: URL? { imageBase?.appending(path: "low.webp") }
    var largeImageURL: URL? { imageBase?.appending(path: "high.webp") }
}

extension TCGCard {
    /// What the type filter matches on: the energy type for Pokémon,
    /// otherwise "Trainer" or "Energy".
    nonisolated var typeCategories: [String] {
        if let types, !types.isEmpty { return types }
        switch category {
        case "Pokemon", nil: return ["Other"]
        case let category?: return [category]
        }
    }

    /// Collector number without padding zeros: "008" → "8", "TG05" stays "TG05".
    nonisolated var displayNumber: String {
        Int(number).map(String.init) ?? number
    }

    /// Orders cards the way they're numbered in the binder: 2 before 10, TG01 after 200.
    nonisolated static func byCollectorNumber(_ a: TCGCard, _ b: TCGCard) -> Bool {
        let aNumber = Int(a.number), bNumber = Int(b.number)
        switch (aNumber, bNumber) {
        case let (x?, y?): return x < y
        case (.some, nil): return true    // plain numbers before prefixed ones
        case (nil, .some): return false
        case (nil, nil): return a.number.localizedStandardCompare(b.number) == .orderedAscending
        }
    }
}
