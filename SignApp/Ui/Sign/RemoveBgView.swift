import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit
import Vision

struct RemoveBgView: View {

    let image: UIImage
    var onBack: () -> Void = {}
    var onContinue: (UIImage) -> Void = { _ in }

    @State private var processed: UIImage? = nil
    @State private var isProcessing = true
    @State private var sliderValue: CGFloat = 0.6

    @State private var workingImage: UIImage? = nil
    @State private var isDrawing = false
    @State private var isErasing = false
    @State private var lastImgPoint: CGPoint? = nil
    @State private var currentViewPoint: CGPoint? = nil
    @State private var initialProcessed: UIImage? = nil

    init(
        imageURL: URL,
        onBack: @escaping () -> Void = {},
        onContinue: @escaping (UIImage) -> Void = { _ in }
    ) {
        self.image = UIImage(contentsOfFile: imageURL.path) ?? UIImage()
        self.onBack = onBack
        self.onContinue = onContinue
    }

    init(
        image: UIImage,
        onBack: @escaping () -> Void = {},
        onContinue: @escaping (UIImage) -> Void = { _ in }
    ) {
        self.image = image
        self.onBack = onBack
        self.onContinue = onContinue
    }

    var body: some View {
        VStack(spacing: 0) {

            ZStack {
                Text("Edit Sign")
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
                        guard !isProcessing else { return }
                        let base = workingImage ?? processed ?? image
                        let trimmed = trimTransparentEdges(base)
                        _ = saveSignaturePNGToDocuments(trimmed)
                        onContinue(trimmed)
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

            GeometryReader { geo in
                let shown = workingImage ?? processed ?? image
                let fit = aspectFitRect(imageSize: shown.size, in: geo.size)

                ZStack {

                    CheckerboardBackground(size: 27)

                    Image(uiImage: shown)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .opacity(isProcessing ? 0.6 : 1)

                    if isProcessing {
                        ProgressView().scaleEffect(1.2)
                    }

                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .frame(width: geo.size.width, height: geo.size.height)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { g in
                                    currentViewPoint = g.location

                                    guard isDrawing || isErasing else { return }
                                    ensureWorkingImage()
                                    let base =
                                        workingImage ?? processed ?? image
                                    guard
                                        let p = viewPointToImagePoint(
                                            g.location,
                                            fit: fit,
                                            imgSize: base.size
                                        )
                                    else { return }

                                    let lw = max(1.0, sliderValue * 30.0)

                                    if lastImgPoint == nil { lastImgPoint = p }
                                    if var wimg = workingImage ?? base
                                        as UIImage?
                                    {
                                        drawLine(
                                            on: &wimg,
                                            from: lastImgPoint!,
                                            to: p,
                                            lineWidth: lw,
                                            color: .black,
                                            erase: isErasing
                                        )
                                        workingImage = wimg
                                    }
                                    lastImgPoint = p
                                }
                                .onEnded { _ in
                                    lastImgPoint = nil
                                    currentViewPoint = nil
                                }
                        )
                }
                .clipped()
                .onAppear { ensureWorkingImageIfReady() }
                .onChange(of: processed) { _ in ensureWorkingImageIfReady() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            SignatureSlider(value: $sliderValue)
                .padding(.bottom)

            ZStack {

                HStack {
                    Spacer()
                    Spacer()
                    Button(action: {
                        isDrawing = true
                        isErasing = false
                    }) {
                        Image("app_btn_pen")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(
                                isDrawing ? Color.init(hex: "FFAE00") : .black
                            )
                            .frame(width: 36, height: 36)
                    }
                    Spacer()
                    Button(action: {
                        isErasing = true
                        isDrawing = false
                    }) {
                        Image("app_btn_robber")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(
                                isErasing ? Color.init(hex: "FFAE00") : .black
                            )
                            .frame(width: 36, height: 36)
                    }
                    Spacer()
                    Spacer()
                }

                HStack {

                    Button(action: {
                        let base = initialProcessed ?? image

                        processed = initialProcessed
                        workingImage = base

                        isDrawing = false
                        isErasing = false
                        lastImgPoint = nil
                        currentViewPoint = nil

                    }) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.black.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image("ic_restore")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(.white)
                                    .frame(width: 18, height: 18)
                            )
                    }

                    Spacer()

                    Button(action: {

                        let base = workingImage ?? processed ?? image
                        let rotated = rotateCCW90(base)

                        processed = rotated
                        workingImage = rotated

                        lastImgPoint = nil
                        currentViewPoint = nil
                        isDrawing = false
                        isErasing = false
                    }) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.black.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image("ic_rotate")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(.white)
                                    .frame(width: 18, height: 18)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(Color(hex: "#DDDDDD").ignoresSafeArea())
        .task { await autoRemoveBackground() }
    }

    @MainActor
    private func autoRemoveBackground() async {
        guard let cg = image.cgImage else {
            isProcessing = false
            return
        }

        let ciCtx = CIContext()
        let input = CIImage(cgImage: cg)

        let mono = input.applyingFilter(
            "CIColorControls",
            parameters: [
                kCIInputSaturationKey: 0.0,
                kCIInputContrastKey: 1.2,
            ]
        )

        let inverted = mono.applyingFilter("CIColorInvert")

        let alphaMask = inverted.applyingFilter("CIMaskToAlpha")

        let transparentBG = CIImage(color: .clear).cropped(to: input.extent)
        let blend = CIFilter.blendWithMask()
        blend.inputImage = input
        blend.backgroundImage = transparentBG
        blend.maskImage = alphaMask

        guard
            let out = blend.outputImage,
            let outCG = ciCtx.createCGImage(out, from: out.extent)
        else {
            isProcessing = false
            return
        }

        let result = UIImage(
            cgImage: outCG,
            scale: image.scale,
            orientation: .up
        )
        processed = result
        if initialProcessed == nil { initialProcessed = result }
        isProcessing = false
    }

    private func ensureWorkingImageIfReady() {
        if workingImage == nil, processed != nil || !isProcessing {
            workingImage = processed ?? image
        }
    }

    private func ensureWorkingImage() {
        if workingImage == nil { workingImage = processed ?? image }
    }

    private func viewPointToImagePoint(
        _ p: CGPoint,
        fit: CGRect,
        imgSize: CGSize
    ) -> CGPoint? {
        guard fit.contains(p), imgSize.width > 0, imgSize.height > 0 else {
            return nil
        }
        let nx = (p.x - fit.minX) / fit.width
        let ny = (p.y - fit.minY) / fit.height
        return CGPoint(x: nx * imgSize.width, y: ny * imgSize.height)
    }

    private func drawLine(
        on img: inout UIImage,
        from a: CGPoint,
        to b: CGPoint,
        lineWidth: CGFloat,
        color: UIColor,
        erase: Bool
    ) {
        let scale = img.scale
        let size = img.size

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }

        img.draw(at: .zero)

        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.interpolationQuality = .high

        let radius = max(0.5, lineWidth / 2.0)
        let dx = b.x - a.x
        let dy = b.y - a.y
        let dist = max(1.0, hypot(dx, dy))
        let step = max(0.5, radius * 0.6)
        let steps = max(1, Int(dist / step))

        if erase {
            ctx.setBlendMode(.clear)
            ctx.setFillColor(UIColor.clear.cgColor)
        } else {
            ctx.setBlendMode(.normal)
            ctx.setFillColor(color.cgColor)
        }

        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = a.x + dx * t
            let y = a.y + dy * t
            let rect = CGRect(
                x: x - radius,
                y: y - radius,
                width: radius * 2,
                height: radius * 2
            )
            ctx.fillEllipse(in: rect)
        }

        if let new = UIGraphicsGetImageFromCurrentImageContext() {
            img = new

        }
    }

    private func rotateCCW90(_ img: UIImage) -> UIImage {
        let newSize = CGSize(width: img.size.height, height: img.size.width)
        let r = UIGraphicsImageRenderer(
            size: newSize,
            format: UIGraphicsImageRendererFormat.default()
        )
        return r.image { ctx in
            ctx.cgContext.translateBy(x: 0, y: newSize.height)
            ctx.cgContext.rotate(by: -.pi / 2)
            img.draw(
                in: CGRect(
                    x: 0,
                    y: 0,
                    width: newSize.height,
                    height: newSize.width
                )
            )
        }
    }
}

#Preview {
    RemoveBgView(image: .placeholderDoc())
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

struct CheckerboardBackground: View {
    var size: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            let cols = Int(ceil(geo.size.width / size))
            let rows = Int(ceil(geo.size.height / size))

