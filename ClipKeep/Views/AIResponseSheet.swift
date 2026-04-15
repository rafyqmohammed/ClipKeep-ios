//
//  AIResponseSheet.swift
//  ClipKeep
//
//  Created by tamtam-8 on 12/4/2026.
//

import SwiftUI

struct AIResponseSheet: View {
    // 1. État pour contrôler l'affichage du sheet
    @State private var showAISheet = false
    
    var body: some View {
        VStack {
            Button("Générer avec l'IA") {
                // 2. Action pour afficher le sheet
                showAISheet.toggle()
//                showAISheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        // 3. Modifier sheet
        .sheet(isPresented: $showAISheet) {
            AIModalView()
        }
    }
}

// La vue qui s'affiche dans le sheet
struct AIModalView: View {
    // 4. Permet de fermer le sheet depuis l'intérieur
    @Environment(\.dismiss) var dismissj
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Suggestion IA")
                    .font(.title)
                
                Text("Voici le texte généré par l'intelligence artificielle...")
                    .padding()
                
                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Fermer") {
                dismissj() // Ferme le sheet
            })
        }
    }
}

#Preview {
    AIResponseSheet()
}
