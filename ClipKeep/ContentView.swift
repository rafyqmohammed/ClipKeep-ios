//
//  ContentView.swift
//  ClipKeep
//
//  Created by tamtam-8 on 6/4/2026.
//

import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(ClipboardStore.self) private var clipboardStore
    @Environment(\.openURL) private var openURL

    var body: some View {
        ClipListView()
            .alert("Activer la capture automatique", isPresented: Binding(
                get: { clipboardStore.shouldShowPastePermissionPrompt },
                set: { clipboardStore.shouldShowPastePermissionPrompt = $0 }
            )) {
                Button("Plus tard", role: .cancel) {}
                Button("Autoriser") {
                    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(settingsURL)
                }
            } message: {
                Text("Pour éviter les demandes répétées et activer la capture auto: Réglages > ClipKeep > Coller à partir d'autres apps > Autoriser")
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ClipItem.self, inMemory: true)
}
