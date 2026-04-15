//
//  ClipboardStore.swift
//  ClipKeep
//
//  Created by tamtam-8 on 6/4/2026.
//

import UIKit
import SwiftData
import Observation  // 

@Observable  // nécessaire pour @Environment
@MainActor
class ClipboardStore {
    private var lastChangeCount = UIPasteboard.general.changeCount
    var isInternalCopy = false  // flag levé par l'app

    private let pastePromptKey = "didShowPastePermissionPrompt"
    var shouldShowPastePermissionPrompt = false

    private var didShowPastePermissionPrompt: Bool {
        get { UserDefaults.standard.bool(forKey: pastePromptKey) }
        set { UserDefaults.standard.set(newValue, forKey: pastePromptKey) }
    }

    func checkClipboard(context: ModelContext) {
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
            let type: ClipType = text.hasPrefix("http") ? .url : .text
            insertOrPromote(data: data, type: type, context: context)
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
    }
}
