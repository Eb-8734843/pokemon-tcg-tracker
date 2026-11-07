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

    init(card: TCGCard, setID: String, dateAdded: Date = .now) {
        self.cardID = card.id
        self.setID = setID
        self.name = card.name
        self.number = card.number
        self.dateAdded = dateAdded
    }
}
