//
//  OwnedPriceRefresher.swift
//  PokemonTCGTracker
//

import Foundation
import SwiftData

/// Refreshes the saved price of owned cards when it's missing or older than
/// `maxAge`, so the collection value is right without opening every set.
/// Cardmarket prices on TCGdex update once a day, so twice a day is plenty.
enum OwnedPriceRefresher {
    static let maxAge: TimeInterval = 12 * 60 * 60

    static func refresh(context: ModelContext, client: TCGdexClient = TCGdexClient(), now: Date = .now) async {
        let owned = (try? context.fetch(FetchDescriptor<OwnedCard>())) ?? []
        let stale = owned.filter { needsRefresh($0.priceUpdated, now: now) }
        guard !stale.isEmpty,
              let details = try? await client.fetchCardDetails(ids: stale.map(\.cardID))
        else { return }

        for card in stale {
            if let detail = details[card.cardID] { card.updatePrice(from: detail, at: now) }
        }
        try? context.save()
    }

    nonisolated static func needsRefresh(_ updated: Date?, now: Date) -> Bool {
        guard let updated else { return true }
        return now.timeIntervalSince(updated) > maxAge
    }
}
