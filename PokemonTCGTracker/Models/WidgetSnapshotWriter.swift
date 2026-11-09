//
//  WidgetSnapshotWriter.swift
//  PokemonTCGTracker
//

import Foundation
import WidgetKit

/// Builds the widget's summary from the owned cards and saved set data,
/// writes it to the App Group folder, and asks the widget to refresh.
enum WidgetSnapshotWriter {
    struct OwnedCardInfo: Sendable {
        let cardID: String
        let setID: String
        let priceEUR: Double?
    }

    static func update(owned: [OwnedCard], exchangeRates: ExchangeRates, client: TCGdexClient = TCGdexClient()) {
        let snapshot = makeSnapshot(
            owned: owned.map { OwnedCardInfo(cardID: $0.cardID, setID: $0.setID, priceEUR: $0.priceEUR) },
            sets: client.cachedSets() ?? [],
            cardsForSet: { client.cachedCards(setID: $0) },
            eurToGBP: exchangeRates.rate.eurToGBP)

        guard !snapshot.hasSameContent(as: WidgetSnapshot.load()), snapshot.save() else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshot.widgetKind)
    }

    /// Pure, so the tests can check it without files or the widget.
    nonisolated static func makeSnapshot(owned: [OwnedCardInfo], sets: [TCGSet],
                                         cardsForSet: (String) -> [TCGCard]?,
                                         eurToGBP: Double, now: Date = .now) -> WidgetSnapshot {
        let valueEUR = owned.compactMap(\.priceEUR).reduce(0, +)
        let setsByID = Dictionary(sets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let progress = Dictionary(grouping: owned, by: \.setID).compactMap { setID, cards -> WidgetSnapshot.SetProgress? in
            guard let set = setsByID[setID] else { return nil }
            let remaining = cardsForSet(setID).map { setCards in
                CompletionPlan(cards: setCards, ownedIDs: Set(cards.map(\.cardID))).totalEUR * eurToGBP
            }
            return .init(id: setID, name: set.name, owned: cards.count, total: set.total, remainingGBP: remaining)
        }
        .sorted { a, b in
            a.fraction != b.fraction ? a.fraction > b.fraction : a.name < b.name
        }

        return WidgetSnapshot(updated: now, cardCount: owned.count, valueGBP: valueEUR * eurToGBP, sets: progress)
    }
}