            Path { path in
                for row in 0..<rows {
                    for col in 0..<cols {
                        if (row + col).isMultiple(of: 2) {
                            let x = CGFloat(col) * size
                            let y = CGFloat(row) * size
                            path.addRect(
                                CGRect(x: x, y: y, width: size, height: size)
                            )
                        }
                    }
                }
            }
            .fill(Color.gray.opacity(0.3))
            .background(Color.white)
        }
        .ignoresSafeArea()
    }
}

struct SignatureAdjustHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let pad: CGFloat = 16
                let knobR: CGFloat = 18
                let barLeftH: CGFloat = 8
                let barRightH: CGFloat = 28
                let midY = h * 0.50
                let endX = w - pad - knobR * 2

                ZStack {
                    Path { p in
                        p.move(to: CGPoint(x: pad, y: midY - barLeftH / 2))
                        p.addLine(to: CGPoint(x: endX, y: midY - barRightH / 2))
                        p.addLine(to: CGPoint(x: endX, y: midY + barRightH / 2))
                        p.addLine(to: CGPoint(x: pad, y: midY + barLeftH / 2))
                        p.closeSubpath()
                    }
                    .fill(Color(hex: "FFAE00"))

                    Circle()
                        .fill(Color(hex: "FFAE00"))
                        .frame(width: knobR * 2, height: knobR * 2)
                        .position(x: w - pad - knobR, y: midY)
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                }
            }
            .frame(height: 56)

            Text("Resize and move to adjust signature")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 16)
    }
}

