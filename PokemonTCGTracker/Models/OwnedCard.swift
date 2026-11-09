//
//  OwnedCard.swift
//  PokemonTCGTracker
//

import Foundation
import SwiftData

/// A card the user owns. Saved on the device with SwiftData.
///
/// Name and number are copied in so the collection can be shown later
/// without a network connection (the app is meant to work offline).
@Model
final class OwnedCard {
    @Attribute(.unique) var cardID: String
    var setID: String
    var name: String
    var number: String
    var dateAdded: Date
    /// Last known Cardmarket price in euros, kept here so the collection's
    /// value can be shown offline and without loading every set.
    var priceEUR: Double?
    var priceUpdated: Date?

    init(card: TCGCard, setID: String, dateAdded: Date = .now) {
        self.cardID = card.id
        self.setID = setID
        self.name = card.name
        self.number = card.number
        self.dateAdded = dateAdded
        self.priceEUR = card.priceEUR
        self.priceUpdated = card.priceEUR == nil ? nil : .now
    }

    /// Takes a newer price from freshly loaded card details.
    func updatePrice(from card: TCGCard, at date: Date = .now) {
        guard let price = card.priceEUR else { return }
        priceEUR = price
        priceUpdated = date
    }
}
