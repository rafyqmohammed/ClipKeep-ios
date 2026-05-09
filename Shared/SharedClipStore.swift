import Foundation

enum SharedClipStore {
    private static let appGroupID        = "group.com.rafyq.ClipKeep"
    private static let clipsFileName     = "clips.json"
    private static let pendingFileName   = "pending_pins.json"

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private static var clipsFileURL: URL? {
        containerURL?.appendingPathComponent(clipsFileName)
    }

    private static var pendingFileURL: URL? {
        containerURL?.appendingPathComponent(pendingFileName)
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

    // MARK: — App principale → clavier (fichier)

    static func sync(from items: [SharedClipItem]) {
        guard let url = clipsFileURL,
              let data = try? encoder.encode(items) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load() -> [SharedClipItem] {
        guard let url = clipsFileURL,
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([SharedClipItem].self, from: data)) ?? []
    }

    // MARK: — Clavier → app principale (fichier, cross-process fiable)

    static func recordPending(id: UUID) {
        var pending = loadPending()
        let idStr = id.uuidString
        if let i = pending.firstIndex(of: idStr) { pending.remove(at: i) }
        else { pending.append(idStr) }
        savePending(pending)
    }

    static func consumePendingPinToggles() -> [UUID] {
        let pending = loadPending()
        guard !pending.isEmpty else { return [] }
        deletePending()
        return pending.compactMap { UUID(uuidString: $0) }
    }

    private static func loadPending() -> [String] {
        guard let url = pendingFileURL,
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([String].self, from: data)) ?? []
    }

    private static func savePending(_ ids: [String]) {
        guard let url = pendingFileURL,
              let data = try? encoder.encode(ids) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func deletePending() {
        guard let url = pendingFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
