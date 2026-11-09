//
//  PokemonTCGTrackerTests.swift
//  PokemonTCGTrackerTests
//
//  Created by Ebube-Chukwu Ekwe on 07/11/2026.
//

import Foundation
import Testing
@testable import PokemonTCGTracker

let testURL = URL(string: "https://example.com")!

func makeCard(_ number: String, _ name: String = "Test", category: String? = "Pokemon",
              rarity: String? = nil, types: [String]? = nil, image: URL? = testURL) -> TCGCard {
    TCGCard(id: "s-\(number)", name: name, number: number, category: category,
            rarity: rarity, types: types, imageBase: image)
}

// MARK: - Decoding TCGdex responses

struct TCGdexDecodingTests {
    @Test func decodesGraphQLSets() throws {
        // Trimmed copy of a real TCGdex GraphQL response (November 2026).
        let json = """
        {"data":{"sets":[
          {"id":"me05","name":"Pitch Black","logo":"https://assets.tcgdex.net/en/me/me05/logo","symbol":null,
           "releaseDate":"2026-07-17","serie":{"name":"Mega Evolution"},"cardCount":{"official":84,"total":120}},
          {"id":"base2","name":"Jungle","logo":"https://assets.tcgdex.net/en/base/base2/logo",
           "symbol":"https://assets.tcgdex.net/univ/base/base2/symbol",
           "releaseDate":"1999-06-16","serie":{"name":"Base"},"cardCount":{"official":64,"total":64}},
          {"id":"empty","name":"No Cards","logo":null,"symbol":null,
           "releaseDate":"2020-01-01","serie":{"name":"Misc"},"cardCount":{"official":0,"total":0}}
        ]}}
        """.data(using: .utf8)!

        let response = try TCGdexClient.decoder.decode(GraphQLResponse<SetsData>.self, from: json)
        let sets = try #require(response.data?.sets).compactMap(\.tcgSet)
        #expect(sets.map(\.id) == ["me05", "base2"])   // the empty set is skipped

        let pitchBlack = sets[0]
        #expect(pitchBlack.series == "Mega Evolution")
        #expect(pitchBlack.printedTotal == 84 && pitchBlack.total == 120)
        #expect(pitchBlack.logoURL?.absoluteString == "https://assets.tcgdex.net/en/me/me05/logo.webp")
        #expect(pitchBlack.symbolURL == nil)

        let parts = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "UTC")!, from: pitchBlack.releaseDate)
        #expect(parts.year == 2026 && parts.month == 7 && parts.day == 17)
    }

    @Test func decodesFullCard() throws {
        let json = """
        {"id":"me05-008","localId":"008","name":"Mega Delphox ex","image":"https://assets.tcgdex.net/en/me/me05/008",
         "category":"Pokemon","rarity":"Double rare","types":["Fire"],"hp":350,"pricing":{}}
        """.data(using: .utf8)!
        let card = try TCGdexClient.decoder.decode(CardDetail.self, from: json).tcgCard
        #expect(card.id == "me05-008")
        #expect(card.number == "008" && card.displayNumber == "8")
        #expect(card.rarity == "Double rare")
        #expect(card.typeCategories == ["Fire"])
        #expect(card.smallImageURL?.absoluteString == "https://assets.tcgdex.net/en/me/me05/008/low.webp")
    }

    @Test func decodesSetCardListWithMissingImage() throws {
        let json = """
        {"id":"me05","name":"Pitch Black","cards":[
          {"id":"me05-001","localId":"001","name":"Tropius","image":"https://assets.tcgdex.net/en/me/me05/001"},
          {"id":"me05-120","localId":"120","name":"Mega Darkrai ex"}]}
        """.data(using: .utf8)!
        let cards = try TCGdexClient.decoder.decode(SetDetail.self, from: json).cards.map(\.tcgCard)
        #expect(cards.count == 2)
        #expect(cards[1].smallImageURL == nil)
        #expect(cards[1].rarity == nil)
    }
}

// MARK: - Cards

struct TCGCardTests {
    @Test func sortsByCollectorNumber() {
        let shuffled = ["TG02", "010", "002", "TG01", "001", "100", "12a"].map { makeCard($0) }
        let sorted = shuffled.sorted(by: TCGCard.byCollectorNumber).map(\.number)
        #expect(sorted == ["001", "002", "010", "100", "12a", "TG01", "TG02"])
    }

    @Test func typeCategoriesUseCategoryForTrainersAndEnergy() {
        #expect(makeCard("1", category: "Trainer").typeCategories == ["Trainer"])
        #expect(makeCard("2", category: "Energy").typeCategories == ["Energy"])
        #expect(makeCard("3", category: "Pokemon", types: nil).typeCategories == ["Other"])
    }
}

// MARK: - Saving on device

struct DiskCacheTests {
    @Test func savesLoadsAndRemovesOldFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = DiskCache(directory: directory)

