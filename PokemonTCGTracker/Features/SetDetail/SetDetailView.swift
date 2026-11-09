//
//  SetDetailView.swift
//  PokemonTCGTracker
//

import SwiftUI
import SwiftData

struct SetDetailView: View {
    @State private var model: SetDetailViewModel
    @State private var filter = CardFilter()
    @State private var editor = OwnershipEditor()
    @Environment(\.modelContext) private var modelContext
    @Environment(ExchangeRates.self) private var exchangeRates
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
            // Attached before .searchable so the bar sits above the bottom search field.
            .safeAreaInset(edge: .bottom) { UndoBar(editor: editor) }
            .navigationTitle(model.set.name)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $filter.searchText, prompt: "Search by name or number")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { filterMenu }
            }
            .task { await model.load() }
            .onChange(of: model.cards) { updateOwnedPrices() }
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
        .accessibilityLabel("\(card.name), number \(card.displayNumber)")
        .accessibilityValue(owned ? "Owned" : "Not owned")
        .accessibilityHint("Double tap to mark as \(owned ? "not owned" : "owned")")
    }

    private func header(visibleCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SetProgressView(owned: ownedCards.count, total: model.cards.count, showsPercentage: true)
            completionLink
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

    /// "116 to go · about £162.40 — See cheapest first".
    @ViewBuilder
    private var completionLink: some View {
        let plan = CompletionPlan(cards: model.cards, ownedIDs: ownedIDs)
        if !plan.isComplete {
            NavigationLink {
                CompletionView(set: model.set, cards: model.cards)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(plan.missingCount) to go · about \(exchangeRates.format(eur: plan.totalEUR))")
                            .font(.subheadline.weight(.semibold))
                        Text("See the cheapest cards to buy first")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(10)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
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

    /// Copies freshly loaded prices onto the owned cards in this set.
    private func updateOwnedPrices() {
        let cardsByID = Dictionary(model.cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for owned in ownedCards {
            if let card = cardsByID[owned.cardID] { owned.updatePrice(from: card) }
        }
    }

    private func toggleOwned(_ card: TCGCard) {
        editor.toggle(card, setID: model.set.id, in: modelContext)
    }
}

struct CardCell: View {
    let card: TCGCard
    let isOwned: Bool
    @Environment(ExchangeRates.self) private var exchangeRates

    var body: some View {
        VStack(spacing: 4) {
            AsyncImage(url: card.smallImageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    placeholder.overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                default:
                    if card.smallImageURL == nil {
                        // A few cards have no image in TCGdex: show the name instead.
                        placeholder.overlay(
                            Text(card.name).font(.caption).multilineTextAlignment(.center).padding(6)
                        )
                    } else {
                        placeholder.overlay(ProgressView())
                    }
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

            HStack(spacing: 4) {
                Text("#\(card.displayNumber)")
                    .foregroundStyle(.secondary)
                if let price = card.priceEUR {
                    Text(exchangeRates.format(eur: price))
                        .fontWeight(.medium)
                }
            }
            .font(.caption2.monospacedDigit())
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 6).fill(.quaternary)
    }
}
