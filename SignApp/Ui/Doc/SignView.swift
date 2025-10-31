import Combine
import SwiftUI
import UIKit

final class SignaturesStore: ObservableObject {
    struct Item: Identifiable, Hashable {
        let id = UUID()
        let url: URL
        let image: UIImage
    }

    @Published var items: [Item] = []

    func reload() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = self.loadAll()
            DispatchQueue.main.async {
                self.items = loaded
                LOG("SIGN", "loaded \(loaded.count) signatures")
            }
        }
    }

    private func loadAll() -> [Item] {
        let fm = FileManager.default
        guard
            var dir = try? fm.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        else { return [] }
        dir.appendPathComponent("Signatures", isDirectory: true)

        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        guard
            let urls = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [
                    .creationDateKey, .contentModificationDateKey,
                ],
                options: [.skipsHiddenFiles]
            )
        else { return [] }

        let sorted =
            urls
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted {
                let a =
                    (try? $0.resourceValues(forKeys: [
                        .contentModificationDateKey, .creationDateKey,
                    ]).contentModificationDate)
                    ?? (try? $0.resourceValues(forKeys: [.creationDateKey])
                        .creationDate) ?? .distantPast
                let b =
                    (try? $1.resourceValues(forKeys: [
                        .contentModificationDateKey, .creationDateKey,
                    ]).contentModificationDate)
                    ?? (try? $1.resourceValues(forKeys: [.creationDateKey])
                        .creationDate) ?? .distantPast
                return a > b
            }

        return sorted.compactMap { url in
            guard let img = UIImage(contentsOfFile: url.path) else {
                return nil
            }
            return Item(url: url, image: img)
        }
    }
}

struct SignView: View {

    let images: [UIImage]
    var onBack: () -> Void = {}
    var onSign: () -> Void = {}
    var onCreateSignature: () -> Void = {}
    var onSaved: (URL) -> Void = { _ in }

    @State private var currentIndex: Int = 0
    @State private var showGallery: Bool = false
    @State private var exportItem: ExportItem? = nil
    @State private var pendingSavedURL: URL? = nil

    @StateObject private var sigStore = SignaturesStore()

    @State private var placed: [Int: [PlacedSignature]] = [:]
    @State private var selectedID: UUID? = nil

    init(
        original: UIImage,
        onBack: @escaping () -> Void = {},
        onDownload: @escaping () -> Void = {},
        onSign: @escaping () -> Void = {},
        onCreateSignature: @escaping () -> Void = {},
        onSaved: @escaping (URL) -> Void = { _ in }
    ) {
        self.images = [original]
        self.onBack = onBack
        self.onSign = onSign
        self.onCreateSignature = onCreateSignature
        self.onSaved = onSaved
    }

