//
//  ActivityShareSheet.swift
//  ClipKeep
//

import UIKit

enum ActivityShareSheet {
    static func present(items: [Any], onDismiss: ((_ completed: Bool) -> Void)? = nil) {
        guard
            let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let window = scene.windows.first(where: \.isKeyWindow),
            let rootVC = window.rootViewController
        else { return }

        var topVC = rootVC
        while let next = topVC.presentedViewController { topVC = next }

        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = window
        vc.completionWithItemsHandler = { _, completed, _, _ in onDismiss?(completed) }
        topVC.present(vc, animated: true)
    }
}
