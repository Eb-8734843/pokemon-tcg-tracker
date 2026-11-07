//
//  PokemonTCGTrackerTests.swift
//  PokemonTCGTrackerTests
//
//  Created by Ebube-Chukwu Ekwe on 07/11/2026.
//

import Foundation
import Testing
@testable import PokemonTCGTracker

struct TCGSetDecodingTests {
    // Trimmed copy of a real /v2/sets response (November 2026).
    let json = """
    {"data":[
      {"id":"me55c","name":"30th Celebration: Classic Collection","series":"Mega Evolution","total":30,
       "ptcgoCode":"30C","releaseDate":"2026/09/16",
       "images":{"symbol":"https://images.scrydex.com/pokemon/me55c-symbol/symbol","logo":"https://images.scrydex.com/pokemon/me55c-logo/logo"}},
      {"id":"me55","name":"30th Celebration","series":"Mega Evolution","printedTotal":128,"total":161,
       "releaseDate":"2026/09/16",
       "images":{"symbol":"https://images.scrydex.com/pokemon/me55-symbol/symbol","logo":"https://images.scrydex.com/pokemon/me55-logo/logo"}}
    ],"page":1,"pageSize":2,"count":2,"totalCount":176}
    """.data(using: .utf8)!

    @Test func decodesSetsPage() throws {
        let page = try PokemonTCGClient.decoder.decode(PagedResponse<TCGSet>.self, from: json)
        #expect(page.totalCount == 176)
        #expect(page.data.count == 2)

        let classic = page.data[0]
        #expect(classic.id == "me55c")
        #expect(classic.printedTotal == nil)
        #expect(classic.images.logo.absoluteString.hasSuffix("me55c-logo/logo"))

        let parts = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "UTC")!, from: classic.releaseDate)
        #expect(parts.year == 2026 && parts.month == 9 && parts.day == 16)

        #expect(page.data[1].printedTotal == 128)
    }
}

struct TCGCardTests {
    func card(_ number: String) -> TCGCard {
        let url = URL(string: "https://example.com")!
        return TCGCard(id: "x-\(number)", name: "Test", number: number, supertype: nil, rarity: nil,
                       images: .init(small: url, large: url))
    }

    @Test func sortsByCollectorNumber() {
        let shuffled = ["TG02", "10", "2", "TG01", "1", "100", "12a"].map(card)
        let sorted = shuffled.sorted(by: TCGCard.byCollectorNumber).map(\.number)
        #expect(sorted == ["1", "2", "10", "100", "12a", "TG01", "TG02"])
    }

    @Test func decodesCardWithoutRarity() throws {
        let json = """
        {"data":[{"id":"me55-1","name":"Exeggcute","supertype":"Pokémon","number":"1",
          "images":{"small":"https://images.scrydex.com/pokemon/me55-1/small","large":"https://images.scrydex.com/pokemon/me55-1/large"}}],
         "page":1,"pageSize":1,"count":1,"totalCount":161}
        """.data(using: .utf8)!
        let page = try PokemonTCGClient.decoder.decode(PagedResponse<TCGCard>.self, from: json)
        #expect(page.data.first?.name == "Exeggcute")
        #expect(page.data.first?.rarity == nil)
    }
}

struct DiskCacheTests {
    @Test func savesAndLoadsSets() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = DiskCache(directory: directory)

        let url = URL(string: "https://example.com/logo")!
        let set = TCGSet(id: "me5", name: "Pitch Black", series: "Mega Evolution", printedTotal: 84, total: 120,
                         ptcgoCode: "PBL", releaseDate: Date(timeIntervalSince1970: 1_784_246_400),
                         images: .init(symbol: url, logo: url))

        #expect(cache.load([TCGSet].self, key: "sets") == nil)
        cache.save([set], key: "sets")
        #expect(cache.load([TCGSet].self, key: "sets") == [set])
    }
}
