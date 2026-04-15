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
    
    var body: some View {
        NavigationStack {
            ZStack {
                if clips.isEmpty {
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
                } else {
                    List {
                        ForEach(clips) { clip in
                            NavigationLink(destination: ClipDetailView(clip: clip)) {
                                ClipItemView(item: clip)
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
}

#Preview {
    ClipListView()
        .modelContainer(for: ClipItem.self, inMemory: true)
}
