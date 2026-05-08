import SwiftUI

struct ClipKeyboardRow: View {
    let clip: SharedClipItem

    private var icon: String {
        switch clip.subtype {
        case "email":    return "envelope"
        case "phone":    return "phone"
        case "date":     return "calendar"
        case "colorHex": return "paintpalette"
        case "address":  return "map"
        default:
            switch clip.type {
            case "url":  return "link"
            case "code": return "chevron.left.forwardslash.chevron.right"
            default:     return "doc.text"
            }
        }
    }

    private var iconColor: Color {
        switch clip.subtype {
        case "email":    return .blue
        case "phone":    return .green
        case "date":     return .purple
        case "colorHex": return .pink
        case "address":  return .red
        default:
            switch clip.type {
            case "url":  return .blue
            case "code": return .orange
            default:     return .secondary
            }
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(clip.text.count > 60
                     ? String(clip.text.prefix(60)) + "…"
                     : clip.text)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Text(clip.createdAt.formatted())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if clip.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }
}
