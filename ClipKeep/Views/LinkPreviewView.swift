//
//  LinkPreviewView.swift
//  ClipKeep
//

import SwiftUI
import LinkPresentation

struct LinkPreviewView: View {
    let url: URL
    @State private var metadata: LPLinkMetadata?
    @State private var provider: LPMetadataProvider?

    var body: some View {
        Group {
            if let metadata {
                LPLinkViewRepresentable(metadata: metadata)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .clipped()
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "globe")
                        .font(.title3)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(url.host ?? url.absoluteString)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(url.absoluteString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .onAppear { fetchMetadata() }
        .onDisappear { provider?.cancel(); provider = nil }
    }

    private func fetchMetadata() {
        guard provider == nil, metadata == nil else { return }
        let lp = LPMetadataProvider()
        provider = lp
        lp.startFetchingMetadata(for: url) { fetched, _ in
            DispatchQueue.main.async {
                metadata = fetched
                provider = nil
            }
        }
    }
}

private struct LPLinkViewRepresentable: UIViewRepresentable {
    let metadata: LPLinkMetadata

    func makeUIView(context: Context) -> LPLinkView {
        LPLinkView(metadata: metadata)
    }

    func updateUIView(_ uiView: LPLinkView, context: Context) {
        uiView.metadata = metadata
    }
}
