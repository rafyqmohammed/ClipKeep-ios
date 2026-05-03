//
//  OnboardingView.swift
//  ClipKeep
//

import SwiftUI

struct OnboardingView: View {
    var onDone: () -> Void
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            page1.tag(0)
            page2.tag(1)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .ignoresSafeArea()
    }

    // MARK: - Page 1 : capture automatique

    private var page1: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
                .padding(.bottom, 36)

            Text("Capture automatique")
                .font(.title.bold())
                .padding(.bottom, 12)

            Text("ClipKeep enregistre tout ce que tu copies — texte, liens, images et code — sans aucune action de ta part.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button {
                withAnimation { page = 1 }
            } label: {
                Text("Suivant")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }

    // MARK: - Page 2 : permission

    private var page2: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "hand.raised.fill")
                .font(.system(size: 80))
                .foregroundStyle(.orange.gradient)
                .padding(.bottom, 36)

            Text("Permission requise")
                .font(.title.bold())
                .padding(.bottom, 12)

            Text("iOS demande l'autorisation pour que ClipKeep puisse lire ton presse-papiers. Sans elle, rien ne sera capturé.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 16)

            Label("Appuie sur \"Autoriser\" quand iOS le demande.", systemImage: "checkmark.circle")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.orange)
                .padding(.horizontal, 40)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                onDone()
            } label: {
                Text("Commencer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }
}

#Preview {
    OnboardingView { }
}
