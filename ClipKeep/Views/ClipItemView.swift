//
//  ClipItemView.swift
//  ClipKeep
//
//  Created by tamtam-8 on 6/4/2026.
//

import SwiftUI

struct ClipItemView: View {
    let item: ClipItem

    var body: some View {
        HStack(spacing: 12) {
            if item.type == .image, let uiImage = UIImage(data: item.contentData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
            } else {
                Image(systemName: rowIcon)
                    .foregroundColor(rowIconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                if item.type == .url, let host = URL(string: item.textValue)?.host {
                    Text(host)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(item.textValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if item.type == .code {
                    let firstLine = item.textValue
                        .components(separatedBy: "\n")
                        .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
                    let lineCount = item.textValue.components(separatedBy: "\n").count
                    Text(firstLine)
                        .font(.system(.subheadline, design: .monospaced))
                        .lineLimit(1)
                    Text("\(lineCount) lignes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(item.type == .image ? "Image enregistrée" : item.textValue)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Text(item.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    if let subtype = item.detectedSubtype {
                        subtypeBadge(subtype)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var rowIcon: String {
        switch item.type {
        case .image:  return "photo"
        case .url:    return "link"
        case .code:   return "chevron.left.forwardslash.chevron.right"
        case .text:   return item.detectedSubtype?.icon ?? "doc.text"
        }
    }

    private var rowIconColor: Color {
        switch item.type {
        case .image:  return .blue
        case .url:    return .blue
        case .code:   return .purple
        case .text:   return item.detectedSubtype.map { subtypeColor($0) } ?? .blue
        }
    }

    private func subtypeBadge(_ subtype: ClipSubtype) -> some View {
        HStack(spacing: 3) {
            Image(systemName: subtype.icon)
                .font(.system(size: 8))
            Text(subtype.label)
                .font(.system(size: 9))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(subtypeColor(subtype).opacity(0.12))
        .foregroundColor(subtypeColor(subtype))
        .cornerRadius(4)
    }

    private func subtypeColor(_ subtype: ClipSubtype) -> Color {
        switch subtype {
        case .email:    return .blue
        case .phone:    return .green
        case .date:     return .orange
        case .colorHex: return .pink
        case .address:  return .teal
        }
    }
}

#Preview {
    
}
