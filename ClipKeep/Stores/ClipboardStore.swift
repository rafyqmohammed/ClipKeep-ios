//
//  ClipboardStore.swift
//  ClipKeep
//
//  Created by tamtam-8 on 6/4/2026.
//

import UIKit
import SwiftData
import Observation

@Observable  // nécessaire pour @Environment
@MainActor
class ClipboardStore {
    private var lastChangeCount = UIPasteboard.general.changeCount
    var isInternalCopy = false
    var captureToast: String? = nil
    var isEnabled: Bool = UserDefaults.standard.object(forKey: "clipboardEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "clipboardEnabled")
            lastChangeCount = UIPasteboard.general.changeCount
        }
    }

    private let pastePromptKey = "didShowPastePermissionPrompt"
    var shouldShowPastePermissionPrompt = false

    private var didShowPastePermissionPrompt: Bool {
        get { UserDefaults.standard.bool(forKey: pastePromptKey) }
        set { UserDefaults.standard.set(newValue, forKey: pastePromptKey) }
    }

    // Alerte "Accès complet clavier" — même logique que shouldShowPastePermissionPrompt.
    // Affichée une seule fois si le clavier n'a jamais confirmé son accès complet.
    private let fullAccessPromptKey  = "didShowFullAccessPrompt"
    private let fullAccessConfirmKey = "keyboard_full_access_ok"
    var shouldShowFullAccessPrompt = false

    private var didShowFullAccessPrompt: Bool {
        get { UserDefaults.standard.bool(forKey: fullAccessPromptKey) }
        set { UserDefaults.standard.set(newValue, forKey: fullAccessPromptKey) }
    }

    private func checkFullAccessStatus() {
        guard !didShowFullAccessPrompt else { return }
        let confirmed = UserDefaults(suiteName: "group.com.rafyq.ClipKeep")?
            .bool(forKey: fullAccessConfirmKey) ?? false
        if !confirmed {
            shouldShowFullAccessPrompt = true
            didShowFullAccessPrompt = true
        }
    }

    // Appelé au lancement de l'app et à chaque retour au premier plan.
    // Ordre : épingles en attente → clips capturés → sync du fichier partagé.
    func initialSync(context: ModelContext) {
        applyPendingPinChanges(context: context)
        processCapturedClips(context: context)
        checkFullAccessStatus()
        let descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\ClipItem.createdAt, order: .reverse)])
        let all = (try? context.fetch(descriptor)) ?? []
        syncToSharedStore(all)
    }

    // Traite les clips capturés par le clavier ET la Share Extension.
    // Texte/URL/Code → captured_clips.json | Images → captured_images/
    // Pas de toast : les clips apparaissent silencieusement dans la liste.
    func processCapturedClips(context: ModelContext) {
        let capturedTexts  = SharedClipStore.consumeCaptured()
        let capturedImages = SharedClipStore.consumeCapturedImages()
        guard !capturedTexts.isEmpty || !capturedImages.isEmpty else { return }

        let descriptor = FetchDescriptor<ClipItem>()
        let all = (try? context.fetch(descriptor)) ?? []
        var changed = false

        // Texte, URLs et code capturés par le clavier ou la Share Extension.
        for item in capturedTexts {
            guard let data = item.text.data(using: .utf8) else { continue }
            if let existing = all.first(where: { $0.contentData == data }) {
                context.delete(existing)
            }
            let type: ClipType
            if item.text.hasPrefix("http") { type = .url }
            else if looksLikeCode(item.text) { type = .code }
            else { type = .text }
            context.insert(ClipItem(contentData: data, type: type))
            changed = true
        }

        // Images capturées depuis la Share Extension.
        for imageData in capturedImages {
            if let existing = all.first(where: { $0.contentData == imageData }) {
                context.delete(existing)
            }
            context.insert(ClipItem(contentData: imageData, type: .image))
            changed = true
        }

        if changed {
            try? context.save()
            cleanupIfNeeded(context: context)
        }
    }

    // Lit pending_pins.json, trouve les ClipItems correspondants dans SwiftData,
    // bascule leur isPinned, puis sauvegarde. Appelé à chaque tick du timer
    // et à chaque activation de la scène pour ne rater aucune épingle du clavier.
    @discardableResult
    func applyPendingPinChanges(context: ModelContext) -> Bool {
        let pendingIDs = SharedClipStore.consumePendingPinToggles()
        guard !pendingIDs.isEmpty else { return false }
        let descriptor = FetchDescriptor<ClipItem>()
        guard let all = try? context.fetch(descriptor) else { return false }
        var changed = false
        for id in pendingIDs {
            if let item = all.first(where: { $0.id == id }) {
                item.isPinned.toggle()
                changed = true
            }
        }
        if changed {
            try? context.save()
            syncToSharedStore(all)
        }
        return changed
    }

    // Vérifie le presse-papiers toutes les 1,5 secondes.
    // Traite aussi les épingles en attente du clavier à chaque tick.
    func checkClipboard(context: ModelContext) {
        applyPendingPinChanges(context: context)
        guard isEnabled else { return }
        guard UIPasteboard.general.changeCount != lastChangeCount else { return }
        lastChangeCount = UIPasteboard.general.changeCount

        // Copie depuis l'app → on ignore, on reset le flag, on ne touche pas la base
        if isInternalCopy {
            isInternalCopy = false
            return
        }

        if let image = UIPasteboard.general.image, let data = image.pngData() {
            if !didShowPastePermissionPrompt {
                shouldShowPastePermissionPrompt = true
                didShowPastePermissionPrompt = true
            }
            insertOrPromote(data: data, type: .image, context: context)
        } else if let text = UIPasteboard.general.string, let data = text.data(using: .utf8) {
            if !didShowPastePermissionPrompt {
                shouldShowPastePermissionPrompt = true
                didShowPastePermissionPrompt = true
            }
            let type: ClipType
            if text.hasPrefix("http") {
                type = .url
            } else if looksLikeCode(text) {
                type = .code
            } else {
                type = .text
            }
            insertOrPromote(data: data, type: type, context: context)
        }
    }

    private func looksLikeCode(_ text: String) -> Bool {
        let multilineKeywords = ["func ", "def ", "class ", "return ",
                                 "const ", "for (", "while (", "#include",
                                 "public ", "private ", "() =>", "===", "!==", "#!/",
                                 "var ", "let ", "->"]
        let singleLineKeywords = ["import ", "print(", "console.log(", "System.out",
                                  "cout <<", "printf(", "echo ", "SELECT ", "FROM "]
        if text.contains("\n") {
            return multilineKeywords.contains(where: { text.contains($0) })
        } else {
            return singleLineKeywords.contains(where: { text.contains($0) })
        }
    }

    private func insertOrPromote(data: Data, type: ClipType, context: ModelContext) {
        let descriptor = FetchDescriptor<ClipItem>()
        let all = (try? context.fetch(descriptor)) ?? []

        if let existing = all.first(where: { $0.contentData == data }) {
            context.delete(existing)
        }

        let newItem = ClipItem(contentData: data, type: type)
        context.insert(newItem)
        try? context.save()
        cleanupIfNeeded(context: context)
        showCaptureToast(for: type)

        let updated = (try? context.fetch(descriptor)) ?? []
        syncToSharedStore(updated)
    }

    private func syncToSharedStore(_ items: [ClipItem]) {
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
                    subtype: $0.detectedSubtype?.rawValue,
                    createdAt: $0.createdAt,
                    isPinned: $0.isPinned
                )
            }
        SharedClipStore.sync(from: shared)
    }

    private func showCaptureToast(for type: ClipType) {
        switch type {
        case .image: captureToast = loc("toast.image.saved")
        case .url:   captureToast = loc("toast.link.saved")
        case .code:  captureToast = loc("toast.code.saved")
        case .text:  captureToast = loc("toast.text.saved")
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            self?.captureToast = nil
        }
    }

    // Force une sync immédiate de SwiftData vers clips.json.
    // Appelé depuis ClipListView après chaque épingle/désépingle dans ClipKeep,
    // pour que le clavier voit le changement dès sa prochaine tick d'une seconde.
    func syncAll(context: ModelContext) {
        let descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\ClipItem.createdAt, order: .reverse)])
        let all = (try? context.fetch(descriptor)) ?? []
        syncToSharedStore(all)
    }

    func cleanupIfNeeded(context: ModelContext) {
        let retentionDays = UserDefaults.standard.integer(forKey: "retentionDays")
        let maxItems = UserDefaults.standard.integer(forKey: "maxItems")
        guard retentionDays > 0 || maxItems > 0 else { return }

        let descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\ClipItem.createdAt, order: .reverse)])
        guard let all = try? context.fetch(descriptor) else { return }

        var changed = false

        if retentionDays > 0 {
            let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date.distantPast
            for item in all where !item.isPinned && item.createdAt < cutoff {
                context.delete(item)
                changed = true
            }
        }

        if maxItems > 0 {
            let nonPinned = all.filter { !$0.isPinned }
            if nonPinned.count > maxItems {
                for item in nonPinned.dropFirst(maxItems) {
                    context.delete(item)
                    changed = true
                }
            }
        }

        if changed {
            try? context.save()
            let remaining = (try? context.fetch(descriptor)) ?? []
            syncToSharedStore(remaining)
        }
    }
}
