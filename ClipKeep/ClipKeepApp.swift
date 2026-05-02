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
//            
//            // 🔍 Affiche le chemin de la base de données
//            if let storeURL = modelContainer.configurations.first?.url {
//                print("📁 Database Path: \(storeURL.path)")
//                print("📁 Full URL: \(storeURL)")
//            }
//            
        } catch {
            let storeURL = ModelConfiguration().url
            try? FileManager.default.removeItem(at: storeURL)
            do {
                modelContainer = try ModelContainer(for: ClipItem.self)
//                
//                // 🔍 Affiche le chemin après récréation
//                if let storeURL = modelContainer.configurations.first?.url {
//                    print("📁 Database Path (recreated): \(storeURL.path)")
//                }
//                
            } catch {
                fatalError("Could not initialize ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(clipboardStore)
                .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
                    Task {
                        clipboardStore.checkClipboard(context: modelContainer.mainContext)
                    }
                }
        }
    }
}
