import SafariServices
import SwiftUI

struct BrowserSheetItem: Identifiable {
    let url: URL

    var id: String {
        url.absoluteString
    }
}

struct InAppBrowserSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
