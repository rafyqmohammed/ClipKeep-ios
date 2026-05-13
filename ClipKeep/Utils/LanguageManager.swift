import Foundation
import Combine

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    static let supported: [String] = ["fr", "en", "ar", "es"]

    @Published private(set) var current: String

    private let defaults = UserDefaults(suiteName: "group.com.rafyq.ClipKeep")!
    private static let key = "app_language"

    private init() {
        // Priorité 1 : AppleLanguages (changé via Réglages iOS → ClipKeep OU notre syncSystem)
        // Priorité 2 : notre clé sauvegardée dans l'App Group
        // Priorité 3 : langue du système iOS (première installation)
        // Priorité 4 : français par défaut
        let resolved: String

        if let systemLangs = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
           let match = systemLangs.compactMap({ code -> String? in
               let prefix = String(code.prefix(2)).lowercased()
               return LanguageManager.supported.contains(prefix) ? prefix : nil
           }).first {
            resolved = match
        } else if let saved = UserDefaults(suiteName: "group.com.rafyq.ClipKeep")?.string(forKey: LanguageManager.key) {
            resolved = saved
        } else {
            resolved = Locale.preferredLanguages
                .compactMap { lang -> String? in
                    let code = String(lang.prefix(2)).lowercased()
                    return LanguageManager.supported.contains(code) ? code : nil
                }
                .first ?? "fr"
        }

        current = resolved
        UserDefaults(suiteName: "group.com.rafyq.ClipKeep")?.set(resolved, forKey: LanguageManager.key)
        LanguageManager.syncSystem(resolved)
    }

    func set(_ language: String) {
        guard LanguageManager.supported.contains(language), language != current else { return }
        current = language
        defaults.set(language, forKey: LanguageManager.key)
        LanguageManager.syncSystem(language)
    }

    // Writes to AppleLanguages so iOS Settings → ClipKeep shows the right language.
    // Takes effect on next app launch (iOS requirement).
    private static func syncSystem(_ language: String) {
        UserDefaults.standard.set([language], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }

    var isRTL: Bool { current == "ar" }
}

// Global shortcut — resolves the key in the currently selected language bundle.
func loc(_ key: String) -> String {
    let lang = LanguageManager.shared.current
    guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
          let bundle = Bundle(path: path) else {
        return Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }
    return bundle.localizedString(forKey: key, value: key, table: nil)
}
