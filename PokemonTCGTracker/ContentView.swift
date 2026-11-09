//
//  ContentView.swift
//  PokemonTCGTracker
//
//  Created by Ebube-Chukwu Ekwe on 07/11/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ExchangeRates.self) private var exchangeRates
    @Query private var ownedCards: [OwnedCard]

    /// Changes whenever something the widget shows changes.
    private var widgetInputs: [String] {
        ownedCards.map { "\($0.cardID)|\($0.priceEUR ?? -1)" }.sorted()
            + ["\(exchangeRates.rate.eurToGBP)"]
    }

    var body: some View {
        SetListView()
            .task { await exchangeRates.refresh() }
            .task(id: widgetInputs) {
                // Wait a moment so a run of taps writes the widget file once.
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                WidgetSnapshotWriter.update(owned: ownedCards, exchangeRates: exchangeRates)
            }
            .task {
                // One-time move of cards saved before the switch to TCGdex,
                // then make sure owned cards have up-to-date prices.
                await OwnedCardMigration.runIfNeeded(context: modelContext)
                await OwnedPriceRefresher.refresh(context: modelContext)
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: OwnedCard.self, inMemory: true)
        .environment(ExchangeRates(cache: nil))
}
