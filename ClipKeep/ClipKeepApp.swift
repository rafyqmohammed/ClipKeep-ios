//
//  ClipKeepApp.swift
//  ClipKeep
//
//  Created by tamtam-8 on 6/4/2026.
//

import SwiftUI
import SwiftData
import Combine

@main
struct ClipKeepApp: App {
    let modelContainer: ModelContainer
    @State private var clipboardStore = ClipboardStore()

    init() {
        do {
            modelContainer = try ModelContainer(for: ClipItem.self)
        } catch {
            // Le schéma a changé (ex. nouveau champ) : on supprime l'ancien store et on recrée
            let storeURL = ModelConfiguration().url
            try? FileManager.default.removeItem(at: storeURL)
            do {
                modelContainer = try ModelContainer(for: ClipItem.self)
            } catch {
                fatalError("Could not initialize ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(clipboardStore)  // injecte dans l'environnement
                .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
                    Task {
                        clipboardStore.checkClipboard(context: modelContainer.mainContext)
                    }
                }
        }
    }
}