    init(
        images: [UIImage],
        onBack: @escaping () -> Void = {},
        onDownload: @escaping () -> Void = {},
        onSign: @escaping () -> Void = {},
        onCreateSignature: @escaping () -> Void = {},
        onSaved: @escaping (URL) -> Void = { _ in }
    ) {
        self.images = images
        self.onBack = onBack
        self.onSign = onSign
        self.onCreateSignature = onCreateSignature
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(spacing: 0) {

            ZStack {
                Text("Sign Document")
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

                    Button(action: {
                        Task { await savePDFAndShare() }
                    }) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.init(hex: "FFAE00").opacity(0.8))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image("ic_save")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(.black)
                                    .frame(width: 22, height: 22)
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
                            let fit = aspectFitRect(
                                imageSize: images[i].size,
                                in: geo.size
                            )

                            ZStack(alignment: .topLeading) {

                                Image(uiImage: images[i])
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(
                                        width: geo.size.width,
                                        height: geo.size.height
                                    )
                                    .clipped()
                                    .contentShape(Rectangle())

                                ZStack(alignment: .topLeading) {
                                    Color.clear
                                        .frame(
                                            width: fit.width,
                                            height: fit.height
                                        )
                                        .position(x: fit.midX, y: fit.midY)

                                    let arr = placed[i] ?? []
                                    ForEach(arr) { sig in
                                        SignatureSticker(
                                            signature: sig,
                                            fitRect: fit,
                                            isSelected: sig.id == selectedID,
                                            onUpdate: { updated in

                                                guard var pageArr = placed[i],
                                                    let idx =
                                                        pageArr.firstIndex(
                                                            where: {
                                                                $0.id == sig.id
                                                            })
                                                else { return }
                                                pageArr[idx] = updated
                                                placed[i] = pageArr
                                            },
                                            onSelect: {
                                                selectedID =
                                                    (selectedID == sig.id
                                                        ? nil : sig.id)

                                                guard var pageArr = placed[i],
                                                    let idx =
                                                        pageArr.firstIndex(
                                                            where: {
                                                                $0.id == sig.id
                                                            })
                                                else { return }
                                                for k in pageArr.indices {
                                                    pageArr[k].isSelected =
                                                        (k == idx)
                                                        && (selectedID == sig.id)
                                                }
                                                placed[i] = pageArr
                                            },
                                            onDelete: {
                                                guard var pageArr = placed[i]
                                                else { return }
                                                pageArr.removeAll {
                                                    $0.id == sig.id
                                                }
                                                placed[i] = pageArr
                                                if selectedID == sig.id {
                                                    selectedID = nil
                                                }
                                            }
                                        )
                                    }
                                }
                                .frame(
                                    width: geo.size.width,
                                    height: geo.size.height,
                                    alignment: .topLeading
                                )
                            }
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

            VStack(alignment: .leading, spacing: 8) {
                if sigStore.items.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black.opacity(0.6))
                        Text("No signatures yet")
                            .foregroundColor(.black.opacity(0.7))
                            .font(.system(size: 14))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.white.opacity(0.6))
                    .clipShape(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(sigStore.items) { item in
                                SignatureThumb(image: item.image)
                                    .onTapGesture {
                                        LOG(
                                            "SIGN",
                                            "add signature to page \(currentIndex)"
                                        )
                                        var arr = placed[currentIndex] ?? []
                                        arr.append(
                                            PlacedSignature(
                                                image: item.image,
                                                cx: 0.5,
                                                cy: 0.85,
                                                widthFrac: 0.32,
                                                isSelected: true
                                            )
                                        )
                                        placed[currentIndex] = arr
                                        selectedID = arr.last?.id
                                    }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .padding(.top, 8)

            HStack {
                Button(action: {
                    LOG("SIGN", "+ tapped -> onCreateSignature()")
                    onCreateSignature()
                }) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.black.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image("ic_plus")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundColor(.white)
                        )
                }
                Spacer()

                Button(action: { showGallery = true }) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.black.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image("ic_dots")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundColor(.white)
                        )
                }

            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .background(Color(hex: "#DDDDDD").ignoresSafeArea())
        .fullScreenCover(
            isPresented: $showGallery,
            onDismiss: {
                LOG("SIGN", "gallery dismissed → reload signatures")
                sigStore.reload()
            }
        ) {
            GallerySignView(onBack: { showGallery = false })
        }
        .onAppear {
            LOG("SIGN", "appear → reload saved signatures")
            sigStore.reload()
        }
        .onChange(of: showGallery) { opened in
            if !opened { sigStore.reload() }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .signaturesDidChange)
        ) { _ in
            LOG("SIGN", "notification → reload signatures")
            sigStore.reload()
        }
        .sheet(
            item: $exportItem,
            onDismiss: {
                if let url = pendingSavedURL {
                    let u = url
                    pendingSavedURL = nil
                    onSaved(u)
                }
            }
        ) { item in
            ActivityView(activityItems: [item.url])
        }
    }

    private func savePDFAndShare() async {
        LOG("SIGN", "save tapped → building signed PDF")
        guard let url = generateSignedPDFA4() else {
            LOG("SIGN", "PDF generation failed")
            return
        }
        LOG("SIGN", "PDF saved to \(url.path)")
        pendingSavedURL = url
        exportItem = ExportItem(url: url)
    }

    private func generateSignedPDFA4() -> URL? {
        guard !images.isEmpty else { return nil }

        let pageSize = CGSize(width: 595, height: 842)
        let margin: CGFloat = 24
        let pageBounds = CGRect(origin: .zero, size: pageSize)

        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds, format: format)

        let data = renderer.pdfData { ctx in
            for (pageIndex, baseImage) in images.enumerated() {
                ctx.beginPage(withBounds: pageBounds, pageInfo: [:])

                let contentRect = pageBounds.insetBy(dx: margin, dy: margin)
                let fit = aspectFitRect(
                    imageSize: baseImage.size,
                    in: contentRect.size
                )
                let drawRect = CGRect(
                    x: contentRect.minX + fit.origin.x,
                    y: contentRect.minY + fit.origin.y,
                    width: fit.size.width,
                    height: fit.size.height
                )

                baseImage.draw(in: drawRect)

                let items = placed[pageIndex] ?? []
                for sig in items {

                    let targetW = drawRect.width
                    let targetH = drawRect.height

                    let stickerW = sig.widthFrac * targetW
                    let aspect =
                        (sig.image.size.width > 0)
                        ? (sig.image.size.height / sig.image.size.width)
                        : 1
                    let stickerH = stickerW * aspect

                    let cx = drawRect.minX + sig.cx * targetW
                    let cy = drawRect.minY + sig.cy * targetH

                    let cg = UIGraphicsGetCurrentContext()
                    cg?.saveGState()
                    cg?.translateBy(x: cx, y: cy)
                    cg?.rotate(by: CGFloat(sig.angleDeg * .pi / 180))
                    let rect = CGRect(
                        x: -stickerW / 2,
                        y: -stickerH / 2,
                        width: stickerW,
                        height: stickerH
                    )
                    sig.image.draw(in: rect, blendMode: .normal, alpha: 1.0)
                    cg?.restoreGState()
                }
            }
        }

        let fm = FileManager.default
        guard
            var dir = try? fm.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        else { return nil }
        dir.appendPathComponent("Signed", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let ts = ISO8601DateFormatter()
        ts.formatOptions = [
            .withYear, .withMonth, .withDay, .withTime,
            .withDashSeparatorInDate, .withColonSeparatorInTime,
        ]
        let name =
            "Signed-\(ts.string(from: Date()).replacingOccurrences(of: ":", with: "-")).pdf"
        var fileURL = dir.appendingPathComponent(name)

        do {
            try data.write(to: fileURL, options: .atomic)
            var r = URLResourceValues()
            r.isExcludedFromBackup = true
            try? fileURL.setResourceValues(r)
            return fileURL
        } catch {
            LOG("SIGN", "write pdf error: \(error)")
            return nil
        }
    }

    private func generateSignedPDFSameSize() -> URL? {
        guard !images.isEmpty else { return nil }

        let format = UIGraphicsPDFRendererFormat()
        let dummyBounds = CGRect(
            origin: .zero,
            size: .init(width: 100, height: 100)
        )
        let renderer = UIGraphicsPDFRenderer(
            bounds: dummyBounds,
            format: format
        )

        let data = renderer.pdfData { ctx in
            for (pageIndex, baseImage) in images.enumerated() {
                let pageSize = baseImage.size
                let pageBounds = CGRect(origin: .zero, size: pageSize)
                ctx.beginPage(withBounds: pageBounds, pageInfo: [:])

                baseImage.draw(in: pageBounds)

                let items = placed[pageIndex] ?? []
                for sig in items {
                    let Wimg = pageSize.width
                    let Himg = pageSize.height

                    let stickerW = sig.widthFrac * Wimg
                    let aspect =
                        (sig.image.size.width > 0)
                        ? (sig.image.size.height / sig.image.size.width) : 1
                    let stickerH = stickerW * aspect

                    let cx = sig.cx * Wimg
                    let cy = sig.cy * Himg

                    let cg = UIGraphicsGetCurrentContext()
                    cg?.saveGState()
                    cg?.translateBy(x: cx, y: cy)
                    cg?.rotate(by: CGFloat(sig.angleDeg * .pi / 180))
                    let drawRect = CGRect(
                        x: -stickerW / 2,
                        y: -stickerH / 2,
                        width: stickerW,
                        height: stickerH
                    )
                    sig.image.draw(in: drawRect, blendMode: .normal, alpha: 1.0)
                    cg?.restoreGState()
                }
            }
        }

        let fm = FileManager.default
        guard
            var dir = try? fm.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        else {
            return nil
        }
        dir.appendPathComponent("Signed", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let ts = ISO8601DateFormatter()
        ts.formatOptions = [
            .withYear, .withMonth, .withDay, .withTime,
            .withDashSeparatorInDate, .withColonSeparatorInTime,
        ]
        let name =
            "Signed-\(ts.string(from: Date()).replacingOccurrences(of: ":", with: "-")).pdf"
        var fileURL = dir.appendingPathComponent(name)

        do {
            try data.write(to: fileURL, options: .atomic)
            var r = URLResourceValues()
            r.isExcludedFromBackup = true
            try? fileURL.setResourceValues(r)
            return fileURL
        } catch {
            LOG("SIGN", "write pdf error: \(error)")
            return nil
        }
    }

}

private struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct SignatureThumb: View {
    let image: UIImage
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
                .frame(width: 86, height: 86)
                .clipShape(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "FFAE00"), lineWidth: 1)
        )
    }
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

extension Notification.Name {
    static let signaturesDidChange = Notification.Name("signaturesDidChange")
}

private struct PlacedSignature: Identifiable, Hashable {
    let id = UUID()
    let image: UIImage

    var cx: CGFloat
    var cy: CGFloat

    var widthFrac: CGFloat = 0.32

    var isSelected: Bool = false

    var angleDeg: Double = 0
}

@inline(__always)
private func clamp<T: Comparable>(_ v: T, _ a: T, _ b: T) -> T {
    max(a, min(v, b))
}

private func aspectFitRect(imageSize: CGSize, in container: CGSize) -> CGRect {
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

#Preview {
    SignView(
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

private struct SignatureSticker: View {
    var signature: PlacedSignature
    let fitRect: CGRect
    let isSelected: Bool
    let onUpdate: (PlacedSignature) -> Void
    let onSelect: () -> Void
    let onDelete: () -> Void

    @GestureState private var drag: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1.0
    @GestureState private var resizeTrans: CGSize = .zero

    private let minFrac: CGFloat = 0.12
    private let maxFrac: CGFloat = 0.90

    var body: some View {
        let baseW = signature.widthFrac * fitRect.width
        let aspect =
            signature.image.size.height == 0
            ? 1 : (signature.image.size.height / signature.image.size.width)
        let baseH = baseW * aspect

        let cxAbs = fitRect.minX + signature.cx * fitRect.width
        let cyAbs = fitRect.minY + signature.cy * fitRect.height

        let sHandle = liveScaleForResize(
            translation: resizeTrans,
            baseW: baseW,
            baseH: baseH,
            center: CGPoint(x: cxAbs, y: cyAbs),
            aspect: aspect
        )
        let liveScale = pinch * sHandle

        let liveWidth = baseW * liveScale
        let liveHeight = baseH * liveScale

        let tx = drag.width
        let ty = drag.height

        ZStack(alignment: .topTrailing) {
            Image(uiImage: signature.image)
                .resizable()
                .scaledToFit()
                .frame(width: liveWidth, height: liveHeight)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color(hex: "FFAE00"), lineWidth: 2)
                    }
                }
                .position(x: cxAbs + tx, y: cyAbs + ty)
                .gesture(
                    dragGesture(liveWidth: liveWidth, liveHeight: liveHeight)
                )
                .simultaneousGesture(pinchGesture())
                .onTapGesture { onSelect() }

            if isSelected {

                Button(role: .destructive, action: onDelete) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.black.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .offset(x: -8, y: 8)
                .position(
                    x: cxAbs + tx + liveWidth / 2,
                    y: cyAbs + ty - liveHeight / 2
                )

                let handleSize: CGFloat = 28
                ResizeHandle()
                    .frame(width: handleSize, height: handleSize)
                    .contentShape(Rectangle())
                    .position(
                        x: cxAbs + tx + liveWidth / 2,
                        y: cyAbs + ty + liveHeight / 2
                    )

                    .highPriorityGesture(
                        resizeGesture(
                            baseW: baseW,
                            baseH: baseH,
                            center: CGPoint(x: cxAbs, y: cyAbs),
                            aspect: aspect
                        )
                    )
            }
        }
        .animation(.none, value: isSelected)
    }

    private func dragGesture(liveWidth: CGFloat, liveHeight: CGFloat)
        -> some Gesture
    {
        DragGesture()
            .updating($drag) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                var nx =
                    (fitRect.minX + signature.cx * fitRect.width)
                    + value.translation.width
                var ny =
                    (fitRect.minY + signature.cy * fitRect.height)
                    + value.translation.height

                let halfW = liveWidth / 2
                let halfH = liveHeight / 2
                nx = clamp(nx, fitRect.minX + halfW, fitRect.maxX - halfW)
                ny = clamp(ny, fitRect.minY + halfH, fitRect.maxY - halfH)

                var updated = signature
                updated.cx = clamp((nx - fitRect.minX) / fitRect.width, 0, 1)
                updated.cy = clamp((ny - fitRect.minY) / fitRect.height, 0, 1)
                onUpdate(updated)
            }
    }

    private func pinchGesture() -> some Gesture {
        MagnificationGesture()
            .updating($pinch) { value, state, _ in
                state = value
            }
            .onEnded { value in
                var updated = signature
                var newFrac = clamp(
                    signature.widthFrac * value,
                    minFrac,
                    maxFrac
                )

                let maxByBounds = maxWidthFracThatFits(
                    centerX: signature.cx,
                    centerY: signature.cy,
                    aspect: (signature.image.size.width > 0
                        ? signature.image.size.height
                            / signature.image.size.width : 1)
                )
                newFrac = min(newFrac, maxByBounds)
                updated.widthFrac = newFrac
                onUpdate(updated)
            }
    }

    private func resizeGesture(
        baseW: CGFloat,
        baseH: CGFloat,
        center: CGPoint,
        aspect: CGFloat
    ) -> some Gesture {
        DragGesture()
            .updating($resizeTrans) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                let s = liveScaleForResize(
                    translation: value.translation,
                    baseW: baseW,
                    baseH: baseH,
                    center: center,
                    aspect: aspect
                )
                var updated = signature
                var newFrac = (baseW * s) / fitRect.width
                newFrac = clamp(newFrac, minFrac, maxFrac)

                let maxByBounds = maxWidthFracThatFits(
                    centerX: signature.cx,
                    centerY: signature.cy,
                    aspect: aspect
                )
                updated.widthFrac = min(newFrac, maxByBounds)
                onUpdate(updated)
            }
    }

    private func liveScaleForResize(
        translation t: CGSize,
        baseW: CGFloat,
        baseH: CGFloat,
        center: CGPoint,
        aspect: CGFloat
    ) -> CGFloat {
        let startHalfW = baseW / 2
        let startHalfH = baseH / 2

        let br0 = CGPoint(x: center.x + startHalfW, y: center.y + startHalfH)
        let br1 = CGPoint(x: br0.x + t.width, y: br0.y + t.height)

        let newHalfW = max(br1.x - center.x, 4)
        let newHalfH = max(br1.y - center.y, 4)

        var s = max(newHalfW / startHalfW, newHalfH / startHalfH)

        let dxMax = min(center.x - fitRect.minX, fitRect.maxX - center.x)
        let dyMax = min(center.y - fitRect.minY, fitRect.maxY - center.y)
        let halfWLimitByBounds = min(dxMax, dyMax / aspect)
        let maxScaleByBounds = halfWLimitByBounds / startHalfW

        let minScaleByFrac = (fitRect.width * minFrac) / baseW
        let maxScaleByFrac = (fitRect.width * maxFrac) / baseW

        s = clamp(s, minScaleByFrac, min(maxScaleByFrac, maxScaleByBounds))
        return s
    }

    private func maxWidthFracThatFits(
        centerX: CGFloat,
        centerY: CGFloat,
        aspect: CGFloat
    ) -> CGFloat {
        let cxAbs = fitRect.minX + centerX * fitRect.width
        let cyAbs = fitRect.minY + centerY * fitRect.height

        let dx = min(cxAbs - fitRect.minX, fitRect.maxX - cxAbs)
        let dy = min(cyAbs - fitRect.minY, fitRect.maxY - cyAbs)

        let maxHalfWByBounds = min(dx, dy / aspect)
        let maxWByBounds = maxHalfWByBounds * 2
        return clamp(maxWByBounds / fitRect.width, 0, 1)
    }
}

private struct ResizeHandle: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.black.opacity(0.8))
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
