import UIKit
import SwiftUI

@objc(KeyboardViewController)
class KeyboardViewController: UIInputViewController {

    private var hostingController: UIHostingController<KeyboardView>?

    // Surveillance du presse-papiers pendant que le clavier est actif.
    // Le clavier étant actif pendant toute session de frappe, il peut capturer
    // les copies faites dans n'importe quelle app sans que ClipKeep soit ouvert.
    private var lastChangeCount = UIPasteboard.general.changeCount
    private var captureTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboardView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Confirme l'accès complet dans l'App Group pour que ClipKeep
        // puisse afficher l'alerte si ce n'est pas activé.
        if hasFullAccess {
            UserDefaults(suiteName: "group.com.rafyq.ClipKeep")?
                .set(true, forKey: "keyboard_full_access_ok")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Initialise le compteur à l'apparition pour ne pas capturer
        // du contenu déjà copié avant l'ouverture du clavier.
        lastChangeCount = UIPasteboard.general.changeCount
        captureTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.captureIfChanged()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureTimer?.invalidate()
        captureTimer = nil
    }

    // Vérifie si le presse-papiers a changé depuis la dernière vérification.
    // Si oui, écrit le nouveau contenu dans captured_clips.json (App Group).
    private func captureIfChanged() {
        let current = UIPasteboard.general.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current
        if let text = UIPasteboard.general.string, !text.isEmpty {
            SharedClipStore.addCaptured(text: text)
        }
    }

    private func setupKeyboardView() {
        let keyboardView = KeyboardView(
            needsNextKeyboard: needsInputModeSwitchKey,
            hasFullAccess: hasFullAccess,
            onInsert: { [weak self] text in
                self?.textDocumentProxy.insertText(text)
            },
            onDelete: { [weak self] in
                self?.textDocumentProxy.deleteBackward()
            },
            onNextKeyboard: { [weak self] in
                self?.advanceToNextInputMode()
            }
        )

        let hosting = UIHostingController(rootView: keyboardView)
        hostingController = hosting

        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
