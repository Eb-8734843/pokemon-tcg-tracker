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
    @State private var editor = OwnershipEditor()
    /// Saved between launches; 0 means no budget set.
    @AppStorage("budgetGBP") private var budgetGBP = 0.0
    @FocusState private var editingBudget: Bool

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

                if !plan.pricedMissing.isEmpty {
                    budgetSection(plan)
                }

                Section {
                    let affordable = affordableCount(plan)
                    ForEach(Array(plan.pricedMissing.enumerated()), id: \.element.id) { index, card in
                        if index == affordable, let affordable, affordable > 0 {
                            budgetLine(plan, affordable: affordable)
                        }
                        row(card, runningTotalEUR: plan.cheapestTotalEUR(index + 1),
                            inBudget: affordable.map { index < $0 } ?? false)
                    }
                } header: {
                    Text("Cheapest first")
                } footer: {
                    Text("The right-hand figure is the running total: what it costs to buy every card up to that one.")
                }

                if !plan.unpricedMissing.isEmpty {
                    Section("No price on Cardmarket") {
                        ForEach(plan.unpricedMissing) { card in
                            row(card, runningTotalEUR: nil, inBudget: false)
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
        .safeAreaInset(edge: .bottom) { UndoBar(editor: editor) }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { editingBudget = false }
            }
        }
    }

    // MARK: - Budget

    /// How many of the cheapest cards the budget buys, or nil with no budget set.
    private func affordableCount(_ plan: CompletionPlan) -> Int? {
        guard budgetGBP > 0 else { return nil }
        return plan.affordableCount(budgetEUR: exchangeRates.euros(fromGBP: budgetGBP))
    }

    private func budgetSection(_ plan: CompletionPlan) -> some View {
        Section {
            HStack {
                Label("Budget", systemImage: "sterlingsign.circle")
                Spacer()
                // Empty rather than "£0.00" when there's no budget, so there's nothing to delete first.
                TextField("Amount", value: Binding(
                    get: { budgetGBP > 0 ? budgetGBP : nil },
                    set: { budgetGBP = max(0, $0 ?? 0) }
                ), format: .currency(code: "GBP"))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .focused($editingBudget)
                    .frame(maxWidth: 140)
                if budgetGBP > 0 {
                    Button("Clear budget", systemImage: "xmark.circle.fill") { budgetGBP = 0 }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                        .buttonStyle(.borderless)
                }
            }

            HStack(spacing: 8) {
                ForEach([5.0, 10, 20, 50], id: \.self) { amount in
                    Button(amount.formatted(.currency(code: "GBP").precision(.fractionLength(0)))) {
                        editingBudget = false
                        budgetGBP = amount
                    }
                    .buttonStyle(.bordered)
                    .tint(budgetGBP == amount ? .accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                }
            }

            if let affordable = affordableCount(plan) {
                budgetResult(plan, affordable: affordable)
            }
        } header: {
            Text("Budget mode")
        } footer: {
            if budgetGBP == 0 {
                Text("Enter what you want to spend to see how far it gets you, cheapest cards first.")
            }
        }
    }

    /// "£5.00 buys 37 of 56 missing cards · £0.42 left over".
    private func budgetResult(_ plan: CompletionPlan, affordable: Int) -> some View {
        let spentEUR = plan.cheapestTotalEUR(affordable)
        let leftGBP = max(0, budgetGBP - exchangeRates.pounds(fromEUR: spentEUR))
        let budget = budgetGBP.formatted(.currency(code: "GBP"))
        return VStack(alignment: .leading, spacing: 4) {
            if affordable == 0 {
                Text("\(budget) isn't enough for the cheapest card yet.")
                    .font(.headline)
            } else if affordable == plan.pricedMissing.count {
                Text("\(budget) buys every priced card you're missing.")
                    .font(.headline)
            } else {
                Text("\(budget) buys **\(affordable)** of the \(plan.pricedMissing.count) priced cards you're missing.")
            }
            Group {
                Text("Spent: \(exchangeRates.format(eur: spentEUR)) · left over: \(leftGBP.formatted(.currency(code: "GBP")))")
                if affordable < plan.pricedMissing.count, let next = plan.pricedMissing[affordable].priceEUR {
                    let shortGBP = max(0.01, exchangeRates.pounds(fromEUR: next) - leftGBP)
                    Text("The next card, \(plan.pricedMissing[affordable].name), needs \(shortGBP.formatted(.currency(code: "GBP"))) more.")
                }
                if !plan.unpricedMissing.isEmpty {
                    Text("Doesn't include the \(plan.unpricedMissing.count) without a price.")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    /// A divider in the list where the budget runs out.
    private func budgetLine(_ plan: CompletionPlan, affordable: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "flag.checkered")
            Text("\(budgetGBP.formatted(.currency(code: "GBP"))) budget ends here")
            Spacer()
            Text(exchangeRates.format(eur: plan.cheapestTotalEUR(affordable)))
                .monospacedDigit()
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.green)
        .listRowBackground(Color.green.opacity(0.12))
        .accessibilityElement(children: .combine)
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

    private func row(_ card: TCGCard, runningTotalEUR: Double?, inBudget: Bool) -> some View {
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
                        .foregroundStyle(inBudget ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
                }
            }
            .monospacedDigit()
        }
        .accessibilityValue(inBudget ? "In budget" : "")
        .swipeActions {
            Button("Got it", systemImage: "checkmark") { markOwned(card) }
                .tint(.green)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Mark as owned") { markOwned(card) }
    }

    private func markOwned(_ card: TCGCard) {
        withAnimation {
            editor.markOwned(card, setID: set.id, in: modelContext)
        }
    }
}
