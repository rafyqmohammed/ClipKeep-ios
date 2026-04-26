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
    @State private var showSettings = false
    @State private var searchText = ""
    @State private var filterType: ClipType? = nil

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
                                    NavigationLink(destination: ClipDetailView(clip: clip)) {
                                        ClipItemView(item: clip)
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            withAnimation {
                                                clip.isPinned.toggle()
                                                try? modelContext.save()
                                            }
                                        } label: {
                                            Label(
                                                clip.isPinned ? "Désépingler" : "Épingler",
                                                systemImage: clip.isPinned ? "pin.slash" : "pin"
                                            )
                                        }
                                        .tint(.orange)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                modelContext.delete(clip)
                                                try? modelContext.save()
                                            }
                                        } label: {
                                            Label("Supprimer", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .scrollDismissesKeyboard(.interactively)
                        }
                    }
                }
            }
            .navigationTitle("ClipKeep")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

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
                    Button {
                        text = ""
                    } label: {
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
        ("Tout",   "tray.full", nil),
        ("Texte",  "doc.text",  .text),
        ("Images", "photo",     .image),
        ("Liens",  "link",      .url)
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

#Preview {
    ClipListView()
        .modelContainer(for: ClipItem.self, inMemory: true)
}
