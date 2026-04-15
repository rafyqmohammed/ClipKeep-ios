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
                }
                
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
}

#Preview {
    SettingsView()
        .modelContainer(for: ClipItem.self, inMemory: true)
}
