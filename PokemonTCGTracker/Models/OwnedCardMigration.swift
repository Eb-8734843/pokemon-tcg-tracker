//
//  OwnedCardMigration.swift
//  PokemonTCGTracker
//

import Foundation
import SwiftData

/// Moves owned cards saved by the old pokemontcg.io version (IDs like "me5-8")
/// to TCGdex IDs (like "me05-008"). Runs once; if the network fails it tries
/// again on the next launch. Cards that can't be matched are left as they are.
enum OwnedCardMigration {
    static let doneKey = "ownedCardsMovedToTCGdex"
    /// The key the old version saved its set list under.
    static let legacySetsCacheKey = "sets"

    static func runIfNeeded(context: ModelContext,
                            client: TCGdexClient = TCGdexClient(),
                            defaults: UserDefaults = .standard) async {
        guard !defaults.bool(forKey: doneKey) else { return }

        let owned = (try? context.fetch(FetchDescriptor<OwnedCard>())) ?? []
        guard !owned.isEmpty,
              let oldSets = client.cache?.load([LegacySet].self, key: legacySetsCacheKey)
        else {
            finish(client: client, defaults: defaults)
            return
        }

        do {
            let newSets = try await client.fetchSets()
            for (oldSetID, cards) in Dictionary(grouping: owned, by: \.setID) {
                guard let oldSet = oldSets.first(where: { $0.id == oldSetID }),
                      let newSet = matchSet(oldSet, in: newSets)
                else { continue }

                let summaries = try await client.fetchCardSummaries(setID: newSet.id)
                for card in cards {
                    guard let match = matchCard(number: card.number, name: card.name, in: summaries) else { continue }
                    card.cardID = match.id
                    card.setID = newSet.id
                    card.number = match.localId
                }
            }
            try context.save()
            finish(client: client, defaults: defaults)
        } catch {
            // Offline or the database failed: leave the flag unset and try next launch.
        }
    }

    private static func finish(client: TCGdexClient, defaults: UserDefaults) {
        defaults.set(true, forKey: doneKey)
        client.cache?.removeAll(exceptPrefix: "tcgdex-")   // old pokemontcg.io files
    }

    // MARK: Matching (nonisolated so the tests can call them directly)

    /// Same name (ignoring case and punctuation), otherwise same release day and card count.
    nonisolated static func matchSet(_ old: LegacySet, in newSets: [TCGSet]) -> TCGSet? {
        if let byName = newSets.first(where: { normalized($0.name) == normalized(old.name) }) {
            return byName
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return newSets.first {
            calendar.isDate($0.releaseDate, inSameDayAs: old.releaseDate) && $0.total == old.total
        }
    }

    /// Same number and name; otherwise the only card with that number.
    nonisolated static func matchCard(number: String, name: String, in summaries: [CardSummary]) -> CardSummary? {
        let sameNumber = summaries.filter { numbersMatch($0.localId, number) }
        return sameNumber.first { normalized($0.name) == normalized(name) }
            ?? (sameNumber.count == 1 ? sameNumber[0] : nil)
    }

    /// "8" matches "008"; "TG05" matches "tg05".
    nonisolated static func numbersMatch(_ a: String, _ b: String) -> Bool {
        if let x = Int(a), let y = Int(b) { return x == y }
        return a.caseInsensitiveCompare(b) == .orderedSame
    }

    nonisolated static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .filter { $0.isLetter || $0.isNumber }
    }
}
