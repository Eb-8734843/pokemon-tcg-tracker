//
//  ExchangeRates.swift
//  PokemonTCGTracker
//

import Foundation
import Observation

/// Converts Cardmarket's euro prices to pounds using the European Central
/// Bank's daily rate, from Frankfurter (https://frankfurter.dev, free, no key).
@Observable
final class ExchangeRates {
    nonisolated struct Rate: Codable, Equatable, Sendable {
        let eurToGBP: Double
        /// The day the ECB published this rate.
        let date: String
    }

    /// Used until the first rate loads: the ECB rate on 6 November 2026.
    static let fallback = Rate(eurToGBP: 0.83415, date: "2026-11-06")

    private(set) var rate: Rate
    private let cache: DiskCache?
    private let session: URLSession
    private static let cacheKey = "tcgdex-fx-eur-gbp"   // "tcgdex-" so old-file clean-up keeps it

    init(cache: DiskCache? = .shared, session: URLSession = .shared) {
        self.cache = cache
        self.session = session
        self.rate = cache?.load(Rate.self, key: Self.cacheKey) ?? Self.fallback
    }

    /// Gets today's rate. On failure, keeps the last saved one.
    func refresh() async {
        struct Response: Decodable { let date: String; let rates: [String: Double] }
        let url = URL(string: "https://api.frankfurter.dev/v1/latest?from=EUR&to=GBP")!
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let gbp = decoded.rates["GBP"], gbp > 0
        else { return }
        rate = Rate(eurToGBP: gbp, date: decoded.date)
        cache?.save(rate, key: Self.cacheKey)
    }

    func pounds(fromEUR euros: Double) -> Double {
        euros * rate.eurToGBP
    }

    func euros(fromGBP pounds: Double) -> Double {
        pounds / rate.eurToGBP
    }

    /// e.g. "£0.51". Anything under a penny shows as "<£0.01".
    func format(eur euros: Double) -> String {
        let gbp = pounds(fromEUR: euros)
        if gbp > 0, gbp < 0.005 { return "<£0.01" }
        return gbp.formatted(.currency(code: "GBP"))
    }
}
