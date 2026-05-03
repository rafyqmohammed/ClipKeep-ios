//
//  ClipListView.swift
//  ClipKeep
//
//  Created by tamtam-8 on 6/4/2026.
//

import SwiftUI
import SwiftData

struct ClipListView: View {
    @Query(sort: \ClipItem.createdAt, order: .reverse) var clips: [ClipItem]
    @Environment(\.modelContext) var modelContext
    @Environment(ClipboardStore.self) var clipboardStore
    @State private var showSettings = false
    @State private var searchText = ""
    @State private var filterType: ClipType? = nil
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var isExportingPDF = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    // MARK: - Computed

    private var displayedClips: [ClipItem] {
        let filtered = clips.filter { clip in
            let matchesType = filterType == nil || clip.type == filterType
            let matchesSearch: Bool
            if searchText.isEmpty {
                matchesSearch = true
            } else if clip.type == .image {
                matchesSearch = false
            } else {
                matchesSearch = clip.textValue.localizedCaseInsensitiveContains(searchText)
            }
            return matchesType && matchesSearch
        }
        return filtered.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private var selectedClips: [ClipItem] {
        displayedClips.filter { selectedIDs.contains($0.id) }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                if clips.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        SearchField(text: $searchText)
                            .padding(.top, 8)
                            .padding(.bottom, 4)

                        FilterBar(selected: $filterType)
                            .padding(.vertical, 6)

                        if displayedClips.isEmpty {
                            noResultsView
                        } else {
                            List {
                                ForEach(displayedClips) { clip in
                                    if isSelecting {
                                        selectionRow(clip)
                                    } else {
                                        navigationRow(clip)
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .scrollDismissesKeyboard(.interactively)
                        }
                    }
                }
            }
            .navigationTitle(isSelecting
                ? "\(selectedIDs.count) sélectionné(s)"
                : "ClipKeep")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .animation(.easeInOut(duration: 0.2), value: isSelecting)
            .fullScreenCover(isPresented: Binding(
                get: { !hasSeenOnboarding },
                set: { _ in }
            )) {
                OnboardingView { hasSeenOnboarding = true }
            }
            .overlay(alignment: .bottom) {
                if let message = clipboardStore.captureToast {
                    CaptureToast(message: message)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.35), value: clipboardStore.captureToast)
            .overlay {
                if isExportingPDF {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        VStack(spacing: 14) {
                            ProgressView()
                                .scaleEffect(1.3)
                                .tint(.white)
                            Text("Génération du PDF…")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white)
                        }
                        .padding(28)
                        .background(.ultraThinMaterial)
                        .cornerRadius(18)
                    }
                }
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func navigationRow(_ clip: ClipItem) -> some View {
        NavigationLink(destination: ClipDetailView(clip: clip)) {
            ClipItemView(item: clip)
        }
        .contextMenu {
            Button { copyClip(clip) } label: {
                Label("Copier", systemImage: "doc.on.doc")
            }
            shareMenuButton(for: clip)
            Divider()
            Button {
                withAnimation { clip.isPinned.toggle(); try? modelContext.save() }
            } label: {
                Label(
                    clip.isPinned ? "Désépingler" : "Épingler",
                    systemImage: clip.isPinned ? "pin.slash" : "pin"
                )
            }
            Divider()
            Button(role: .destructive) {
                withAnimation { modelContext.delete(clip); try? modelContext.save() }
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation { clip.isPinned.toggle(); try? modelContext.save() }
            } label: {
                Label(clip.isPinned ? "Désépingler" : "Épingler",
                      systemImage: clip.isPinned ? "pin.slash" : "pin")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation { modelContext.delete(clip); try? modelContext.save() }
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func selectionRow(_ clip: ClipItem) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if selectedIDs.contains(clip.id) { selectedIDs.remove(clip.id) }
                else { selectedIDs.insert(clip.id) }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedIDs.contains(clip.id)
                      ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(selectedIDs.contains(clip.id) ? .accentColor : .secondary)
                ClipItemView(item: clip)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Share helper (contextMenu)

    @ViewBuilder
    private func shareMenuButton(for clip: ClipItem) -> some View {
        if clip.type == .url, let url = URL(string: clip.textValue) {
            ShareLink(item: url) {
                Label("Partager", systemImage: "square.and.arrow.up")
            }
        } else if clip.type == .image, let uiImage = UIImage(data: clip.contentData) {
            ShareLink(
                item: Image(uiImage: uiImage),
                preview: SharePreview("Image", image: Image(uiImage: uiImage))
            ) {
                Label("Partager", systemImage: "square.and.arrow.up")
            }
        } else {
            ShareLink(item: clip.textValue) {
                Label("Partager", systemImage: "square.and.arrow.up")
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isSelecting {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Annuler") {
                    isSelecting = false
                    selectedIDs.removeAll()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    let textClips = selectedClips.filter { $0.type != .image }
                    if !textClips.isEmpty {
                        Button {
                            let content = formattedShareContent(for: textClips)
                            ActivityShareSheet.present(items: [content]) { completed in
                                if completed {
                                    self.selectedIDs.removeAll()
                                    self.isSelecting = false
                                }
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    Button {
                        exportSelectedAsPDF()
                    } label: {
                        if isExportingPDF {
                            ProgressView().scaleEffect(0.75)
                        } else {
                            Image(systemName: "arrow.up.doc")
                        }
                    }
                    .disabled(selectedIDs.isEmpty || isExportingPDF)
                    Button(role: .destructive) {
                        deleteSelected()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
        } else {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        clipboardStore.isEnabled.toggle()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(clipboardStore.isEnabled ? Color.green : Color.red)
                            .frame(width: 7, height: 7)
                        Text(clipboardStore.isEnabled ? "Actif" : "Inactif")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        withAnimation { isSelecting = true }
                    } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func formattedShareContent(for clips: [ClipItem]) -> String {
        guard clips.count > 1 else { return clips[0].textValue }

        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        fmt.locale = Locale(identifier: "fr_FR")

        return clips.map { clip in
            let icon: String
            let label: String
            switch clip.type {
            case .url:
                icon = "🔗"; label = "Lien"
            case .code:
                icon = "{ }"; label = "Code"
            case .text:
                switch clip.detectedSubtype {
                case .email:    icon = "✉️";  label = "Email"
                case .phone:    icon = "📞"; label = "Téléphone"
                case .date:     icon = "📅"; label = "Date"
                case .colorHex: icon = "🎨"; label = "Couleur"
                case .address:  icon = "📍"; label = "Adresse"
                case nil:       icon = "📄"; label = "Texte"
                }
            case .image:
                icon = "🖼"; label = "Image"
            }
            return "\(icon) \(label)  ·  \(fmt.string(from: clip.createdAt))\n\(clip.textValue)"
        }.joined(separator: "\n\n────────\n\n")
    }

    private func copyClip(_ clip: ClipItem) {
        clipboardStore.isInternalCopy = true
        if clip.type == .image, let uiImage = UIImage(data: clip.contentData) {
            UIPasteboard.general.image = uiImage
        } else {
            UIPasteboard.general.string = clip.textValue
        }
    }

    private func exportSelectedAsPDF() {
        isExportingPDF = true
        Task { @MainActor in
            await Task.yield()
            let data = await PDFExporter.generate(from: selectedClips)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("ClipKeep-Selection.pdf")
            try? data.write(to: url)
            withAnimation { isExportingPDF = false }
            await Task.yield()
            ActivityShareSheet.present(items: [url]) { completed in
                if completed {
                    self.selectedIDs.removeAll()
                    self.isSelecting = false
                }
            }
        }
 }

    private func deleteSelected() {
        withAnimation {
            for clip in selectedClips { modelContext.delete(clip) }
            try? modelContext.save()
            selectedIDs.removeAll()
            isSelecting = false
        }
    }

    // MARK: - Empty states

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("Aucun élément sauvegardé")
                .font(.title3)
                .foregroundColor(.gray)
            Text("Copiez du texte, une image ou un lien pour les voir ici")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("Aucun résultat")
                .font(.title3)
                .foregroundColor(.gray)
            Text("Essayez un autre terme ou filtre")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - SearchField

private struct SearchField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                TextField("Rechercher dans l'historique…", text: $text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focused)
                if !text.isEmpty {
                    Button { text = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            if focused || !text.isEmpty {
                Button("Annuler") {
                    text = ""
                    focused = false
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.2), value: focused)
    }
}

// MARK: - FilterBar

private struct FilterBar: View {
    @Binding var selected: ClipType?

    private let filters: [(label: String, icon: String, type: ClipType?)] = [
        ("Tout",   "tray.full",                               nil),
        ("Texte",  "doc.text",                                .text),
        ("Code",   "chevron.left.forwardslash.chevron.right", .code),
        ("Images", "photo",                                   .image),
        ("Liens",  "link",                                    .url)
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.label) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selected = filter.type
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: filter.icon)
                                .font(.caption)
                            Text(filter.label)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(selected == filter.type ? Color.accentColor : Color(.systemGray5))
                        .foregroundColor(selected == filter.type ? .white : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - CaptureToast

private struct CaptureToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(message)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }
}

#Preview {
    ClipListView()
        .modelContainer(for: ClipItem.self, inMemory: true)
}