        let set = TCGSet(id: "me05", name: "Pitch Black", series: "Mega Evolution", printedTotal: 84, total: 120,
                         releaseDate: Date(timeIntervalSince1970: 1_784_246_400), logoBase: testURL, symbolBase: nil)

        #expect(cache.load([TCGSet].self, key: "tcgdex-sets") == nil)
        cache.save([set], key: "tcgdex-sets")
        cache.save(["old"], key: "sets")
        #expect(cache.load([TCGSet].self, key: "tcgdex-sets") == [set])

        cache.removeAll(exceptPrefix: "tcgdex-")
        #expect(cache.load([String].self, key: "sets") == nil)
        #expect(cache.load([TCGSet].self, key: "tcgdex-sets") == [set])
    }
}

// MARK: - Search and filters

struct CardFilterTests {
    var cards: [TCGCard] {
        [
            makeCard("001", "Tropius", rarity: "Common", types: ["Grass"]),
            makeCard("008", "Mega Delphox ex", rarity: "Double rare", types: ["Fire"]),
            makeCard("009", "Sizzlipede", rarity: "Common", types: ["Fire"]),
            makeCard("070", "Boss's Orders", category: "Trainer", rarity: "Uncommon"),
            makeCard("TG01", "Delphox", rarity: "Trainer Gallery Rare Holo", types: ["Fire"]),
        ]
    }

    func numbers(_ filter: CardFilter, owned: Set<String> = []) -> [String] {
        filter.apply(to: cards, ownedIDs: owned).map(\.number)
    }

    @Test func noFiltersShowsEverything() {
        #expect(numbers(CardFilter()).count == 5)
        #expect(CardFilter().hasActiveFilters == false)
    }

    @Test func searchMatchesNamePartOrNumber() {
        #expect(numbers(CardFilter(searchText: "delph")) == ["008", "TG01"])
        #expect(numbers(CardFilter(searchText: "tg01")) == ["TG01"])
        #expect(numbers(CardFilter(searchText: "  9 ")) == ["009"])    // "9" finds "009"
        #expect(numbers(CardFilter(searchText: "009")) == ["009"])
    }

    @Test func filtersByRarityTypeAndOwnership() {
        #expect(numbers(CardFilter(rarity: "Common")) == ["001", "009"])
        #expect(numbers(CardFilter(type: "Fire")) == ["008", "009", "TG01"])
        #expect(numbers(CardFilter(type: "Trainer")) == ["070"])
        #expect(numbers(CardFilter(ownership: .owned), owned: ["s-008"]) == ["008"])
        #expect(numbers(CardFilter(ownership: .missing), owned: ["s-008"]) == ["001", "009", "070", "TG01"])
    }

    @Test func filtersCombine() {
        let filter = CardFilter(searchText: "delphox", type: "Fire", ownership: .missing)
        #expect(filter.hasActiveFilters)
        #expect(numbers(filter, owned: ["s-008"]) == ["TG01"])
    }

    @Test func listsFilterOptionsInOrder() {
        #expect(CardFilter.rarities(in: cards) == ["Common", "Double rare", "Uncommon", "Trainer Gallery Rare Holo"])
        #expect(CardFilter.types(in: cards) == ["Grass", "Fire", "Trainer"])
    }
}

// MARK: - Moving owned cards from pokemontcg.io to TCGdex

struct OwnedCardMigrationTests {
    func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: c)!
    }

    var newSets: [TCGSet] {
        [
            TCGSet(id: "me05", name: "Pitch Black", series: "Mega Evolution", printedTotal: 84, total: 120,
                   releaseDate: day(2026, 7, 17), logoBase: nil, symbolBase: nil),
            TCGSet(id: "30th-c", name: "30th Classic Collection", series: "Mega Evolution", printedTotal: 30, total: 30,
                   releaseDate: day(2026, 9, 16), logoBase: nil, symbolBase: nil),
        ]
    }

    @Test func matchesSetByName() {
        let old = LegacySet(id: "me5", name: "Pitch Black", total: 120, releaseDate: day(2026, 7, 17))
        #expect(OwnedCardMigration.matchSet(old, in: newSets)?.id == "me05")
    }

    @Test func matchesRenamedSetByDateAndCount() {
        let old = LegacySet(id: "me55c", name: "30th Celebration: Classic Collection", total: 30, releaseDate: day(2026, 9, 16))
        #expect(OwnedCardMigration.matchSet(old, in: newSets)?.id == "30th-c")
    }

    @Test func doesNotGuessUnknownSets() {
        let old = LegacySet(id: "xx", name: "Made Up", total: 99, releaseDate: day(2001, 1, 1))
        #expect(OwnedCardMigration.matchSet(old, in: newSets) == nil)
    }

    @Test func matchesCardsByNumberAndName() {
        let summaries = [
            CardSummary(id: "me05-008", localId: "008", name: "Mega Delphox ex", image: nil),
            CardSummary(id: "me05-009", localId: "009", name: "Sizzlipede", image: nil),
        ]
        #expect(OwnedCardMigration.matchCard(number: "8", name: "Mega Delphox ex", in: summaries)?.id == "me05-008")
        // Only card with that number, even if the name is written differently.
        #expect(OwnedCardMigration.matchCard(number: "9", name: "Sizzlipede (Reverse)", in: summaries)?.id == "me05-009")
        #expect(OwnedCardMigration.matchCard(number: "500", name: "Nope", in: summaries) == nil)
    }

    @Test func legacySetListDecodes() throws {
        // How the old version saved its set list (default JSONEncoder dates).
        let json = """
        [{"id":"me5","name":"Pitch Black","series":"Mega Evolution","printedTotal":84,"total":120,
          "ptcgoCode":"PBL","releaseDate":805939200,"images":{"symbol":"https://x/s","logo":"https://x/l"}}]
        """.data(using: .utf8)!
        let sets = try JSONDecoder().decode([LegacySet].self, from: json)
        #expect(sets.first?.id == "me5")
        #expect(sets.first?.total == 120)
    }
}

