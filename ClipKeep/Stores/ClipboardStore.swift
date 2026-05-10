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

    // Appelé au lancement de l'app et à chaque retour au premier plan.
    // Traite d'abord les épingles en attente du clavier, puis met à jour clips.json.
    func initialSync(context: ModelContext) {
        applyPendingPinChanges(context: context)
        let descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\ClipItem.createdAt, order: .reverse)])
        let all = (try? context.fetch(descriptor)) ?? []
        syncToSharedStore(all)
    }

    // Lit pending_pins.json, trouve les ClipItems correspondants dans SwiftData,
    // bascule leur isPinned, puis sauvegarde. Appelé à chaque tick du timer
    // et à chaque activation de la scène pour ne rater aucune épingle du clavier.
    private func applyPendingPinChanges(context: ModelContext) {
        let pendingIDs = SharedClipStore.consumePendingPinToggles()
        guard !pendingIDs.isEmpty else { return }
        let descriptor = FetchDescriptor<ClipItem>()
        guard let all = try? context.fetch(descriptor) else { return }
        var changed = false
        for id in pendingIDs {
            if let item = all.first(where: { $0.id == id }) {
                item.isPinned.toggle()
                changed = true
            }
        }
        if changed { try? context.save() }
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
        case .image: captureToast = "🖼  Image enregistrée"
        case .url:   captureToast = "🔗  Lien enregistré"
        case .code:  captureToast = "{ }  Code enregistré"
        case .text:  captureToast = "📋  Texte enregistré"
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
