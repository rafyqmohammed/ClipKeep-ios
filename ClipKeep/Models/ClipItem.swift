//
//  ClipItem.swift
//  ClipKeep
//
//  Created by tamtam-8 on 6/4/2026.
//

import Foundation
import SwiftData

enum ClipType: String, Codable {
    case text, image, url, code
}

enum ClipSubtype: String {
    case email, phone, date, colorHex, address

    var icon: String {
        switch self {
        case .email:    return "envelope"
        case .phone:    return "phone"
        case .date:     return "calendar"
        case .colorHex: return "paintpalette"
        case .address:  return "map"
        }
    }

    var label: String {
        switch self {
        case .email:    return loc("type.email")
        case .phone:    return loc("type.phone")
        case .date:     return loc("type.date")
        case .colorHex: return loc("type.color")
        case .address:  return loc("type.address")
        }
    }
}

@Model
final class ClipItem {
    var id: UUID
    var contentData: Data    // Le contenu brut (texte converti en Data ou Image)
    var type: ClipType       // Pour savoir comment l'afficher
    var createdAt: Date
    var isPinned: Bool

    init(contentData: Data, type: ClipType) {
        self.id = UUID()
        self.contentData = contentData
        self.type = type
        self.createdAt = Date()
        self.isPinned = false
    }
    
    var textValue: String {
        String(data: contentData, encoding: .utf8) ?? ""
    }

    var detectedSubtype: ClipSubtype? {
        guard type == .text else { return nil }
        let text = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // Hex color: #RGB, #RRGGBB, #RRGGBBAA
        if text.range(of: #"^#[0-9A-Fa-f]{3}([0-9A-Fa-f]{3}([0-9A-Fa-f]{2})?)?$"#,
                      options: .regularExpression) != nil {
            return .colorHex
        }

        // NSDataDetector for phone, link (email), date, address
        let detectorTypes: NSTextCheckingTypes =
            NSTextCheckingResult.CheckingType.phoneNumber.rawValue |
            NSTextCheckingResult.CheckingType.link.rawValue |
            NSTextCheckingResult.CheckingType.date.rawValue |
            NSTextCheckingResult.CheckingType.address.rawValue
        guard let detector = try? NSDataDetector(types: detectorTypes) else { return nil }
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: nsRange)

        for match in matches {
            switch match.resultType {
            case .phoneNumber:
                // Reject false positives: match must cover ≥ 70% of the text
                // and contain at least 7 digits (minimum for a real phone number)
                let coverage = Double(match.range.length) / Double(text.utf16.count)
                let digits   = (match.phoneNumber ?? "").filter(\.isNumber)
                if coverage >= 0.7 && digits.count >= 7 { return .phone }
            case .link:
                if match.url?.scheme == "mailto" { return .email }
            case .date:        return .date
            case .address:     return .address
            default: break
            }
        }

        // Email regex fallback (bare address without mailto:)
        if text.range(of: #"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$"#,
                      options: [.regularExpression, .caseInsensitive]) != nil {
            return .email
        }

        return nil
    }
}
