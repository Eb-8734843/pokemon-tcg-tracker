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
