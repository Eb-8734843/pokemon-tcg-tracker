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

    var body: some View {
        SetListView()
            .task {
                // One-time move of cards saved before the switch to TCGdex.
                await OwnedCardMigration.runIfNeeded(context: modelContext)
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: OwnedCard.self, inMemory: true)
}
