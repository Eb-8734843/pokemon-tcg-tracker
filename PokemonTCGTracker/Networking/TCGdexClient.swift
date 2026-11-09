//
//  TCGdexClient.swift
//  PokemonTCGTracker
//

import Foundation

enum TCGdexError: LocalizedError {
    case badStatus(Int)
    case decoding(Error)
    case graphQL(String)

    var errorDescription: String? {
        switch self {
        case .badStatus(429):
            "The card database is busy. Try again in a minute."
        case .badStatus(let code) where code >= 500:
            "The card database is having trouble (error \(code)). Try again shortly."
        case .badStatus(let code):
            "The card database returned error \(code)."
        case .decoding, .graphQL:
            "The card database sent data the app didn't understand."
        }
    }
}

/// Talks to TCGdex (https://tcgdex.dev), a free card database with no API key.
///
/// - The set list comes from one GraphQL request, because only GraphQL gives
///   every set's series and release date at once.
/// - A set's cards come from the REST API: the set's card list, then each
///   card's full details (rarity, type, and prices for week 4), a few at a time.
nonisolated struct TCGdexClient: Sendable {
    var baseURL = URL(string: "https://api.tcgdex.net/v2/en")!
    var graphQLURL = URL(string: "https://api.tcgdex.net/v2/graphql")!
    var session: URLSession = .shared
    /// Where the last good results are kept. `nil` turns saving off (used in tests).
    var cache: DiskCache? = .shared
    /// Extra attempts after a 5xx/429 response.
    var maxRetries = 3
    /// How many card requests run at the same time.
    var maxConcurrentRequests = 8

    // MARK: Sets

    /// Every set, newest first.
    func fetchSets() async throws -> [TCGSet] {
        let query = """
        { sets { id name logo symbol releaseDate serie { name } cardCount { official total } } }
        """
        var request = URLRequest(url: graphQLURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["query": query])

        let response: GraphQLResponse<SetsData> = try await send(request)
        if let message = response.errors?.first?.message { throw TCGdexError.graphQL(message) }
        let sets = (response.data?.sets ?? [])
            .compactMap(\.tcgSet)
            .sorted { $0.releaseDate > $1.releaseDate }
        cache?.save(sets, key: Self.setsCacheKey)
        return sets
    }

    /// The set list saved from the last successful fetch, if any.
    func cachedSets() -> [TCGSet]? {
        cache?.load([TCGSet].self, key: Self.setsCacheKey)
    }

    // MARK: Cards

    /// The short card list for a set (ID, number, name, image), straight from TCGdex.
    func fetchCardSummaries(setID: String) async throws -> [CardSummary] {
        let set: SetDetail = try await send(URLRequest(url: baseURL.appending(path: "sets/\(setID)")))
        return set.cards
    }

    /// Every card in a set with full details, in collector-number order.
    ///
    /// If a single card's details can't be loaded, it's still included using
    /// the short details (no rarity or type), so one bad card doesn't hide the set.
    func fetchCards(setID: String) async throws -> [TCGCard] {
        let summaries = try await fetchCardSummaries(setID: setID)

        var cards: [TCGCard] = []
        cards.reserveCapacity(summaries.count)
        try await withThrowingTaskGroup(of: TCGCard.self) { group in
            var next = summaries.makeIterator()
            func addTask() {
                guard let summary = next.next() else { return }
                group.addTask {
                    do {
                        let detail: CardDetail = try await send(URLRequest(url: baseURL.appending(path: "cards/\(summary.id)")))
                        return detail.tcgCard
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        return summary.tcgCard
                    }
                }
            }
            for _ in 0..<maxConcurrentRequests { addTask() }
            while let card = try await group.next() {
                cards.append(card)
                addTask()
            }
        }

        cards.sort(by: TCGCard.byCollectorNumber)
        cache?.save(cards, key: Self.cardsCacheKey(setID))
        return cards
    }

    /// The card list for a set saved from the last successful fetch, if any.
    func cachedCards(setID: String) -> [TCGCard]? {
        cache?.load([TCGCard].self, key: Self.cardsCacheKey(setID))
    }

    // Prefixed so they never clash with files saved by the old pokemontcg.io version.
    static let setsCacheKey = "tcgdex-sets"
    static func cardsCacheKey(_ setID: String) -> String { "tcgdex-cards-\(setID)" }

    // MARK: Requests

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        var request = request
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var attempt = 0
        while true {
            try Task.checkCancellation()
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0

            if (status >= 500 || status == 429), attempt < maxRetries {
                attempt += 1
                try await Task.sleep(for: .milliseconds(300 * attempt))
                continue
            }
            guard (200..<300).contains(status) else { throw TCGdexError.badStatus(status) }

            do {
                return try Self.decoder.decode(T.self, from: data)
            } catch {
                throw TCGdexError.decoding(error)
            }
        }
    }

    /// TCGdex sends dates as "2026-07-17".
    static let decoder: JSONDecoder = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }()
}

// MARK: - TCGdex response shapes

nonisolated struct GraphQLResponse<DataType: Decodable & Sendable>: Decodable, Sendable {
    struct Message: Decodable, Sendable { let message: String }
    let data: DataType?
    let errors: [Message]?
}

nonisolated struct SetsData: Decodable, Sendable {
    let sets: [SetNode]

    struct SetNode: Decodable, Sendable {
        struct Serie: Decodable, Sendable { let name: String }
        struct CardCount: Decodable, Sendable { let official: Int?; let total: Int? }

        let id: String
        let name: String
        let logo: URL?
        let symbol: URL?
        let releaseDate: Date?
        let serie: Serie?
        let cardCount: CardCount?

        /// Skips sets with no release date or no cards, which can't be shown sensibly.
        var tcgSet: TCGSet? {
            guard let releaseDate, let total = cardCount?.total, total > 0 else { return nil }
            return TCGSet(id: id, name: name, series: serie?.name ?? "Other", printedTotal: cardCount?.official,
                          total: total, releaseDate: releaseDate, logoBase: logo, symbolBase: symbol)
        }
    }
}

nonisolated struct SetDetail: Decodable, Sendable {
    let cards: [CardSummary]
}

/// The short card details TCGdex lists inside a set.
nonisolated struct CardSummary: Decodable, Sendable {
    let id: String
    let localId: String
    let name: String
    let image: URL?

    var tcgCard: TCGCard {
        TCGCard(id: id, name: name, number: localId, category: nil, rarity: nil, types: nil, imageBase: image)
    }
}

/// The full card details from `GET /cards/{id}`.
nonisolated struct CardDetail: Decodable, Sendable {
    let id: String
    let localId: String
    let name: String
    let image: URL?
    let category: String?
    let rarity: String?
    let types: [String]?

    var tcgCard: TCGCard {
        TCGCard(id: id, name: name, number: localId, category: category, rarity: rarity, types: types, imageBase: image)
    }
}
