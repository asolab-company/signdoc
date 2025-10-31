import SwiftUI
import UIKit

struct EditDocView: View {
    let images: [UIImage]
    var onBack: () -> Void = {}
    var onSign: () -> Void = {}
    @State private var currentIndex = 0
    @State private var exportItem: ExportItem? = nil
    @EnvironmentObject var iap: IAPManager
    @EnvironmentObject var overlay: OverlayManager

    init(
        original: UIImage,
        onBack: @escaping () -> Void = {},
        onDownload: @escaping () -> Void = {},
        onSign: @escaping () -> Void = {}
    ) {
        self.images = [original]
        self.onBack = onBack
        self.onSign = onSign
    }

    init(
        images: [UIImage],
        onBack: @escaping () -> Void = {},
        onDownload: @escaping () -> Void = {},
        onSign: @escaping () -> Void = {}
    ) {
        self.images = images
        self.onBack = onBack
        self.onSign = onSign
    }

    var body: some View {
        VStack(spacing: 0) {

            ZStack {
                Text("Scanned Documents")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.black)

                HStack {
                    Button(action: onBack) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.black.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    Spacer()
                    Button(action: saveAsPDF) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.black.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image("ic_download")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ZStack {
                TabView(selection: $currentIndex) {
                    ForEach(images.indices, id: \.self) { i in
                        GeometryReader { geo in
                            Image(uiImage: images[i])
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(
                                    width: geo.size.width,
                                    height: geo.size.height
                                )
                                .clipped()
                                .contentShape(Rectangle())
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                VStack {
                    Spacer()
                    PageDots(current: currentIndex, total: images.count)
                        .padding(.bottom, 8)
                }
            }

            Button(action: {
                if iap.isSubscribed {
                    onSign()
                } else {
                    overlay.show()
                }
            }) {
                ZStack {
                    Text("Sign the page")
                        .font(.system(size: 16, weight: .bold))

                    HStack {

                        if !iap.isSubscribed {
                            Image("app_ic_lock")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .padding(.leading)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 20, weight: .bold))
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(GreenCTAStyle())
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .background(Color(hex: "#DDDDDD").ignoresSafeArea())

        .sheet(item: $exportItem, onDismiss: { exportItem = nil }) { item in
            ActivityView(activityItems: [item.url])
        }
    }

    private func saveAsPDF() {

        guard let url = generatePDF_A4(from: images) else { return }
        exportItem = ExportItem(url: url)
    }

    private func generatePDF_A4(from images: [UIImage]) -> URL? {
        guard !images.isEmpty else { return nil }

        let pageSize = CGSize(width: 595, height: 842)
        let margin: CGFloat = 24

        let format = UIGraphicsPDFRendererFormat()
        let bounds = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)

        let data = renderer.pdfData { ctx in
            for img in images {
                ctx.beginPage()

                let contentRect = bounds.insetBy(dx: margin, dy: margin)
                let target = aspectFitRect(
                    imageSize: img.size,
                    in: contentRect.size
                )
                let drawRect = CGRect(
                    x: contentRect.minX + target.origin.x,
                    y: contentRect.minY + target.origin.y,
                    width: target.size.width,
                    height: target.size.height
                )
                img.draw(in: drawRect)
            }
        }

        let tmp = URL(
            fileURLWithPath: NSTemporaryDirectory(),
            isDirectory: true
        )
        let fileURL = tmp.appendingPathComponent(
            "Scan-\(UUID().uuidString.prefix(6)).pdf"
        )
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("PDF write error: \(error)")
            return nil
        }
    }

    private func generatePDF_nativeSize(from images: [UIImage]) -> URL? {
        guard let first = images.first else { return nil }
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: first.size),
            format: format
        )

        let data = renderer.pdfData { ctx in
            for img in images {
                ctx.beginPage(
                    withBounds: CGRect(origin: .zero, size: img.size),
                    pageInfo: [:]
                )
                img.draw(in: CGRect(origin: .zero, size: img.size))
            }
        }

        let tmp = URL(
            fileURLWithPath: NSTemporaryDirectory(),
            isDirectory: true
        )
        let url = tmp.appendingPathComponent(
            "Scan-\(UUID().uuidString.prefix(6)).pdf"
        )
        do {
            try data.write(to: url)
            return url
        } catch {
            print("PDF write error: \(error)")
            return nil
        }
    }

    private func aspectFitRect(imageSize: CGSize, in container: CGSize)
        -> CGRect
    {
        let scale = min(
            container.width / imageSize.width,
            container.height / imageSize.height
        )
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        let x = (container.width - w) / 2
        let y = (container.height - h) / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

private struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct PageDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .frame(
                        width: i == current ? 8 : 6,
                        height: i == current ? 8 : 6
                    )
                    .foregroundColor(
                        i == current
                            ? Color(hex: "#FFAE00") : Color.white.opacity(0.7)
                    )
                    .animation(.none, value: current)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.45))
        .clipShape(Capsule())
        .compositingGroup()
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )

        if let pop = vc.popoverPresentationController {
            pop.sourceView = UIApplication.shared.windows.first {
                $0.isKeyWindow
            }
            pop.sourceRect = CGRect(
                x: UIScreen.main.bounds.midX,
                y: UIScreen.main.bounds.maxY - 60,
                width: 0,
                height: 0
            )
            pop.permittedArrowDirections = []
        }
        return vc
    }
    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}

#Preview {
    EditDocView(
        images: [
            .placeholderDoc(),
            .placeholderDoc(size: .init(width: 1400, height: 1000)),
            .placeholderDoc(size: .init(width: 1000, height: 1400)),
        ]
    )
}

extension UIImage {
    fileprivate static func placeholderDoc(
        size: CGSize = .init(width: 1200, height: 1600)
    ) -> UIImage {
        let r = UIGraphicsImageRenderer(size: size)
        return r.image { ctx in
            UIColor(white: 0.95, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let inset: CGFloat = size.width * 0.08
            let doc = CGRect(
                x: inset,
                y: inset,
                width: size.width - inset * 2,
                height: size.height - inset * 2
            )
            UIBezierPath(roundedRect: doc, cornerRadius: 24).addClip()
            UIColor.white.setFill()
            ctx.fill(doc)

            UIColor(white: 0.85, alpha: 1).setFill()
            let lineInset: CGFloat = 28
            let lineH: CGFloat = 16
            let gap: CGFloat = 18
            var y = doc.minY + 40
            for i in 0..<18 {
                let w = doc.width * (0.5 + 0.5 * CGFloat((i % 5) + 1) / 5.0)
                ctx.fill(
                    CGRect(
                        x: doc.minX + lineInset,
                        y: y,
                        width: w,
                        height: lineH
                    )
                )
                y += gap
            }
        }
    }
}
