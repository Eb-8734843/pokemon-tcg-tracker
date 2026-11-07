//
//  SetDetailView.swift
//  PokemonTCGTracker
//

import SwiftUI
import SwiftData

struct SetDetailView: View {
    @State private var model: SetDetailViewModel
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
            ScrollView {
                header
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(model.cards) { card in
                        let owned = ownedIDs.contains(card.id)
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
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .refreshable { await model.load() }
        }
    }

    private var header: some View {
        HStack {
            Text("\(ownedCards.count) of \(model.cards.count) owned")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("Tap a card to mark it owned")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 8)
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
