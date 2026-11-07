//
//  PokemonTCGTrackerApp.swift
//  PokemonTCGTracker
//
//  Created by Ebube-Chukwu Ekwe on 07/11/2026.
//

import SwiftUI

@main
struct PokemonTCGTrackerApp: App {
    init() {
        // Bigger shared cache so set logos don't re-download on every launch.
        URLCache.shared = URLCache(memoryCapacity: 20_000_000, diskCapacity: 200_000_000)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
