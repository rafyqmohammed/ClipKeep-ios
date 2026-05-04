//
//  SpotlightIndexer.swift
//  ClipKeep
//

import CoreSpotlight

enum SpotlightIndexer {
    private static let domain = "com.clipkeep.clip"

    static func index(_ clip: ClipItem) {
        guard clip.type != .image else { return }
        let item = makeItem(clip)
        CSSearchableIndex.default().indexSearchableItems([item]) { _ in }
    }

    static func deindex(id: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [id.uuidString]) { _ in }
    }

    static func deindexAll() {
        CSSearchableIndex.default().deleteAllSearchableItems { _ in }
    }

    static func reindexAll(_ clips: [ClipItem]) {
        let items = clips.compactMap { clip -> CSSearchableItem? in
            guard clip.type != .image else { return nil }
            return makeItem(clip)
        }
        CSSearchableIndex.default().deleteAllSearchableItems { _ in
            CSSearchableIndex.default().indexSearchableItems(items) { _ in }
        }
    }

    private static func makeItem(_ clip: ClipItem) -> CSSearchableItem {
        let attr = CSSearchableItemAttributeSet(contentType: .text)
        attr.title = clipTitle(clip)
        attr.contentDescription = clip.textValue
        attr.contentCreationDate = clip.createdAt
        attr.keywords = [clip.type.rawValue]
        let item = CSSearchableItem(
            uniqueIdentifier: clip.id.uuidString,
            domainIdentifier: domain,
            attributeSet: attr
        )
        item.expirationDate = .distantFuture
        return item
    }

    private static func clipTitle(_ clip: ClipItem) -> String {
        switch clip.type {
        case .url:   return clip.textValue
        case .code:  return "Code — " + String(clip.textValue.prefix(50))
        case .text:  return String(clip.textValue.prefix(60))
        case .image: return "Image"
        }
    }
}
