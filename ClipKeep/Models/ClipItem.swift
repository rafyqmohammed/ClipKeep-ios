//
//  ClipItem.swift
//  ClipKeep
//
//  Created by tamtam-8 on 6/4/2026.
//

import Foundation
import SwiftData

enum ClipType: String, Codable {
    case text, image, url
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
    
    // Helper pour récupérer le texte facilement
    var textValue: String {
        String(data: contentData, encoding: .utf8) ?? ""
    }
}
