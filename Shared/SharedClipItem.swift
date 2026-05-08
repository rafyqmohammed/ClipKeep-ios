import Foundation

struct SharedClipItem: Codable, Identifiable {
    let id: UUID
    let text: String
    let type: String           // "text" | "url" | "code"
    let subtype: String?       // "email" | "phone" | "date" | "colorHex" | "address"
    let createdAt: Date
    let isPinned: Bool
}
