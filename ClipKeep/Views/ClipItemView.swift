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
            } else if item.type == .text, let color = parsedHexColor {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
            } else {
                Image(systemName: rowIcon)
                    .font(.body.weight(.medium))
                    .foregroundStyle(rowIconColor)
                    .frame(width: 40, height: 40)
                    .background(rowIconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
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
                    Text(String(format: loc("item.lines"), lineCount))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(item.type == .image ? loc("item.image") : item.textValue)
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
                    typeBadge
                }
            }
        }
    }

    // MARK: - Helpers

    private var parsedHexColor: Color? {
        let raw = item.textValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard raw.hasPrefix("#") else { return nil }
        let hex = String(raw.dropFirst())

        let rgb6: String
        switch hex.count {
        case 3:  rgb6 = hex.map { String(repeating: String($0), count: 2) }.joined()
        case 6:  rgb6 = hex
        case 8:  rgb6 = String(hex.prefix(6))
        default: return nil
        }

        guard let value = UInt32(rgb6, radix: 16) else { return nil }
        return Color(
            red:   Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8)  & 0xFF) / 255,
            blue:  Double(value         & 0xFF) / 255
        )
    }

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

    private var typeBadge: some View {
        let label: String
        let icon: String
        let color: Color

        if let sub = item.detectedSubtype {
            switch sub {
            case .email:    label = loc("type.email");   icon = sub.icon; color = .blue
            case .phone:    label = loc("type.phone");   icon = sub.icon; color = .green
            case .date:     label = loc("type.date");    icon = sub.icon; color = .orange
            case .colorHex: label = loc("type.color");   icon = sub.icon; color = .pink
            case .address:  label = loc("type.address"); icon = sub.icon; color = .teal
            }
        } else {
            switch item.type {
            case .code:  label = loc("type.code");  icon = "chevron.left.forwardslash.chevron.right"; color = .purple
            case .url:   label = loc("type.link");  icon = "link";     color = .orange
            case .image: label = loc("type.image"); icon = "photo";    color = .green
            case .text:  label = loc("type.text");  icon = "doc.text"; color = .blue
            }
        }

        return HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(label)
                .font(.system(size: 9))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(color.opacity(0.12))
        .foregroundColor(color)
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
