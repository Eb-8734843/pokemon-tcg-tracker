//
//  CompletionPlan.swift
//  PokemonTCGTracker
//

import Foundation

/// What it costs to finish a set: the missing cards, cheapest first.
nonisolated struct CompletionPlan: Sendable {
    /// Missing cards with a price, cheapest first (ties in collector-number order).
    let pricedMissing: [TCGCard]
    /// Missing cards Cardmarket has no price for, in collector-number order.
    let unpricedMissing: [TCGCard]

    init(cards: [TCGCard], ownedIDs: Set<String>) {
        let missing = cards.filter { !ownedIDs.contains($0.id) }
        pricedMissing = missing
            .filter { $0.priceEUR != nil }
            .sorted { a, b in
                if a.priceEUR! != b.priceEUR! { return a.priceEUR! < b.priceEUR! }
                return TCGCard.byCollectorNumber(a, b)
            }
        unpricedMissing = missing
            .filter { $0.priceEUR == nil }
            .sorted(by: TCGCard.byCollectorNumber)
    }

    var missingCount: Int { pricedMissing.count + unpricedMissing.count }
    var isComplete: Bool { missingCount == 0 }

    /// Cost of every missing card that has a price.
    var totalEUR: Double { pricedMissing.reduce(0) { $0 + ($1.priceEUR ?? 0) } }

    /// Cost of the `count` cheapest missing cards.
    func cheapestTotalEUR(_ count: Int) -> Double {
        pricedMissing.prefix(count).reduce(0) { $0 + ($1.priceEUR ?? 0) }
    }
}
