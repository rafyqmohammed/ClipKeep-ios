import Foundation

// Pont de communication entre ClipKeep (app principale) et ClipKeepKeyboard (extension clavier).
// Deux canaux distincts, chacun dans un seul sens :
//   1. ClipKeep → Clavier  : clips.json        (liste complète des clips)
//   2. Clavier  → ClipKeep : pending_pins.json  (UUIDs des clips dont l'épingle a changé)
//
// Les deux fichiers vivent dans le container App Group partagé.
// L'extension clavier doit avoir RequestsOpenAccess = true dans son Info.plist
// pour pouvoir écrire dans ce container (sinon les écritures échouent silencieusement).
enum SharedClipStore {
    private static let appGroupID      = "group.com.rafyq.ClipKeep"
    private static let clipsFileName   = "clips.json"
    private static let pendingFileName = "pending_pins.json"

    // URL racine du container App Group partagé entre l'app et l'extension.
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

    // MARK: — Canal 1 : ClipKeep → Clavier (clips.json)

    // Écrase clips.json avec la liste complète des clips actuels.
    // Appelé depuis ClipKeep après chaque modification (ajout, épingle, suppression).
    static func sync(from items: [SharedClipItem]) {
        guard let url = clipsFileURL,
              let data = try? encoder.encode(items) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // Lit clips.json et retourne la liste des clips.
    // Appelé depuis le clavier au lancement et toutes les secondes via le timer.
    static func load() -> [SharedClipItem] {
        guard let url = clipsFileURL,
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([SharedClipItem].self, from: data)) ?? []
    }

    // MARK: — Canal 2 : Clavier → ClipKeep (pending_pins.json)

    // Enregistre un toggle d'épingle depuis le clavier.
    // Si l'UUID est déjà dans la liste (double-tap), il est retiré (annulation).
    // Sinon il est ajouté. Résultat écrit dans pending_pins.json.
    static func recordPending(id: UUID) {
        var pending = loadPending()
        let idStr = id.uuidString
        if let i = pending.firstIndex(of: idStr) { pending.remove(at: i) }
        else { pending.append(idStr) }
        savePending(pending)
    }

    // Lit pending_pins.json, retourne les UUIDs en attente, puis supprime le fichier.
    // "Consommer" = lire + effacer en une seule opération pour éviter les doublons.
    // Si le fichier est vide ou absent, retourne [] sans rien supprimer.
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
