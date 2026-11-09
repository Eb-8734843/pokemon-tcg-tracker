//
//  CollectionWidget.swift
//  CollectionWidget
//

import SwiftUI
import WidgetKit

@main
struct CollectionWidgetBundle: WidgetBundle {
    var body: some Widget {
        CollectionWidget()
    }
}

/// Home screen widget: the collection's value, and the sets closest to complete.
struct CollectionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshot.widgetKind, provider: Provider()) { entry in
            CollectionWidgetView(entry: entry)
                // Light text on the dark background, whatever the phone's setting.
                .environment(\.colorScheme, .dark)
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName("Collection")
        .description("Your collection's value and the sets you're closest to finishing.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline

struct Entry: TimelineEntry {
    let date: Date
    /// `nil` until the app has written its first summary.
    let snapshot: WidgetSnapshot?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        // The widget gallery shows sample data until there's a real collection.
        let snapshot = WidgetSnapshot.load()
        let hasCards = (snapshot?.cardCount ?? 0) > 0
        completion(Entry(date: .now, snapshot: context.isPreview && !hasCards ? .sample : snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // The app asks for a reload whenever the collection changes, so there's
        // nothing to schedule; refresh twice a day in case a reload was missed.
        let entry = Entry(date: .now, snapshot: WidgetSnapshot.load())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(12 * 60 * 60))))
    }
}

// MARK: - Views

struct CollectionWidgetView: View {
    let entry: Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot = entry.snapshot, snapshot.cardCount > 0 {
            switch family {
            case .systemMedium:
                HStack(alignment: .top, spacing: 16) {
                    ValueSummary(snapshot: snapshot)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SetList(sets: Array(snapshot.sets.prefix(3)))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            default:
                VStack(alignment: .leading, spacing: 0) {
                    ValueSummary(snapshot: snapshot)
                    Spacer(minLength: 6)
                    if let top = snapshot.sets.first {
                        SetRow(set: top, compact: true)
                    }
                }
            }
        } else {
            EmptyCollection()
        }
    }
}

private struct ValueSummary: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Collection", systemImage: "rectangle.stack.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(snapshot.valueGBP, format: .currency(code: "GBP"))
                .font(.title2.bold().monospacedDigit())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .widgetAccentable()
            Text("\(snapshot.cardCount) \(snapshot.cardCount == 1 ? "card" : "cards")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SetList: View {
    let sets: [WidgetSnapshot.SetProgress]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(sets) { SetRow(set: $0, compact: false) }
        }
    }
}

private struct SetRow: View {
    let set: WidgetSnapshot.SetProgress
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(set.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(set.owned)/\(set.total)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: set.fraction)
                .tint(set.owned >= set.total ? .green : .orange)
                .widgetAccentable()
            if !compact, let remaining = set.remainingGBP, set.owned < set.total {
                Text("about \(remaining, format: .currency(code: "GBP")) to finish")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct EmptyCollection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.title2)
                .widgetAccentable()
            Text("Start your collection")
                .font(.headline)
            Text("Open a set and tap the cards you own.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Matches the app icon: deep indigo to violet.
private struct WidgetBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.13, green: 0.12, blue: 0.36),
                                Color(red: 0.31, green: 0.22, blue: 0.62)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    CollectionWidget()
} timeline: {
    Entry(date: .now, snapshot: .sample)
    Entry(date: .now, snapshot: nil)
}

#Preview("Medium", as: .systemMedium) {
    CollectionWidget()
} timeline: {
    Entry(date: .now, snapshot: .sample)
}
