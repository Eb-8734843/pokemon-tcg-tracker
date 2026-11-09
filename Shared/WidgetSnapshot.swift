//
//  WidgetSnapshot.swift
//  Shared by PokemonTCGTracker and CollectionWidget
//

import Foundation

/// A small summary of the collection that the app writes to the shared
/// App Group folder and the home screen widget reads. The widget can't open
/// the app's SwiftData database, so this file is how they talk.
nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {
    struct SetProgress: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let name: String
        let owned: Int
        let total: Int
        /// What the missing cards with a price cost, in pounds. `nil` if the
        /// set's cards haven't been loaded on this device yet.
        let remainingGBP: Double?

        var fraction: Double { total > 0 ? min(Double(owned) / Double(total), 1) : 0 }
    }

    let updated: Date
    let cardCount: Int
    let valueGBP: Double
    /// Sets with at least one owned card, closest to complete first.
    let sets: [SetProgress]

    static let appGroupID = "group.glukka.wmin.ac.uk.PokemonTCGTracker"
    static let widgetKind = "CollectionWidget"

    /// Shown in the widget gallery and before the app has run.
    static let sample = WidgetSnapshot(
        updated: .now, cardCount: 42, valueGBP: 18.35,
        sets: [
            SetProgress(id: "a", name: "Pitch Black", owned: 96, total: 120, remainingGBP: 140.20),
            SetProgress(id: "b", name: "Chaos Rising", owned: 61, total: 122, remainingGBP: 88.10),
            SetProgress(id: "c", name: "Perfect Order", owned: 12, total: 124, remainingGBP: 210.00),
        ])

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appending(path: "widget-snapshot.json")
    }

    static func load() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Returns false if the App Group folder isn't available.
    @discardableResult
    func save() -> Bool {
        guard let url = Self.fileURL, let data = try? JSONEncoder().encode(self) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    /// Same contents, ignoring when it was written.
    func hasSameContent(as other: WidgetSnapshot?) -> Bool {
        guard let other else { return false }
        return cardCount == other.cardCount && valueGBP == other.valueGBP && sets == other.sets
    }
}
