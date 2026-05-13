import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(ClipboardStore.self) var clipboardStore
    @EnvironmentObject var langManager: LanguageManager
    @Query(sort: \ClipItem.createdAt, order: .reverse) var clips: [ClipItem]
    @State private var showConfirmation = false
    @State private var isGeneratingPDF = false
    @AppStorage("retentionDays") private var retentionDays: Int = 0
    @AppStorage("maxItems") private var maxItems: Int = 0

    var body: some View {
        NavigationStack {
            List {
                captureSection
                infoSection
                storageSection
                languageSection
                exportSection
                actionsSection
                aboutSection
            }
            .navigationTitle(loc("title.settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(loc("action.close")) { dismiss() }
                }
            }
            .alert(loc("alert.delete.title"), isPresented: $showConfirmation) {
                Button(loc("action.cancel"), role: .cancel) { }
                Button(loc("action.confirm.delete"), role: .destructive) { clearAll() }
            } message: {
                Text(loc("alert.delete.message"))
            }
            .overlay { pdfLoadingOverlay }
        }
    }

    @ViewBuilder
    private var captureSection: some View {
        Section(header: Text(loc("settings.section.capture"))) {
            Toggle(isOn: Binding(
                get: { clipboardStore.isEnabled },
                set: { clipboardStore.isEnabled = $0 }
            )) {
                Label(
                    clipboardStore.isEnabled
                        ? loc("settings.capture.enabled")
                        : loc("settings.capture.disabled"),
                    systemImage: clipboardStore.isEnabled
                        ? "doc.on.clipboard.fill"
                        : "doc.on.clipboard"
                )
            }
            .tint(.green)
        }
    }

    @ViewBuilder
    private var infoSection: some View {
        Section(header: Text(loc("settings.section.info"))) {
            HStack {
                Text(loc("settings.info.saved"))
                Spacer()
                Text("\(clips.count)").fontWeight(.semibold)
            }
            HStack {
                Text(loc("settings.info.pinned"))
                Spacer()
                Text("\(clips.filter(\.isPinned).count)").fontWeight(.semibold)
            }
        }
    }

    @ViewBuilder
    private var storageSection: some View {
        Section(header: Text(loc("settings.section.storage"))) {
            Picker(loc("settings.storage.retention"), selection: $retentionDays) {
                Text(loc("settings.storage.unlimited")).tag(0)
                Text(loc("settings.storage.7days")).tag(7)
                Text(loc("settings.storage.30days")).tag(30)
            }
            Picker(loc("settings.storage.limit"), selection: $maxItems) {
                Text(loc("settings.storage.unlimited")).tag(0)
                Text(loc("settings.storage.50items")).tag(50)
                Text(loc("settings.storage.100items")).tag(100)
            }
        }
        .onChange(of: retentionDays) { _, _ in applyCleanup() }
        .onChange(of: maxItems) { _, _ in applyCleanup() }
    }

    @ViewBuilder
    private var languageSection: some View {
        Section(header: Text(loc("settings.section.language"))) {
            languageRow(code: "fr", name: " Français")
            languageRow(code: "en", name: " English")
            languageRow(code: "ar", name: " العربية")
            languageRow(code: "es", name: " Español")
        }
    }

    private func languageRow(code: String, name: String) -> some View {
        Button {
            langManager.set(code)
        } label: {
            HStack {
                Text(name).foregroundStyle(.primary)
                Spacer()
                if langManager.current == code {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    @ViewBuilder
    private var exportSection: some View {
        Section(header: Text(loc("settings.section.export"))) {
            Button { exportPDF() } label: {
                HStack {
                    Image(systemName: "arrow.up.doc")
                    Text(loc("action.export.pdf"))
                }
            }
            .disabled(clips.isEmpty || isGeneratingPDF)
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        Section(header: Text(loc("settings.section.actions"))) {
            Button(role: .destructive) {
                showConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text(loc("action.clear.history"))
                }
            }
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section(header: Text(loc("settings.section.about"))) {
            HStack {
                Text(loc("settings.about.version"))
                Spacer()
                Text("1.0").foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var pdfLoadingOverlay: some View {
        if isGeneratingPDF {
            ZStack {
                Color.black.opacity(0.4).ignoresSafeArea()
                VStack(spacing: 14) {
                    ProgressView().scaleEffect(1.3).tint(.white)
                    Text(loc("settings.loading.pdf"))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                }
                .padding(28)
                .background(.ultraThinMaterial)
                .cornerRadius(18)
            }
        }
    }

    private func clearAll() {
        do {
            try modelContext.delete(model: ClipItem.self)
            try modelContext.save()
        } catch {
            print("Erreur: \(error)")
        }
    }

    private func applyCleanup() {
        let store = ClipboardStore()
        store.cleanupIfNeeded(context: modelContext)
    }

    private func exportPDF() {
        isGeneratingPDF = true
        Task { @MainActor in
            await Task.yield()
            let data = await PDFExporter.generate(from: clips)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("ClipKeep-History.pdf")
            try? data.write(to: url)
            withAnimation { isGeneratingPDF = false }
            await Task.yield()
            ActivityShareSheet.present(items: [url])
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: ClipItem.self, inMemory: true)
        .environmentObject(LanguageManager.shared)
}
