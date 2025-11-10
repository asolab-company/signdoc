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
                  
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {

                case .sign:
                    SignView(
                        images: pages,
                        onBack: {
                          
                            path.removeLast()
                        },
                        onCreateSignature: {
                      
                            onOpenSignatureScanner()
                        },
                        onSaved: { url in
                          
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
