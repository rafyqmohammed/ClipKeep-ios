import Foundation

enum SharedClipStore {
    private static let appGroupID = "group.com.rafyq.ClipKeep"
    private static let fileName  = "clips.json"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // Appelé depuis ClipKeep (app principale) après chaque modification
    static func sync(from items: [ClipItem]) {
        let shared = items
            .filter { $0.type != .image }
            .sorted {
                if $0.isPinned != $1.isPinned { return $0.isPinned }
                return $0.createdAt > $1.createdAt
            }
            .map {
                SharedClipItem(
                    id: $0.id,
                    text: $0.textValue,
                    type: $0.type.rawValue,
                    createdAt: $0.createdAt,
                    isPinned: $0.isPinned
                )
            }

        guard let url = fileURL,
              let data = try? encoder.encode(shared) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // Appelé depuis ClipKeepKeyboard (clavier) pour lire les clips
    static func load() -> [SharedClipItem] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([SharedClipItem].self, from: data)) ?? []
    }
}
