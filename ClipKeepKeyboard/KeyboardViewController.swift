import UIKit
import SwiftUI

class KeyboardViewController: UIInputViewController {

    private var hostingController: UIHostingController<KeyboardView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboardView()
    }

    private func setupKeyboardView() {
        let keyboardView = KeyboardView(
            needsNextKeyboard: needsInputModeSwitchKey,
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
