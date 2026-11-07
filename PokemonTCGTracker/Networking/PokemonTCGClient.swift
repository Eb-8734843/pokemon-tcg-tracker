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
    /// How many extra attempts to make after a 5xx/429 response.
    var maxRetries = 2

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
        return response.data
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
                try await Task.sleep(for: .seconds(Double(attempt)))
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
