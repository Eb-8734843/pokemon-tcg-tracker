//
//  SetListView.swift
//  PokemonTCGTracker
//

import SwiftUI
import SwiftData

struct SetListView: View {
    @State private var model = SetListViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Sets")
                .searchable(text: $model.searchText, prompt: "Search sets or series")
                .task { await model.load() }
                .refreshable { await model.load() }
                .navigationDestination(for: TCGSet.self) { set in
                    SetDetailView(set: set)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView("Loading sets…")
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load sets", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await model.load() } }
                    .buttonStyle(.borderedProminent)
            }
        case .loaded:
            List {
                ForEach(model.seriesSections, id: \.series) { section in
                    Section(section.series) {
                        ForEach(section.sets) { set in
                            NavigationLink(value: set) {
                                SetRow(set: set)
                            }
                        }
                    }
                }
            }
            .overlay {
                if model.seriesSections.isEmpty {
                    ContentUnavailableView.search(text: model.searchText)
                }
            }
        }
    }
}

struct SetRow: View {
    let set: TCGSet

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: set.images.logo) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    Image(systemName: "photo").foregroundStyle(.secondary)
                default:
                    ProgressView()
                }
            }
            .frame(width: 96, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(set.name)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    AsyncImage(url: set.images.symbol) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color.clear
                    }
                    .frame(width: 14, height: 14)
                    Text("\(set.total) cards · \(set.releaseDate.formatted(date: .abbreviated, time: .omitted))")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SetListView()
        .modelContainer(for: OwnedCard.self, inMemory: true)
}
