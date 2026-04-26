//
//  SettingsView.swift
//  ClipKeep
//
//  Created by tamtam-8 on 6/4/2026.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Query var clips: [ClipItem]
    @State private var showConfirmation = false
    @AppStorage("retentionDays") private var retentionDays: Int = 0
    @AppStorage("maxItems") private var maxItems: Int = 0

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Informations")) {
                    HStack {
                        Text("Éléments sauvegardés")
                        Spacer()
                        Text("\(clips.count)")
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Text("Éléments épinglés")
                        Spacer()
                        Text("\(clips.filter(\.isPinned).count)")
                            .fontWeight(.semibold)
                    }
                }

                Section(header: Text("Stockage")) {
                    Picker("Durée de conservation", selection: $retentionDays) {
                        Text("Illimité").tag(0)
                        Text("7 jours").tag(7)
                        Text("30 jours").tag(30)
                    }
                    Picker("Limite d'éléments", selection: $maxItems) {
                        Text("Illimité").tag(0)
                        Text("50 éléments").tag(50)
                        Text("100 éléments").tag(100)
                    }
                }
                .onChange(of: retentionDays) { _, _ in applyCleanup() }
                .onChange(of: maxItems) { _, _ in applyCleanup() }

                Section(header: Text("Actions")) {
                    Button(role: .destructive) {
                        showConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Effacer tout l'historique")
                        }
                    }
                }

                Section(header: Text("À propos")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Paramètres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .alert("Confirmer la suppression", isPresented: $showConfirmation) {
                Button("Annuler", role: .cancel) { }
                Button("Effacer", role: .destructive) {
                    clearAll()
                }
            } message: {
                Text("Cette action supprimera tous les éléments sauvegardés. Cette opération ne peut pas être annulée.")
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
}

#Preview {
    SettingsView()
        .modelContainer(for: ClipItem.self, inMemory: true)
}