// MARK: - Prices

struct PriceTests {
    func decodePrice(_ json: String) throws -> Double? {
        try JSONDecoder().decode(CardmarketPrice.self, from: json.data(using: .utf8)!).bestEUR
    }

    @Test func usesTrendThenAverageThenHolo() throws {
        #expect(try decodePrice(#"{"trend":0.61,"avg30":0.59,"low":0.05,"trend-holo":0}"#) == 0.61)
        #expect(try decodePrice(#"{"trend":0,"avg30":0.59,"trend-holo":0.2}"#) == 0.59)
        #expect(try decodePrice(#"{"trend":null,"avg30":null,"trend-holo":0.2}"#) == 0.2)
        #expect(try decodePrice(#"{"trend":0,"avg30":0,"trend-holo":0}"#) == nil)
    }

    @Test func fullCardCarriesPrice() throws {
        let json = """
        {"id":"me05-120","localId":"120","name":"Mega Darkrai ex","category":"Pokemon",
         "pricing":{"cardmarket":{"unit":"EUR","trend":127.35,"avg30":132.3,"low":100,"trend-holo":0}}}
        """.data(using: .utf8)!
        let card = try TCGdexClient.decoder.decode(CardDetail.self, from: json).tcgCard
        #expect(card.priceEUR == 127.35)
    }

    @MainActor @Test func formatsPounds() {
        let rates = ExchangeRates(cache: nil)   // uses the fallback rate, 0.83415
        #expect(rates.format(eur: 0.61) == "£0.51")
        #expect(rates.format(eur: 0.002) == "<£0.01")
        #expect(rates.format(eur: 0) == "£0.00")
    }

    @Test func refreshesMissingOrOldPrices() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(OwnedPriceRefresher.needsRefresh(nil, now: now))
        #expect(OwnedPriceRefresher.needsRefresh(now.addingTimeInterval(-13 * 3600), now: now))
        #expect(!OwnedPriceRefresher.needsRefresh(now.addingTimeInterval(-60), now: now))
    }
}

// MARK: - Cheapest path to completion

struct CompletionPlanTests {
    func card(_ number: String, _ price: Double?) -> TCGCard {
        TCGCard(id: "s-\(number)", name: "Card \(number)", number: number, category: "Pokemon",
                rarity: nil, types: nil, imageBase: nil, priceEUR: price)
    }

    var cards: [TCGCard] {
        [card("001", 0.02), card("002", 5.00), card("003", nil), card("004", 0.02), card("005", 127.35), card("006", 0.50)]
    }

    @Test func listsMissingCardsCheapestFirst() {
        let plan = CompletionPlan(cards: cards, ownedIDs: ["s-002"])
        #expect(plan.pricedMissing.map(\.number) == ["001", "004", "006", "005"])   // ties keep number order
        #expect(plan.unpricedMissing.map(\.number) == ["003"])
        #expect(plan.missingCount == 5)
    }

    @Test func addsUpTotals() {
        let plan = CompletionPlan(cards: cards, ownedIDs: ["s-002"])
        #expect(abs(plan.totalEUR - 127.89) < 0.0001)
        #expect(abs(plan.cheapestTotalEUR(3) - 0.54) < 0.0001)
        #expect(abs(plan.cheapestTotalEUR(99) - plan.totalEUR) < 0.0001)
    }

    @Test func completeWhenNothingMissing() {
        let plan = CompletionPlan(cards: cards, ownedIDs: Set(cards.map(\.id)))
        #expect(plan.isComplete)
        #expect(plan.totalEUR == 0)
    }
}
