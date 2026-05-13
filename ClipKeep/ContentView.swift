import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(ClipboardStore.self) private var clipboardStore
    @Environment(\.openURL) private var openURL

    var body: some View {
        ClipListView()
            .alert(loc("alert.permission.title"), isPresented: Binding(
                get: { clipboardStore.shouldShowPastePermissionPrompt },
                set: { clipboardStore.shouldShowPastePermissionPrompt = $0 }
            )) {
                Button(loc("action.later"), role: .cancel) {}
                Button(loc("action.allow")) {
                    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(settingsURL)
                }
            } message: {
                Text(loc("alert.permission.message"))
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ClipItem.self, inMemory: true)
}
