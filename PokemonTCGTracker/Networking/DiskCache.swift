//
//  DiskCache.swift
//  PokemonTCGTracker
//

import Foundation

/// Saves the last good API result for each request, so the app can show it
/// straight away, offline, or when the API is failing.
///
/// Stored in Application Support, not Caches, because iOS may empty Caches
/// and the app should keep working offline.
nonisolated struct DiskCache: Sendable {
    let directory: URL

    static let shared = DiskCache(directory: URL.applicationSupportDirectory.appending(path: "APICache", directoryHint: .isDirectory))

    func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = try? Data(contentsOf: fileURL(for: key)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func save<T: Encodable>(_ value: T, key: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: fileURL(for: key), options: .atomic)
        } catch {
            // A failed cache write only means the next launch fetches again.
        }
    }

    /// Deletes every saved file whose key doesn't start with `prefix`.
    func removeAll(exceptPrefix prefix: String) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where !file.lastPathComponent.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func fileURL(for key: String) -> URL {
        let safeKey = key.replacingOccurrences(of: "/", with: "_")
        return directory.appending(path: "\(safeKey).json")
    }
}
