//
//  SetListView.swift
//  PokemonTCGTracker
//

import SwiftUI
import SwiftData

struct SetListView: View {
    @State private var model = SetListViewModel()
    @Query private var ownedCards: [OwnedCard]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Sets")
                .searchable(text: $model.searchText, prompt: "Search sets or series")
                .task { await model.load() }
                .refreshable { await model.load() }
                .navigationDestination(for: TCGSet.self) { set in
                    SetDetailView(set: set)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView("Loading sets…")
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load sets", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await model.load() } }
                    .buttonStyle(.borderedProminent)
            }
        case .loaded:
            let ownedBySet = Dictionary(grouping: ownedCards, by: \.setID).mapValues(\.count)
            List {
                if !ownedCards.isEmpty, model.searchText.isEmpty {
                    Section {
                        CollectionValueRow(ownedCards: ownedCards)
                    }
                }
                ForEach(model.seriesSections, id: \.series) { section in
                    Section(section.series) {
                        ForEach(section.sets) { set in
                            NavigationLink(value: set) {
                                SetRow(set: set, ownedCount: ownedBySet[set.id, default: 0])
                            }
                        }
                    }
                }
            }
            .overlay {
                if model.seriesSections.isEmpty {
                    ContentUnavailableView.search(text: model.searchText)
                }
            }
        }
    }
}

struct SetRow: View {
    let set: TCGSet
    var ownedCount = 0

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let logoURL = set.logoURL {
                    AsyncImage(url: logoURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        case .failure:
                            Image(systemName: "photo").foregroundStyle(.secondary)
                        default:
                            ProgressView()
                        }
                    }
                } else {
                    // Some older sets and promos have no logo.
                    Image(systemName: "rectangle.stack")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(set.name)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    // Only takes up space once the symbol has loaded: some TCGdex
                    // symbol links don't work, and that shouldn't indent the text.
                    AsyncImage(url: set.symbolURL) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFit().frame(width: 14, height: 14)
                        }
                    }
                    Text("\(set.total) cards · \(set.releaseDate.formatted(date: .abbreviated, time: .omitted))")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if ownedCount > 0 {
                    SetProgressView(owned: ownedCount, total: set.total)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// "Your collection: 4 cards · about £0.62".
struct CollectionValueRow: View {
    let ownedCards: [OwnedCard]
    @Environment(ExchangeRates.self) private var exchangeRates

    var body: some View {
        let priced = ownedCards.compactMap(\.priceEUR)
        let unpriced = ownedCards.count - priced.count
        VStack(alignment: .leading, spacing: 4) {
            Text("Your collection")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(exchangeRates.format(eur: priced.reduce(0, +)))
                    .font(.title.bold().monospacedDigit())
                Spacer()
                Text("\(ownedCards.count) \(ownedCards.count == 1 ? "card" : "cards")")
                    .foregroundStyle(.secondary)
            }
            if unpriced > 0 {
                Text("\(unpriced) without a price yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SetListView()
        .modelContainer(for: OwnedCard.self, inMemory: true)
        .environment(ExchangeRates(cache: nil))
}
