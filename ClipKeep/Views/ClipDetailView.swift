//
//  ClipDetailView.swift
//  ClipKeep
//
//  Created by tamtam-8 on 6/4/2026.
//

import SwiftUI

struct ClipDetailView: View {
    @Environment(ClipboardStore.self) var clipboardStore
    @State private var copied = false

    let clip: ClipItem

    var body: some View {
        VStack(spacing: 16) {

            // Content section
            VStack(alignment: .leading, spacing: 12) {
                Text(loc("detail.section.content"))
                    .font(.headline)
                    .padding(.horizontal)

                // Rich URL preview card
                if clip.type == .url, let url = URL(string: clip.textValue) {
                    LinkPreviewView(url: url)
                        .padding(.horizontal)
                }

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
                            .font(contentFont)
                            .foregroundColor(clip.type == .url ? .secondary : .primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(clip.type == .code
                                ? Color.purple.opacity(0.05)
                                : Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
                .frame(maxHeight: clip.type == .url ? 70 : .infinity)
            }

            // Info section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(loc("detail.type.label"))
                        .foregroundColor(.secondary)
                    Spacer()
                    if clip.type == .code {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.caption)
                            Text(loc("type.code"))
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    } else if let subtype = clip.detectedSubtype {
                        HStack(spacing: 4) {
                            Image(systemName: subtype.icon)
                                .font(.caption)
                            Text(subtype.label)
                        }
                        .fontWeight(.semibold)
                    } else {
                        Text(clip.type.rawValue.capitalized)
                            .fontWeight(.semibold)
                    }
                }
                HStack {
                    Text(loc("detail.date.label"))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(clip.createdAt.formatted(date: .abbreviated, time: .standard))
                        .fontWeight(.semibold)
                }
                if clip.type == .code {
                    HStack {
                        Text(loc("detail.lines.label"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(clip.textValue.components(separatedBy: "\n").count)")
                            .fontWeight(.semibold)
                    }
                }
                if clip.type != .image {
                    HStack {
                        Text(loc("detail.size.label"))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(clip.contentData.count) \(loc("detail.size.unit"))")
                            .fontWeight(.semibold)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal)

            // Action buttons
            HStack(spacing: 12) {
                Button(action: copyToClipboard) {
                    HStack {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? loc("action.copied") : loc("action.copy"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(copied)

                shareButton
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle(loc("title.details"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private var contentFont: Font {
        switch clip.type {
        case .url:  return .footnote
        case .code: return .system(.body, design: .monospaced)
        default:    return .body
        }
    }

    // MARK: - Share

    @ViewBuilder
    private var shareButton: some View {
        if clip.type == .url, let url = URL(string: clip.textValue) {
            ShareLink(item: url) { shareLabel }
        } else if clip.type == .image, let uiImage = UIImage(data: clip.contentData) {
            ShareLink(
                item: Image(uiImage: uiImage),
                preview: SharePreview(loc("type.image"), image: Image(uiImage: uiImage))
            ) { shareLabel }
        } else {
            ShareLink(item: clip.textValue) { shareLabel }
        }
    }

    private var shareLabel: some View {
        HStack {
            Image(systemName: "square.and.arrow.up")
            Text(loc("action.share"))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray5))
        .foregroundColor(.primary)
        .cornerRadius(8)
    }

    // MARK: - Copy

    private func copyToClipboard() {
        clipboardStore.isInternalCopy = true
        if clip.type == .image, let uiImage = UIImage(data: clip.contentData) {
            UIPasteboard.general.image = uiImage
        } else {
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
