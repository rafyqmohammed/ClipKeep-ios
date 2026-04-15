//
//  ClipDetailView.swift
//  ClipKeep
//
//  Created by tamtam-8 on 6/4/2026.
//

import SwiftUI

struct ClipDetailView: View {
    @Environment(ClipboardStore.self) var clipboardStore
    @Environment(\.dismiss) var dismiss
    @State private var copied = false

    let clip: ClipItem

    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Display content based on type
                VStack(alignment: .leading, spacing: 12) {
                    Text("Contenu")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView {
                        if clip.type == .image, let uiImage = UIImage(data: clip.contentData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(12)
                                .padding()
                        } else {
                            Text(clip.textValue)
                                .textSelection(.enabled)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                
                // Info section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Type:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(clip.type.rawValue.capitalized)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Crée le:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(clip.createdAt.formatted(date: .abbreviated, time: .standard))
                            .fontWeight(.semibold)
                    }
                    
                    if clip.type != .image {
                        HStack {
                            Text("Taille:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(clip.contentData.count) bytes")
                                .fontWeight(.semibold)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
                .padding()
                
                // Copy button
                Button(action: copyToClipboard) {
                    HStack {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copié!" : "Copier")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(copied)
                .padding()
            }
            .navigationTitle("Détails")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func copyToClipboard() {
        clipboardStore.isInternalCopy = true

        if clip.type == .image, let uiImage = UIImage(data: clip.contentData) {
            // Copie l'image dans le presse-papier
            UIPasteboard.general.image = uiImage
        } else {
            // Copie le texte / URL
            UIPasteboard.general.string = clip.textValue
        }

        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }
}

#Preview {
    let item = ClipItem(contentData: "Sample text".data(using: .utf8)!, type: .text)
    ClipDetailView(clip: item)
}
