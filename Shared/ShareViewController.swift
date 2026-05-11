import UIKit
import UniformTypeIdentifiers

@objc(ShareViewController)
class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        processSharedContent()
    }

    private func processSharedContent() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            dismiss(after: 0.5)
            return
        }

        // Image
        let imageType = UTType.image.identifier
        if let provider = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(imageType) }) {
            provider.loadDataRepresentation(forTypeIdentifier: imageType) { [weak self] data, _ in
                if let data { SharedClipStore.addCapturedImage(data: data) }
                self?.dismiss(after: 0.5)
            }
            return
        }

        // URL
        let urlType = UTType.url.identifier
        if let provider = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(urlType) }) {
            provider.loadItem(forTypeIdentifier: urlType) { [weak self] item, _ in
                let text: String?
                if let url = item as? URL { text = url.absoluteString }
                else if let str = item as? String { text = str }
                else { text = nil }
                if let text { SharedClipStore.addCaptured(text: text) }
                self?.dismiss(after: 0.5)
            }
            return
        }

        // Texte
        let textType = UTType.plainText.identifier
        if let provider = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(textType) }) {
            provider.loadItem(forTypeIdentifier: textType) { [weak self] item, _ in
                if let text = item as? String { SharedClipStore.addCaptured(text: text) }
                self?.dismiss(after: 0.5)
            }
            return
        }

        dismiss(after: 0.5)
    }

    private func dismiss(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
