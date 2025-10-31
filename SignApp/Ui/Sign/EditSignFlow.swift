import SwiftUI
import UIKit

struct EditSignFlow: View {
    enum Route: Hashable {
        case crop(Int)
        case removeBg(URL)
        case success(UIImage)
    }

    let images: [UIImage]
    var onClose: () -> Void = {}
    var onScanNew: () -> Void = {}

    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            EditSignView(
                images: images,
                onBack: { onClose() },
                onOpenCrop: { index in path.append(.crop(index)) }
            )
            .navigationBarHidden(true)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .crop(let index):
                    let safe = min(max(index, 0), images.count - 1)
                    CropView(
                        original: images[safe],
                        onBack: { path.removeLast() },
                        onContinue: { cropped in
                            if let url = savePNG(cropped) {
                                path.append(.removeBg(url))
                            }
                        }
                    )
                    .navigationBarHidden(true)

                case .removeBg(let url):
                    RemoveBgView(
                        imageURL: url,
                        onBack: { path.removeLast() },
                        onContinue: { finalImage in
                            path.append(.success(finalImage))
                        }
                    )
                    .navigationBarHidden(true)

                case .success(let img):
                    SuccessSignView(
                        image: img,
                        onMenu: { onClose() },
                        onScanNew: { onScanNew() }
                    )
                    .navigationBarHidden(true)
                }
            }
        }
    }
}

private func savePNG(_ image: UIImage) -> URL? {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("crop_\(UUID().uuidString).png")
    guard let data = image.pngData() else { return nil }
    try? data.write(to: url)
    return url
}
