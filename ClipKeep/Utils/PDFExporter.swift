//
//  PDFExporter.swift
//  ClipKeep
//

import UIKit

// MARK: - Thread-safe snapshot (no NSDataDetector)

struct PDFClipData: Sendable {
    let typeRaw:   String
    let textValue: String
    let imageData: Data?
    let createdAt: Date
    let isPinned:  Bool
}

extension ClipItem {
    var pdfSnapshot: PDFClipData {
        PDFClipData(
            typeRaw:   type.rawValue,
            textValue: textValue,
            imageData: type == .image ? contentData : nil,
            createdAt: createdAt,
            isPinned:  isPinned
        )
    }
}

// MARK: - Generator

struct PDFExporter {

    /// Extracts snapshots on the main thread (fast), then renders on a background thread.
    @MainActor
    static func generate(from clips: [ClipItem]) async -> Data {
        let snapshots = clips.map(\.pdfSnapshot)
        return await Task.detached(priority: .userInitiated) {
            buildPDF(from: snapshots)
        }.value
    }

    // MARK: - Subtype detection (background thread)

    private static func detectSubtype(_ text: String) -> ClipSubtype? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }

        if t.range(of: #"^#[0-9A-Fa-f]{3}([0-9A-Fa-f]{3}([0-9A-Fa-f]{2})?)?$"#,
                   options: .regularExpression) != nil { return .colorHex }

        let types: NSTextCheckingTypes =
            NSTextCheckingResult.CheckingType.phoneNumber.rawValue |
            NSTextCheckingResult.CheckingType.link.rawValue |
            NSTextCheckingResult.CheckingType.date.rawValue |
            NSTextCheckingResult.CheckingType.address.rawValue
        guard let detector = try? NSDataDetector(types: types) else { return nil }
        let range   = NSRange(t.startIndex..., in: t)
        let matches = detector.matches(in: t, options: [], range: range)
        for match in matches {
            switch match.resultType {
            case .phoneNumber:
                let cov    = Double(match.range.length) / Double(t.utf16.count)
                let digits = (match.phoneNumber ?? "").filter(\.isNumber)
                if cov >= 0.7 && digits.count >= 7 { return .phone }
            case .link:
                if match.url?.scheme == "mailto" { return .email }
            case .date:    return .date
            case .address: return .address
            default: break
            }
        }
        if t.range(of: #"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$"#,
                   options: [.regularExpression, .caseInsensitive]) != nil { return .email }
        return nil
    }

    // MARK: - Display helpers (background thread)

    private static func icon(_ type: ClipType, _ sub: ClipSubtype?) -> String {
        switch type {
        case .image: return "🖼"
        case .url:   return "🔗"
        case .code:  return "{ }"
        case .text:
            switch sub {
            case .email:    return "✉️"
            case .phone:    return "📞"
            case .date:     return "📅"
            case .colorHex: return "🎨"
            case .address:  return "📍"
            case nil:       return "📄"
            }
        }
    }

    private static func label(_ type: ClipType, _ sub: ClipSubtype?) -> String {
        switch type {
        case .image: return "Image"
        case .url:   return "Lien"
        case .code:  return "Code"
        case .text:  return sub?.label ?? "Texte"
        }
    }

    private static func accentColor(_ type: ClipType, _ sub: ClipSubtype?) -> UIColor {
        switch type {
        case .image: return .systemPurple
        case .url:   return UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1)
        case .code:  return UIColor(red: 0.55, green: 0.2,  blue: 0.9,  alpha: 1)
        case .text:
            switch sub {
            case .email:    return UIColor(red: 0.0,  green: 0.48, blue: 1.0,  alpha: 1)
            case .phone:    return UIColor(red: 0.2,  green: 0.67, blue: 0.25, alpha: 1)
            case .date:     return UIColor(red: 1.0,  green: 0.58, blue: 0.0,  alpha: 1)
            case .colorHex: return UIColor(red: 1.0,  green: 0.18, blue: 0.53, alpha: 1)
            case .address:  return UIColor(red: 0.18, green: 0.68, blue: 0.69, alpha: 1)
            case nil:       return UIColor(white: 0.4, alpha: 1)
            }
        }
    }

    private static func contentFont(_ type: ClipType) -> UIFont {
        type == .code
            ? .monospacedSystemFont(ofSize: 10, weight: .regular)
            : .systemFont(ofSize: 11)
    }

    // MARK: - PDF render (background thread)

    private static func buildPDF(from clips: [PDFClipData]) -> Data {
        let pageW:   CGFloat = 595
        let pageH:   CGFloat = 842
        let mg:      CGFloat = 36
        let cw               = pageW - mg * 2
        let cardR:   CGFloat = 7
        let cardGap: CGFloat = 10
        let hdrH:    CGFloat = 34
        let pad:     CGFloat = 12

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH)
        )

        return renderer.pdfData { ctx in
            var y: CGFloat = mg

            func newPage() { ctx.beginPage(); y = mg }
            func spaceLeft() -> CGFloat { pageH - mg - y }

            func measure(_ s: String, font f: UIFont, width w: CGFloat) -> CGFloat {
                NSAttributedString(string: s, attributes: [.font: f])
                    .boundingRect(with: CGSize(width: w, height: .greatestFiniteMagnitude),
                                  options: [.usesLineFragmentOrigin, .usesFontLeading],
                                  context: nil)
                    .height.rounded(.up)
            }

            func put(_ s: String, font f: UIFont, color c: UIColor = .black,
                     x: CGFloat, at startY: CGFloat, width w: CGFloat, height h: CGFloat) {
                NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: c])
                    .draw(in: CGRect(x: x, y: startY, width: w, height: h))
            }

            @discardableResult
            func inline(_ s: String, font f: UIFont, color c: UIColor = .black,
                        x: CGFloat = mg, width w: CGFloat = cw, gap: CGFloat = 0) -> CGFloat {
                let h = measure(s, font: f, width: w)
                put(s, font: f, color: c, x: x, at: y, width: w, height: h)
                y += h + gap
                return h
            }

            func rule(atY ry: CGFloat, from x1: CGFloat, to x2: CGFloat,
                      color: UIColor = UIColor(white: 0.82, alpha: 1), lw: CGFloat = 0.5) {
                let p = UIBezierPath()
                p.move(to: CGPoint(x: x1, y: ry))
                p.addLine(to: CGPoint(x: x2, y: ry))
                color.setStroke(); p.lineWidth = lw; p.stroke()
            }

            let fmt = DateFormatter()
            fmt.dateStyle = .long; fmt.timeStyle = .short
            fmt.locale = Locale(identifier: "fr_FR")

            // ── cover ────────────────────────────────────────────────────
            newPage()
            UIColor(red: 0, green: 0.48, blue: 1, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: mg, y: y, width: cw, height: 5),
                         cornerRadius: 2.5).fill()
            y += 14

            inline("ClipKeep", font: .boldSystemFont(ofSize: 32), gap: 4)
            inline("Historique du presse-papiers",
                   font: .systemFont(ofSize: 15), color: .systemGray, gap: 16)
            rule(atY: y, from: mg, to: mg + cw, color: UIColor(white: 0.85, alpha: 1), lw: 1)
            y += 14

            let meta = UIFont.systemFont(ofSize: 11)
            inline("📅  Exporté le  \(fmt.string(from: Date()))",
                   font: meta, color: .systemGray, gap: 6)
            inline("📋  \(clips.count) élément(s)   •   📌  \(clips.filter(\.isPinned).count) épinglé(s)",
                   font: meta, color: .systemGray, gap: 24)
            rule(atY: y, from: mg, to: mg + cw, color: UIColor(white: 0.85, alpha: 1), lw: 1)
            y += 20

            // ── cards ─────────────────────────────────────────────────────
            let contentMaxW = cw - pad * 2

            for (i, clip) in clips.enumerated() {
                let clipType = ClipType(rawValue: clip.typeRaw) ?? .text
                let subtype  = clipType == .text ? detectSubtype(clip.textValue) : nil
                let accent   = accentColor(clipType, subtype)
                let cFont    = contentFont(clipType)

                let body: String = {
                    let t = clip.textValue
                    return t.count > 500 ? String(t.prefix(500)) + "…" : t
                }()

                let contentH: CGFloat
                if let img = clip.imageData.flatMap({ UIImage(data: $0) }) {
                    let s = min(contentMaxW / img.size.width, 220 / img.size.height, 1)
                    contentH = img.size.height * s
                } else {
                    contentH = measure(body, font: cFont, width: contentMaxW)
                }

                let cardH = hdrH + pad + contentH + pad
                if spaceLeft() < cardH { newPage() }

                let cardBox = CGRect(x: mg, y: y, width: cw, height: cardH)

                UIColor(white: 0, alpha: 0.05).setFill()
                UIBezierPath(roundedRect: cardBox.offsetBy(dx: 1.5, dy: 1.5),
                             cornerRadius: cardR).fill()
                UIColor.white.setFill()
                UIBezierPath(roundedRect: cardBox, cornerRadius: cardR).fill()
                let border = UIBezierPath(roundedRect: cardBox, cornerRadius: cardR)
                accent.withAlphaComponent(0.28).setStroke()
                border.lineWidth = 0.75; border.stroke()

                accent.setFill()
                UIBezierPath(
                    roundedRect: CGRect(x: mg, y: y, width: 4, height: cardH),
                    byRoundingCorners: [.topLeft, .bottomLeft],
                    cornerRadii: CGSize(width: cardR, height: cardR)
                ).fill()

                accent.withAlphaComponent(0.07).setFill()
                UIBezierPath(
                    roundedRect: CGRect(x: mg, y: y, width: cw, height: hdrH),
                    byRoundingCorners: [.topLeft, .topRight],
                    cornerRadii: CGSize(width: cardR, height: cardR)
                ).fill()
                rule(atY: y + hdrH, from: mg + 4, to: mg + cw,
                     color: accent.withAlphaComponent(0.18))

                let hFont  = UIFont.systemFont(ofSize: 10, weight: .semibold)
                let hLabel = "\(icon(clipType, subtype))  \(label(clipType, subtype))  •  \(fmt.string(from: clip.createdAt))\(clip.isPinned ? "  📌" : "")"
                let hH     = measure(hLabel, font: hFont, width: cw - 52)
                put(hLabel, font: hFont, color: accent,
                    x: mg + 12, at: y + (hdrH - hH) / 2, width: cw - 52, height: hH)

                let bFont  = UIFont.monospacedSystemFont(ofSize: 9, weight: .medium)
                let bLabel = "#\(i + 1)"
                let bH     = measure(bLabel, font: bFont, width: 38)
                put(bLabel, font: bFont, color: .systemGray,
                    x: mg + cw - 40, at: y + (hdrH - bH) / 2, width: 38, height: bH)

                let cx = mg + pad
                let cy = y + hdrH + pad

                if let img = clip.imageData.flatMap({ UIImage(data: $0) }) {
                    let s = min(contentMaxW / img.size.width, 220 / img.size.height, 1)
                    img.draw(in: CGRect(x: cx, y: cy,
                                        width: img.size.width * s,
                                        height: img.size.height * s))
                } else if clipType == .url {
                    NSAttributedString(string: body, attributes: [
                        .font: cFont,
                        .foregroundColor: UIColor(red: 0, green: 0.48, blue: 1, alpha: 1),
                        .underlineStyle: NSUnderlineStyle.single.rawValue
                    ]).draw(in: CGRect(x: cx, y: cy, width: contentMaxW, height: contentH))
                } else {
                    NSAttributedString(string: body, attributes: [
                        .font: cFont,
                        .foregroundColor: UIColor.black
                    ]).draw(in: CGRect(x: cx, y: cy, width: contentMaxW, height: contentH))
                }

                y += cardH + cardGap
            }

            // ── footer ───────────────────────────────────────────────────
            let footerY = pageH - 22
            rule(atY: footerY - 6, from: mg, to: mg + cw, color: UIColor(white: 0.88, alpha: 1))
            NSAttributedString(
                string: "ClipKeep  •  \(clips.count) élément(s)  •  \(fmt.string(from: Date()))",
                attributes: [.font: UIFont.systemFont(ofSize: 8),
                             .foregroundColor: UIColor.lightGray]
            ).draw(at: CGPoint(x: mg, y: footerY))
        }
    }
}
