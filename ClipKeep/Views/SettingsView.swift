//
//  SettingsView.swift
//  ClipKeep
//
//  Created by tamtam-8 on 6/4/2026.
//

import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Query(sort: \ClipItem.createdAt, order: .reverse) var clips: [ClipItem]
    @State private var showConfirmation = false
    @State private var isGeneratingPDF = false
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

                Section(header: Text("Export")) {
                    Button {
                        exportPDF()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.doc")
                            Text("Exporter en PDF")
                        }
                    }
                    .disabled(clips.isEmpty || isGeneratingPDF)
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
            .overlay {
                if isGeneratingPDF {
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
}
