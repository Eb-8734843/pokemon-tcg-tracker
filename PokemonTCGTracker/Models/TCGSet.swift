//
//  TCGSet.swift
//  PokemonTCGTracker
//

import Foundation

/// A Pokémon TCG expansion set, as returned by `GET /v2/sets`.
nonisolated struct TCGSet: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let series: String
    /// Number printed on the cards (e.g. "/128"). Missing for some sets.
    let printedTotal: Int?
    /// Total including secret rares.
    let total: Int
    let ptcgoCode: String?
    let releaseDate: Date
    let images: Images

    nonisolated struct Images: Decodable, Hashable, Sendable {
        let symbol: URL
        let logo: URL
    }
}

/// The paged wrapper the API puts around every list response.
nonisolated struct PagedResponse<Item: Decodable & Sendable>: Decodable, Sendable {
    let data: [Item]
    let page: Int
    let pageSize: Int
    let count: Int
    let totalCount: Int
}
