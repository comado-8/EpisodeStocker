import SwiftUI

#if canImport(UIKit)
import UIKit

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        configurePopoverIfNeeded(controller)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        configurePopoverIfNeeded(uiViewController)
    }

    private func configurePopoverIfNeeded(_ controller: UIActivityViewController) {
        guard let popover = controller.popoverPresentationController else { return }
        popover.sourceView = controller.view
        popover.sourceRect = CGRect(
            x: controller.view.bounds.midX,
            y: controller.view.bounds.midY,
            width: 1,
            height: 1
        )
        popover.permittedArrowDirections = []
    }
}

#else

struct ActivityView: View {
    let activityItems: [Any]

    var body: some View {
        EmptyView()
    }
}

#endif
