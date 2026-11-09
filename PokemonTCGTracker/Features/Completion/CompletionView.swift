//
//  CompletionView.swift
//  PokemonTCGTracker
//

import SwiftUI
import SwiftData

/// "Cheapest path to completion": the cards still needed for a set,
/// cheapest first, with what they add up to.
struct CompletionView: View {
    let set: TCGSet
    let cards: [TCGCard]

    @Environment(\.modelContext) private var modelContext
    @Environment(ExchangeRates.self) private var exchangeRates
    @Query private var ownedCards: [OwnedCard]

    init(set: TCGSet, cards: [TCGCard]) {
        self.set = set
        self.cards = cards
        let setID = set.id
        _ownedCards = Query(filter: #Predicate<OwnedCard> { $0.setID == setID })
    }

    var body: some View {
        let plan = CompletionPlan(cards: cards, ownedIDs: Set(ownedCards.map(\.cardID)))
        List {
            if plan.isComplete {
                ContentUnavailableView("Set complete!", systemImage: "checkmark.seal.fill",
                                       description: Text("You own every card in \(set.name)."))
            } else {
                summary(plan)

                Section {
                    ForEach(Array(plan.pricedMissing.enumerated()), id: \.element.id) { index, card in
                        row(card, runningTotalEUR: plan.cheapestTotalEUR(index + 1))
                    }
                } header: {
                    Text("Cheapest first")
                } footer: {
                    Text("The right-hand figure is the running total: what it costs to buy every card up to that one.")
                }

                if !plan.unpricedMissing.isEmpty {
                    Section("No price on Cardmarket") {
                        ForEach(plan.unpricedMissing) { card in
                            row(card, runningTotalEUR: nil)
                        }
                    }
                }

                Section {
                    Text("Prices are Cardmarket trend prices from TCGdex, updated daily, converted at €1 = \(exchangeRates.rate.eurToGBP, format: .currency(code: "GBP").precision(.fractionLength(3))) (ECB rate, \(exchangeRates.rate.date)). Shop prices and postage will differ.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Complete \(set.name)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summary(_ plan: CompletionPlan) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(plan.missingCount) more \(plan.missingCount == 1 ? "card" : "cards") to finish the set")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("about \(exchangeRates.format(eur: plan.totalEUR))")
                    .font(.largeTitle.bold().monospacedDigit())
                if !plan.unpricedMissing.isEmpty {
                    Text("plus \(plan.unpricedMissing.count) without a price")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                cheapestSteps(plan)
                    .padding(.top, 6)
            }
            .padding(.vertical, 4)
        }
    }

    /// e.g. "Cheapest 10: £0.21 · Cheapest 50: £3.40", for sizes smaller than what's missing.
    @ViewBuilder
    private func cheapestSteps(_ plan: CompletionPlan) -> some View {
        let steps = [10, 25, 50, 100].filter { $0 < plan.pricedMissing.count }
        if !steps.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(steps, id: \.self) { count in
                    HStack {
                        Text("Cheapest \(count)")
                        Spacer()
                        Text(exchangeRates.format(eur: plan.cheapestTotalEUR(count)))
                            .monospacedDigit()
                    }
                }
            }
            .font(.subheadline)
        }
    }

    private func row(_ card: TCGCard, runningTotalEUR: Double?) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: card.smallImageURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                RoundedRectangle(cornerRadius: 3).fill(.quaternary)
            }
            .frame(width: 36, height: 50)

            VStack(alignment: .leading, spacing: 2) {
                Text(card.name).lineLimit(1)
                Text("#\(card.displayNumber)\(card.rarity.map { " · \($0)" } ?? "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(card.priceEUR.map { exchangeRates.format(eur: $0) } ?? "—")
                    .fontWeight(.semibold)
                if let runningTotalEUR {
                    Text(exchangeRates.format(eur: runningTotalEUR))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .monospacedDigit()
        }
        .swipeActions {
            Button("Got it", systemImage: "checkmark") { markOwned(card) }
                .tint(.green)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Mark as owned") { markOwned(card) }
    }

    private func markOwned(_ card: TCGCard) {
        guard !ownedCards.contains(where: { $0.cardID == card.id }) else { return }
        withAnimation {
            modelContext.insert(OwnedCard(card: card, setID: set.id))
        }
    }
}
