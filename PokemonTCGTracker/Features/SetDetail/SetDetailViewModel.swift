//
//  SetDetailViewModel.swift
//  PokemonTCGTracker
//

import Foundation
import Observation

@Observable
final class SetDetailViewModel {
    enum State {
        case loading
        case loaded
        case failed(String)
    }

    let set: TCGSet
    private(set) var cards: [TCGCard] = []
    private(set) var state: State = .loading

    private let client: PokemonTCGClient

    init(set: TCGSet, client: PokemonTCGClient = PokemonTCGClient()) {
        self.set = set
        self.client = client
    }

    func load() async {
        // Show the saved copy straight away, then refresh it from the API.
        if cards.isEmpty, let saved = client.cachedCards(setID: set.id), !saved.isEmpty {
            cards = saved
            state = .loaded
        }
        if cards.isEmpty { state = .loading }
        do {
            cards = try await client.fetchCards(setID: set.id)
            state = .loaded
        } catch is CancellationError {
        } catch {
            state = cards.isEmpty ? .failed(error.localizedDescription) : .loaded
        }
    }
}