struct SignatureSlider: View {
    @Binding var value: CGFloat
    var height: CGFloat = 24
    var knobRadius: CGFloat = 16
    var color: Color = Color(hex: "FFAE00")

    private let hPad: CGFloat = 24

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                let W = geo.size.width
                let H = geo.size.height
                let midY = H / 2
                let minX = hPad + knobRadius
                let maxX = W - hPad - knobRadius
                let x = min(max(minX + (maxX - minX) * value, minX), maxX)

                ZStack {
                    TaperTrack(
                        leftX: hPad,
                        rightX: W - hPad,
                        topY: midY - height * 0.35,
                        bottomY: midY + height * 0.35
                    )
                    .fill(color)

                    Circle()
                        .fill(color)
                        .frame(width: knobRadius * 2, height: knobRadius * 2)
                        .overlay(
                            Circle().stroke(
                                Color.init(hex: "DDDDDD"),
                                lineWidth: 4
                            )
                        )
                        .position(x: x, y: midY)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            let clamped = min(max(g.location.x, minX), maxX)
                            value = (clamped - minX) / (maxX - minX)
                        }
                )
            }
            .frame(height: max(height, knobRadius * 2))

            Text("Resize and move to adjust signature")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 16)
    }
}

private struct TaperTrack: Shape {
    let leftX: CGFloat
    let rightX: CGFloat
    let topY: CGFloat
    let bottomY: CGFloat

    func path(in _: CGRect) -> Path {
        var p = Path()
        let midY = (topY + bottomY) / 2

        p.move(to: CGPoint(x: leftX, y: midY - 1))
        p.addLine(to: CGPoint(x: rightX, y: topY))
        p.addLine(to: CGPoint(x: rightX, y: bottomY))
        p.addLine(to: CGPoint(x: leftX, y: midY + 1))
        p.closeSubpath()
        return p
    }
}

struct SignatureSliderDemo: View {
    @State private var v: CGFloat = 0.75
    var body: some View {
        SignatureSlider(value: $v)
            .frame(height: 56)
            .padding()
    }
}

#Preview { SignatureSliderDemo() }

private func aspectFitRect(imageSize: CGSize, in container: CGSize) -> CGRect {
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

private func trimTransparentEdges(_ image: UIImage, threshold: UInt8 = 5)
    -> UIImage
{
    guard let cg = image.cgImage else { return image }
    let w = cg.width
    let h = cg.height
    let bytesPerRow = w * 4
    let cs = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo =
        CGBitmapInfo.byteOrder32Big.rawValue
        | CGImageAlphaInfo.premultipliedLast.rawValue

    guard
        let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: cs,
            bitmapInfo: bitmapInfo
        )
    else { return image }

    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    guard let data = ctx.data else { return image }
    let p = data.bindMemory(to: UInt8.self, capacity: bytesPerRow * h)

    var top = 0
    var bottom = h - 1
    var left = 0
    var right = w - 1
    var found = false

    for y in 0..<h {
        let row = y * bytesPerRow
        for x in 0..<w where p[row + x * 4 + 3] > threshold {
            top = y
            found = true
            break
        }
        if found { break }
    }

    found = false
    for y in stride(from: h - 1, through: 0, by: -1) {
        let row = y * bytesPerRow
        for x in 0..<w where p[row + x * 4 + 3] > threshold {
            bottom = y
            found = true
            break
        }
        if found { break }
    }

    found = false
    for x in 0..<w {
        for y in top...bottom where p[y * bytesPerRow + x * 4 + 3] > threshold {
            left = x
            found = true
            break
        }
        if found { break }
    }

    found = false
    for x in stride(from: w - 1, through: 0, by: -1) {
        for y in top...bottom where p[y * bytesPerRow + x * 4 + 3] > threshold {
            right = x
            found = true
            break
        }
        if found { break }
    }
    if right < left || bottom < top { return image }

    let rect = CGRect(
        x: left,
        y: top,
        width: right - left + 1,
        height: bottom - top + 1
    )
    guard let cropped = cg.cropping(to: rect) else { return image }
    return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
}

private func saveSignaturePNGToDocuments(_ image: UIImage) -> URL? {
    guard let data = image.pngData() else { return nil }
    let fm = FileManager.default
    let dir = try? fm.url(
        for: .documentDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    .appendingPathComponent("Signatures", isDirectory: true)
    guard let dirURL = dir else { return nil }
    if !fm.fileExists(atPath: dirURL.path) {
        try? fm.createDirectory(at: dirURL, withIntermediateDirectories: true)
    }
    var url = dirURL.appendingPathComponent("sign_\(UUID().uuidString).png")
    do {
        try data.write(to: url, options: .atomic)
        var rsrc: URLResourceValues = .init()
        rsrc.isExcludedFromBackup = true
        try? url.setResourceValues(rsrc)
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .signaturesDidChange,
                object: url
            )
        }

        return url
    } catch {
        print("Save error:", error)
        return nil
    }
}
