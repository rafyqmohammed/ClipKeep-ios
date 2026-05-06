import Foundation

struct SharedClipItem: Codable, Identifiable {
    let id: UUID
    let text: String
    let type: String      // "text" | "url" | "code"
    let createdAt: Date
    let isPinned: Bool
}
