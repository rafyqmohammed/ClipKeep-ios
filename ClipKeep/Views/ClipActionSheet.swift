//
//  ClipActionSheet.swift
//  ClipKeep
//

import SwiftUI

struct ClipActionSheet: View {
    let clip: ClipItem
    var onCopy: () -> Void
    var onOpen: () -> Void
    var onShare: () -> Void
    var onPin: () -> Void
    var onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Preview card
            previewCard
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

            Divider()

            // Actions
            VStack(spacing: 0) {
                actionRow(loc("action.copy"), icon: "doc.on.doc", color: .accentColor) {
                    dismiss()
                    onCopy()
                }
                Divider().padding(.leading, 60)
                actionRow(loc("action.open"), icon: "arrow.right.circle", color: .primary) {
                    dismiss()
                    onOpen()
                }
                Divider().padding(.leading, 60)
                actionRow(loc("action.share"), icon: "square.and.arrow.up", color: .primary) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onShare() }
                }
                Divider().padding(.leading, 60)
                actionRow(
                    clip.isPinned ? loc("action.unpin") : loc("action.pin"),
                    icon: clip.isPinned ? "pin.slash" : "pin",
                    color: .orange
                ) {
                    dismiss()
                    onPin()
                }
                Divider().padding(.leading, 60)
                actionRow(loc("action.delete"), icon: "trash", color: .red) {
                    dismiss()
                    onDelete()
                }
            }

            Spacer()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
    }

    // MARK: - Preview card

    @ViewBuilder
    private var previewCard: some View {
        HStack(spacing: 14) {
            typeIconView
            VStack(alignment: .leading, spacing: 4) {
                Text(typeLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if clip.type == .image {
                    Text(loc("item.image"))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                } else {
                    Text(clip.textValue.prefix(100))
                        .font(.subheadline)
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                }
                Text(clip.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var typeIconView: some View {
        if clip.type == .image, let uiImage = UIImage(data: clip.contentData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Image(systemName: typeIcon)
                .font(.title2)
                .foregroundStyle(typeColor)
                .frame(width: 52, height: 52)
                .background(typeColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Action row

    private func actionRow(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.body.weight(.medium))
                    .foregroundStyle(color)
                    .frame(width: 24)
                    .padding(.leading, 20)
                Text(title)
                    .font(.body)
                    .foregroundStyle(color == .red ? Color.red : Color.primary)
                Spacer()
            }
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var typeIcon: String {
        switch clip.type {
        case .text:  return clip.detectedSubtype?.icon ?? "doc.text"
        case .url:   return "link"
        case .code:  return "chevron.left.forwardslash.chevron.right"
        case .image: return "photo"
        }
    }

    private var typeColor: Color {
        switch clip.type {
        case .text:  return .blue
        case .url:   return .orange
        case .code:  return .purple
        case .image: return .green
        }
    }

    private var typeLabel: String {
        switch clip.type {
        case .text:  return clip.detectedSubtype?.label ?? loc("type.text")
        case .url:   return loc("type.link")
        case .code:  return loc("type.code")
        case .image: return loc("type.image")
        }
    }
}
