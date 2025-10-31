import SwiftUI
import UIKit

struct CropView: View {

    let images: [UIImage]
    var onBack: () -> Void = {}
    var onContinue: (UIImage) -> Void = { _ in }

    @State private var currentIndex: Int = 0
    @State private var exportItem: ExportItem? = nil

    @State private var cropRect: CGRect = .zero
    @State private var dragStartRect: CGRect = .zero
    @State private var pinchStartRect: CGRect = .zero
    @State private var pinchStartRectCenter: CGPoint = .zero

    @State private var lastFit: CGRect = .zero
    @State private var lastImage: UIImage? = nil

    private let minCropSize: CGFloat = 80
    private let handleSize: CGFloat = 18
    private let borderWidth: CGFloat = 2
    private let lineWidth: CGFloat = 1

    init(
        original: UIImage,
        onBack: @escaping () -> Void = {},
        onContinue: @escaping (UIImage) -> Void = { _ in }
    ) {
        self.images = [original]
        self.onBack = onBack
        self.onContinue = onContinue
    }

    init(
        images: [UIImage],
        onBack: @escaping () -> Void = {},
        onContinue: @escaping (UIImage) -> Void = { _ in }
    ) {
        self.images = images
        self.onBack = onBack
        self.onContinue = onContinue
    }

