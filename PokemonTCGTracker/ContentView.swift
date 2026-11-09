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

    var body: some View {
        SetListView()
            .task { await exchangeRates.refresh() }
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
