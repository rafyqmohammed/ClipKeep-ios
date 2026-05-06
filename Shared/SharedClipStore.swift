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
    static func sync(from items: [SharedClipItem]) {
        guard let url = fileURL,
              let data = try? encoder.encode(items) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // Appelé depuis ClipKeepKeyboard (clavier) pour lire les clips
    static func load() -> [SharedClipItem] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([SharedClipItem].self, from: data)) ?? []
    }
}
