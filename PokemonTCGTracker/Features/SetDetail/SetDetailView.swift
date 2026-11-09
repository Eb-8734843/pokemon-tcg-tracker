//
//  SetDetailView.swift
//  PokemonTCGTracker
//

import SwiftUI
import SwiftData

struct SetDetailView: View {
    @State private var model: SetDetailViewModel
    @State private var filter = CardFilter()
    @Environment(\.modelContext) private var modelContext
    @Query private var ownedCards: [OwnedCard]

    init(set: TCGSet) {
        _model = State(initialValue: SetDetailViewModel(set: set))
        let setID = set.id
        _ownedCards = Query(filter: #Predicate<OwnedCard> { $0.setID == setID })
    }

    private var ownedIDs: Set<String> { Set(ownedCards.map(\.cardID)) }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        content
            .navigationTitle(model.set.name)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $filter.searchText, prompt: "Search by name or number")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { filterMenu }
            }
            .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView("Loading cards…")
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load cards", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await model.load() } }
                    .buttonStyle(.borderedProminent)
            }
        case .loaded:
            let ownedIDs = ownedIDs
            let visibleCards = filter.apply(to: model.cards, ownedIDs: ownedIDs)
            ScrollView {
                header(visibleCount: visibleCards.count)
                if visibleCards.isEmpty {
                    noMatches
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(visibleCards) { card in
                            cardButton(card, owned: ownedIDs.contains(card.id))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .refreshable { await model.load() }
        }
    }

    private func cardButton(_ card: TCGCard, owned: Bool) -> some View {
        Button {
            toggleOwned(card)
        } label: {
            CardCell(card: card, isOwned: owned)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: owned)
        .accessibilityLabel("\(card.name), number \(card.number)")
        .accessibilityValue(owned ? "Owned" : "Not owned")
        .accessibilityHint("Double tap to mark as \(owned ? "not owned" : "owned")")
    }

    private func header(visibleCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SetProgressView(owned: ownedCards.count, total: model.cards.count, showsPercentage: true)
            HStack {
                if filter.hasActiveFilters || !filter.searchText.isEmpty {
                    Text("Showing \(visibleCount) of \(model.cards.count)")
                    if filter.hasActiveFilters {
                        Button("Clear filters") { clearFilters() }
                            .font(.caption.weight(.semibold))
                    }
                } else {
                    Text("Tap a card to mark it owned")
                }
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var noMatches: some View {
        ContentUnavailableView {
            Label("No matching cards", systemImage: "magnifyingglass")
        } description: {
            Text("Try a different search or filter.")
        } actions: {
            if filter.hasActiveFilters {
                Button("Clear filters") { clearFilters() }
            }
        }
        .padding(.top, 40)
    }

    private var filterMenu: some View {
        Menu {
            Picker("Show", selection: $filter.ownership) {
                ForEach(CardFilter.Ownership.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.inline)

            Picker(selection: $filter.rarity) {
                Text("Any rarity").tag(String?.none)
                ForEach(CardFilter.rarities(in: model.cards), id: \.self) { rarity in
                    Text(rarity).tag(String?.some(rarity))
                }
            } label: {
                Label(filter.rarity ?? "Rarity", systemImage: "sparkles")
            }
            .pickerStyle(.menu)

            Picker(selection: $filter.type) {
                Text("Any type").tag(String?.none)
                ForEach(CardFilter.types(in: model.cards), id: \.self) { type in
                    Text(type).tag(String?.some(type))
                }
            } label: {
                Label(filter.type ?? "Type", systemImage: "flame")
            }
            .pickerStyle(.menu)

            if filter.hasActiveFilters {
                Divider()
                Button("Clear filters", systemImage: "xmark.circle", role: .destructive) { clearFilters() }
            }
        } label: {
            Label("Filter", systemImage: filter.hasActiveFilters
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
        .disabled(model.cards.isEmpty)
    }

    private func clearFilters() {
        filter.rarity = nil
        filter.type = nil
        filter.ownership = .all
    }

    private func toggleOwned(_ card: TCGCard) {
        if let existing = ownedCards.first(where: { $0.cardID == card.id }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(OwnedCard(card: card, setID: model.set.id))
        }
    }
}

struct CardCell: View {
    let card: TCGCard
    let isOwned: Bool

    var body: some View {
        VStack(spacing: 4) {
            AsyncImage(url: card.images.small) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    placeholder.overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                default:
                    placeholder.overlay(ProgressView())
                }
            }
            .aspectRatio(63.0 / 88.0, contentMode: .fit)   // real card proportions
            .saturation(isOwned ? 1 : 0)
            .opacity(isOwned ? 1 : 0.45)
            .overlay(alignment: .topTrailing) {
                if isOwned {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .green)
                        .font(.title3)
                        .padding(4)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isOwned)

            Text("#\(card.number)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 6).fill(.quaternary)
    }
}
