import SwiftUI
import UIKit

struct EditDocFlow: View {
    enum Route: Hashable {
        case sign
        case success(URL)
    }

    let images: [UIImage]
    var onClose: () -> Void = {}
    var onScanNew: () -> Void = {}
    var onOpenSignatureScanner: () -> Void = {}

    @State private var path: [Route] = []
    @State private var pages: [UIImage] = []

    @EnvironmentObject var iap: IAPManager
    @EnvironmentObject var overlay: OverlayManager

    var body: some View {
        NavigationStack(path: $path) {
            EditDocView(
                images: pages,
                onBack: { onClose() },
                onSign: { path.append(.sign) }
            )
            .navigationBarHidden(true)
            .onAppear {
                if pages.isEmpty {
                    pages = images
                    LOG("DOCFLOW", "init pages=\(pages.count)")
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {

                case .sign:
                    SignView(
                        images: pages,
                        onBack: {
                            LOG("DOCFLOW", "SignView.onBack -> pop")
                            path.removeLast()
                        },
                        onCreateSignature: {
                            LOG(
                                "DOCFLOW",
                                "SignView.onCreateSignature -> ask ScanView to switch"
                            )
                            onOpenSignatureScanner()
                        },
                        onSaved: { url in
                            LOG(
                                "DOCFLOW",
                                "PDF saved: \(url.lastPathComponent)"
                            )
                            path.append(.success(url))
                        }
                    )
                    .navigationBarHidden(true)

                case .success(let url):

                    SuccessDocView(
                        onMenu: { onClose() },
                        onScanNew: { onScanNew() }
                    )
                    .navigationBarHidden(true)
                }
            }
        }
        .fullScreenCover(isPresented: $overlay.showPaywall) {
            PaywallView()
                .environmentObject(iap)
                .environmentObject(overlay)
        }
    }
}
