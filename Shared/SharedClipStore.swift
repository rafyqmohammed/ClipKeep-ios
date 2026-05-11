import Foundation

// Clip capturé par le clavier en arrière-plan, avant traitement par ClipKeep.
struct CapturedClipItem: Codable {
    let text: String
    let capturedAt: Date
}

// Pont de communication entre ClipKeep (app principale) et ClipKeepKeyboard (extension clavier).
// Deux canaux distincts, chacun dans un seul sens :
//   1. ClipKeep → Clavier  : clips.json        (liste complète des clips)
//   2. Clavier  → ClipKeep : pending_pins.json  (UUIDs des clips dont l'épingle a changé)
//
// Les deux fichiers vivent dans le container App Group partagé.
// L'extension clavier doit avoir RequestsOpenAccess = true dans son Info.plist
// pour pouvoir écrire dans ce container (sinon les écritures échouent silencieusement).
enum SharedClipStore {
    private static let appGroupID       = "group.com.rafyq.ClipKeep"
    private static let clipsFileName    = "clips.json"
    private static let pendingFileName  = "pending_pins.json"
    private static let capturedFileName = "captured_clips.json"

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

    private static var capturedFileURL: URL? {
        containerURL?.appendingPathComponent(capturedFileName)
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

    // MARK: — Canal 3 : Clavier → ClipKeep (captured_clips.json)
    // Le clavier écrit ici les clips détectés pendant la frappe.
    // ClipKeep (foreground ou BGTask) lit et insère dans SwiftData.

    // Appelé depuis le clavier quand il détecte un changement du presse-papiers.
    // Ignore les doublons et le texte vide.
    static func addCaptured(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = loadCaptured()
        guard !list.contains(where: { $0.text == trimmed }) else { return }
        list.append(CapturedClipItem(text: trimmed, capturedAt: Date()))
        guard let url = capturedFileURL,
              let data = try? encoder.encode(list) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // Lit captured_clips.json, le supprime, et retourne les items.
    // Même principe que consumePendingPinToggles : lire + effacer en une opération.
    static func consumeCaptured() -> [CapturedClipItem] {
        let list = loadCaptured()
        guard !list.isEmpty else { return [] }
        if let url = capturedFileURL { try? FileManager.default.removeItem(at: url) }
        return list
    }

    private static func loadCaptured() -> [CapturedClipItem] {
        guard let url = capturedFileURL,
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([CapturedClipItem].self, from: data)) ?? []
    }

    // MARK: — Images capturées depuis la Share Extension

    // Dossier dédié aux images : chaque image = un fichier PNG séparé.
    // On évite le JSON pour les images (trop lourd en base64).
    private static var imagesDirURL: URL? {
        containerURL?.appendingPathComponent("captured_images", isDirectory: true)
    }

    private static var imagesListURL: URL? {
        containerURL?.appendingPathComponent("captured_images.json")
    }

    // Appelé depuis la Share Extension quand l'utilisateur partage une image.
    // Écrit le PNG dans captured_images/ et enregistre son nom dans captured_images.json.
    static func addCapturedImage(data: Data) {
        guard let dir = imagesDirURL else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileName = UUID().uuidString + ".png"
        try? data.write(to: dir.appendingPathComponent(fileName), options: .atomic)
        var names = loadCapturedImageNames()
        names.append(fileName)
        guard let url = imagesListURL,
              let listData = try? encoder.encode(names) else { return }
        try? listData.write(to: url, options: .atomic)
    }

    // Lit et supprime toutes les images en attente. Même principe que consumeCaptured.
    static func consumeCapturedImages() -> [Data] {
        let names = loadCapturedImageNames()
        guard !names.isEmpty, let dir = imagesDirURL, let listURL = imagesListURL else { return [] }
        let result = names.compactMap { name -> Data? in
            let file = dir.appendingPathComponent(name)
            let data = try? Data(contentsOf: file)
            try? FileManager.default.removeItem(at: file)
            return data
        }
        try? FileManager.default.removeItem(at: listURL)
        return result
    }

    private static func loadCapturedImageNames() -> [String] {
        guard let url = imagesListURL,
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([String].self, from: data)) ?? []
    }
}
