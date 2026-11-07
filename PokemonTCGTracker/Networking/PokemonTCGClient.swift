//
//  PokemonTCGClient.swift
//  PokemonTCGTracker
//

import Foundation

enum PokemonTCGError: LocalizedError {
    case badStatus(Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .badStatus(429):
            "The Pokémon TCG API rate limit was hit. Try again in a minute."
        case .badStatus(let code) where code >= 500:
            "The Pokémon TCG API is having trouble (error \(code)). Try again shortly."
        case .badStatus(let code):
            "The Pokémon TCG API returned error \(code)."
        case .decoding:
            "The Pokémon TCG API sent data the app didn't understand."
        }
    }
}

/// Talks to https://api.pokemontcg.io/v2.
///
/// The API key is optional (it raises the rate limit). It's read from the
/// `PokemonTCGAPIKey` Info.plist entry, which comes from `Config/Secrets.xcconfig`.
nonisolated struct PokemonTCGClient: Sendable {
    var baseURL = URL(string: "https://api.pokemontcg.io/v2")!
    var apiKey: String? = PokemonTCGClient.bundledAPIKey
    var session: URLSession = .shared
    /// Where the last good results are kept. `nil` turns saving off (used in tests).
    var cache: DiskCache? = .shared
    /// How many extra attempts to make after a 5xx/429 response.
    /// In November 2026 between 4 and 9 in 10 requests failed with a quick 500/502,
    /// so retry generously. The saved copy in `cache` covers the rest.
    var maxRetries = 10

    static var bundledAPIKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "PokemonTCGAPIKey") as? String,
              !key.isEmpty, !key.hasPrefix("$(")
        else { return nil }
        return key
    }

    /// Every set, newest first. The API has ~180 sets, so one 250-item page covers them.
    func fetchSets() async throws -> [TCGSet] {
        var components = URLComponents(url: baseURL.appending(path: "sets"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "orderBy", value: "-releaseDate"),
            URLQueryItem(name: "pageSize", value: "250"),
            URLQueryItem(name: "select", value: "id,name,series,printedTotal,total,ptcgoCode,releaseDate,images"),
        ]
        let response: PagedResponse<TCGSet> = try await get(components.url!)
        cache?.save(response.data, key: "sets")
        return response.data
    }

    /// The set list saved from the last successful fetch, if any.
    func cachedSets() -> [TCGSet]? {
        cache?.load([TCGSet].self, key: "sets")
    }

    /// The card list for a set saved from the last successful fetch, if any.
    func cachedCards(setID: String) -> [TCGCard]? {
        cache?.load([TCGCard].self, key: "cards-\(setID)")
    }

    /// Every card in a set, in collector-number order. Fetches extra pages for big sets.
    func fetchCards(setID: String) async throws -> [TCGCard] {
        var cards: [TCGCard] = []
        var page = 1
        while true {
            var components = URLComponents(url: baseURL.appending(path: "cards"), resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "q", value: "set.id:\(setID)"),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "pageSize", value: "250"),
                URLQueryItem(name: "select", value: "id,name,number,supertype,rarity,images"),
            ]
            let response: PagedResponse<TCGCard> = try await get(components.url!)
            cards += response.data
            if response.data.isEmpty || cards.count >= response.totalCount { break }
            page += 1
        }
        cards.sort(by: TCGCard.byCollectorNumber)
        cache?.save(cards, key: "cards-\(setID)")
        return cards
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let apiKey { request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key") }

        var attempt = 0
        while true {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0

            // The API sometimes returns a one-off 502, so retry server errors with a short backoff.
            if (status >= 500 || status == 429), attempt < maxRetries {
                attempt += 1
                // Failures come back fast, so short waits: 0.3s, 0.6s, 0.9s, then 1s each.
                try await Task.sleep(for: .milliseconds(min(300 * attempt, 1000)))
                continue
            }
            guard (200..<300).contains(status) else { throw PokemonTCGError.badStatus(status) }

            do {
                return try Self.decoder.decode(T.self, from: data)
            } catch {
                throw PokemonTCGError.decoding(error)
            }
        }
    }

    /// The API sends dates as "2026/09/16".
    static let decoder: JSONDecoder = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy/MM/dd"
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }()
}
