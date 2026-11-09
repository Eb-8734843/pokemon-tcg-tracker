//
//  TCGSet.swift
//  PokemonTCGTracker
//

import Foundation

/// A Pokémon TCG expansion set, from TCGdex.
nonisolated struct TCGSet: Codable, Identifiable, Hashable, Sendable {
    /// TCGdex set ID, e.g. "me05".
    let id: String
    let name: String
    /// Series name, e.g. "Mega Evolution".
    let series: String
    /// Number printed on the cards (e.g. "/84"), not counting secret rares.
    let printedTotal: Int?
    /// Total including secret rares.
    let total: Int
    let releaseDate: Date
    /// Base URL of the set logo (no file extension). Missing for some older sets and promos.
    let logoBase: URL?
    /// Base URL of the set symbol (no file extension). Missing for many sets.
    let symbolBase: URL?

    var logoURL: URL? { logoBase?.appendingPathExtension("webp") }
    var symbolURL: URL? { symbolBase?.appendingPathExtension("webp") }
}

/// A set as saved by the old pokemontcg.io version of the app. Kept only so
/// the one-time move of owned cards can read that saved set list.
nonisolated struct LegacySet: Decodable, Sendable {
    let id: String
    let name: String
    let total: Int
    let releaseDate: Date
}