    var body: some View {
        VStack(spacing: 0) {

            ZStack {
                Text("Crop Image")
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
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            GeometryReader { geo in
                let uiImage = images[
                    min(max(currentIndex, 0), images.count - 1)
                ]
                let container = geo.size
                let fit = aspectFitRect(imageSize: uiImage.size, in: container)

                let drag = DragGesture()
                    .onChanged { v in
                        let dx = v.translation.width
                        let dy = v.translation.height
                        var r = dragStartRect.offsetBy(dx: dx, dy: dy)
                        r = clamp(rect: r, inside: fit)
                        cropRect = r
                    }
                    .onEnded { _ in
                        dragStartRect = cropRect
                        pinchStartRect = cropRect
                        pinchStartRectCenter = cropRect.center
                    }

                let pinch = MagnificationGesture()
                    .onChanged { m in
                        var r = scaledRect(
                            pinchStartRect,
                            scale: m,
                            around: pinchStartRectCenter
                        )
                        r = clampSize(rect: r, min: minCropSize)
                        r = clamp(rect: r, inside: fit)
                        cropRect = r
                    }
                    .onEnded { _ in
                        pinchStartRect = cropRect
                        pinchStartRectCenter = cropRect.center
                    }

                ZStack {

                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: container.width, height: container.height)
                        .clipped()

                    CropGridShape(rect: cropRect, rows: 3, cols: 3)
                        .stroke(Color.black.opacity(0.8), lineWidth: lineWidth)
                        .allowsHitTesting(false)

                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .path(in: cropRect)
                        .stroke(
                            Color.init(hex: "FFAE00"),
                            lineWidth: borderWidth
                        )
                        .allowsHitTesting(false)

                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .frame(width: cropRect.width, height: cropRect.height)
                        .position(x: cropRect.midX, y: cropRect.midY)
                        .gesture(drag.simultaneously(with: pinch))
                        .onAppear {

                            if cropRect == .zero {
                                let w = fit.width * 0.8
                                let h = fit.height * 0.8
                                cropRect = CGRect(
                                    x: fit.midX - w / 2,
                                    y: fit.midY - h / 2,
                                    width: w,
                                    height: h
                                )
                                dragStartRect = cropRect
                                pinchStartRect = cropRect
                                pinchStartRectCenter = cropRect.center
                            }

                            lastFit = fit
                            lastImage = uiImage
                        }

                    ForEach(CropHandle.allCases, id: \.self) { handle in
                        let pt = handlePoint(for: handle, in: cropRect)
                        Circle()
                            .fill(Color.init(hex: "FFAE00"))
                            .frame(width: handleSize, height: handleSize)
                            .shadow(radius: 1)
                            .position(pt)
                            .gesture(
                                DragGesture()
                                    .onChanged { v in
                                        var r = resize(
                                            rect: dragStartRect,
                                            by: v.translation,
                                            from: handle
                                        )
                                        r = clampSize(rect: r, min: minCropSize)
                                        r = clamp(rect: r, inside: fit)
                                        cropRect = r
                                    }
                                    .onEnded { _ in
                                        dragStartRect = cropRect
                                        pinchStartRect = cropRect
                                        pinchStartRectCenter = cropRect.center
                                    }
                            )
                    }
                }
                .contentShape(Rectangle())

                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            guard images.count > 1 else { return }
                            if abs(value.translation.width) > 60 {
                                if value.translation.width < 0 {
                                    currentIndex = min(
                                        currentIndex + 1,
                                        images.count - 1
                                    )
                                } else {
                                    currentIndex = max(currentIndex - 1, 0)
                                }

                                let w = fit.width * 0.8
                                let h = fit.height * 0.8
                                cropRect = CGRect(
                                    x: fit.midX - w / 2,
                                    y: fit.midY - h / 2,
                                    width: w,
                                    height: h
                                )
                                dragStartRect = cropRect
                                pinchStartRect = cropRect
                                pinchStartRectCenter = cropRect.center

                                lastFit = fit
                                lastImage = uiImage
                            }
                        }
                )

                .onChange(of: currentIndex) { _ in
                    lastFit = fit
                    lastImage = uiImage
                }
                .onChange(of: cropRect) { _ in

                    lastFit = fit
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                guard let ui = lastImage,
                    let cropped = crop(
                        uiImage: ui,
                        viewFitRect: lastFit,
                        cropRect: cropRect
                    )
                else { return }
                onContinue(cropped)
            } label: {
                ZStack {
                    Text("Continue")
                        .font(.system(size: 16, weight: .bold))
                    HStack {
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

    private func aspectFitRect(imageSize: CGSize, in container: CGSize)
        -> CGRect
    {
        guard imageSize.width > 0, imageSize.height > 0,
            container.width > 0, container.height > 0
        else { return .zero }
        let s = min(
            container.width / imageSize.width,
            container.height / imageSize.height
        )
        let w = imageSize.width * s
        let h = imageSize.height * s
        return CGRect(
            x: (container.width - w) / 2,
            y: (container.height - h) / 2,
            width: w,
            height: h
        )
    }

    private func crop(uiImage: UIImage, viewFitRect: CGRect, cropRect: CGRect)
        -> UIImage?
    {
        let sx = viewFitRect.width / uiImage.size.width
        let sy = viewFitRect.height / uiImage.size.height
        let toView = CGAffineTransform(
            a: sx,
            b: 0,
            c: 0,
            d: sy,
            tx: viewFitRect.minX,
            ty: viewFitRect.minY
        )
        let toImage = toView.inverted()
        let rectInImage = cropRect.applying(toImage)

        let imgBounds = CGRect(origin: .zero, size: uiImage.size)
        let final = rectInImage.intersection(imgBounds).integral
        guard final.width > 1, final.height > 1 else { return nil }
        guard let cg = uiImage.cgImage?.cropping(to: final) else { return nil }
        return UIImage(
            cgImage: cg,
            scale: uiImage.scale,
            orientation: uiImage.imageOrientation
        )
    }

    private func savePNG(_ image: UIImage) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("crop_\(UUID().uuidString).png")
        guard let data = image.pngData() else { return nil }
        try? data.write(to: url)
        return url
    }

    private func clamp(rect: CGRect, inside bounds: CGRect) -> CGRect {
        var r = rect

        if r.width > bounds.width {
            r.size.width = bounds.width
            r.origin.x = bounds.minX
        }
        if r.height > bounds.height {
            r.size.height = bounds.height
            r.origin.y = bounds.minY
        }

        if r.minX < bounds.minX { r.origin.x = bounds.minX }
        if r.minY < bounds.minY { r.origin.y = bounds.minY }
        if r.maxX > bounds.maxX { r.origin.x = bounds.maxX - r.width }
        if r.maxY > bounds.maxY { r.origin.y = bounds.maxY - r.height }
        return r
    }

    private func clampSize(rect: CGRect, min: CGFloat) -> CGRect {
        var r = rect
        if r.width < min { r.size.width = min }
        if r.height < min { r.size.height = min }
        return r.standardized
    }

    private func scaledRect(_ rect: CGRect, scale: CGFloat, around c: CGPoint)
        -> CGRect
    {
        let newW = max(minCropSize, rect.width * scale)
        let newH = max(minCropSize, rect.height * scale)
        return CGRect(
            x: c.x - newW / 2,
            y: c.y - newH / 2,
            width: newW,
            height: newH
        ).standardized
    }

    private func resize(rect: CGRect, by t: CGSize, from handle: CropHandle)
        -> CGRect
    {
        var r = rect
        switch handle {
        case .topLeft:
            r.origin.x += t.width
            r.origin.y += t.height
            r.size.width -= t.width
            r.size.height -= t.height
        case .topRight:
            r.origin.y += t.height
            r.size.width += t.width
            r.size.height -= t.height
        case .bottomLeft:
            r.origin.x += t.width
            r.size.width -= t.width
            r.size.height += t.height
        case .bottomRight:
            r.size.width += t.width
            r.size.height += t.height
        case .top:
            r.origin.y += t.height
            r.size.height -= t.height
        case .bottom:
            r.size.height += t.height
        case .left:
            r.origin.x += t.width
            r.size.width -= t.width
        case .right:
            r.size.width += t.width
        }
        return r.standardized
    }

    private func handlePoint(for handle: CropHandle, in r: CGRect) -> CGPoint {
        switch handle {
        case .topLeft: return CGPoint(x: r.minX, y: r.minY)
        case .topRight: return CGPoint(x: r.maxX, y: r.minY)
        case .bottomLeft: return CGPoint(x: r.minX, y: r.maxY)
        case .bottomRight: return CGPoint(x: r.maxX, y: r.maxY)
        case .top: return CGPoint(x: r.midX, y: r.minY)
        case .bottom: return CGPoint(x: r.midX, y: r.maxY)
        case .left: return CGPoint(x: r.minX, y: r.midY)
        case .right: return CGPoint(x: r.maxX, y: r.midY)
        }
    }
}

private enum CropHandle: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight, top, bottom, left, right
}

private struct CropGridShape: Shape {
    let rect: CGRect
    let rows: Int
    let cols: Int

    func path(in _: CGRect) -> Path {
        var p = Path()
        guard rect.width > 0, rect.height > 0 else { return p }

        if cols > 1 {
            let dx = rect.width / CGFloat(cols)
            for i in 1..<cols {
                let x = rect.minX + CGFloat(i) * dx
                p.move(to: CGPoint(x: x, y: rect.minY))
                p.addLine(to: CGPoint(x: x, y: rect.maxY))
            }
        }

        if rows > 1 {
            let dy = rect.height / CGFloat(rows)
            for i in 1..<rows {
                let y = rect.minY + CGFloat(i) * dy
                p.move(to: CGPoint(x: rect.minX, y: y))
                p.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
        }
        return p
    }
}

private struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }
    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}

extension CGRect {
    fileprivate var center: CGPoint { CGPoint(x: midX, y: midY) }
}

#Preview {
    CropView(
        images: [
            .placeholderDoc()
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
