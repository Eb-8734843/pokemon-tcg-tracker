//
//  SetListViewModel.swift
//  PokemonTCGTracker
//

import Foundation
import Observation

@Observable
final class SetListViewModel {
    enum State {
        case loading
        case loaded
        case failed(String)
    }

    private(set) var sets: [TCGSet] = []
    private(set) var state: State = .loading
    var searchText = ""

    private let client: TCGdexClient

    init(client: TCGdexClient = TCGdexClient()) {
        self.client = client
    }

    /// Sets grouped by series, with the series that has the newest set first.
    var seriesSections: [(series: String, sets: [TCGSet])] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let filtered = query.isEmpty ? sets : sets.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.series.localizedCaseInsensitiveContains(query)
        }
        let grouped = Dictionary(grouping: filtered, by: \.series)
        return grouped
            .map { (series: $0.key, sets: $0.value.sorted { $0.releaseDate > $1.releaseDate }) }
            .sorted { ($0.sets.first?.releaseDate ?? .distantPast) > ($1.sets.first?.releaseDate ?? .distantPast) }
    }

    func load() async {
        // Show the saved copy straight away, then refresh it from the API.
        if sets.isEmpty, let saved = client.cachedSets(), !saved.isEmpty {
            sets = saved
            state = .loaded
        }
        if sets.isEmpty { state = .loading }
        do {
            sets = try await client.fetchSets()
            state = .loaded
        } catch is CancellationError {
            // The view went away or the refresh was cancelled; keep what we have.
        } catch {
            // Keep showing already-loaded sets on a failed refresh.
            state = sets.isEmpty ? .failed(error.localizedDescription) : .loaded
        }
    }
}
