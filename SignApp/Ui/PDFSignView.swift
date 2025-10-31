import PDFKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PDFSignView: View {
    var onClose: () -> Void
    var onOpenSignatureFlow: () -> Void

    @State private var images: [UIImage] = []
    @State private var showImporter = true
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        ZStack {
            Color(hex: "DDDDDD")
                .ignoresSafeArea()
            Group {
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading PDF…")
                        Spacer()
                    }
                } else if let err = errorText {
                    VStack(spacing: 12) {
                        Text(err).foregroundColor(.red)
                        Button("Close", action: onClose)
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if images.isEmpty {

                    Color.clear
                        .onAppear { showImporter = true }
                } else {

                    SignView(
                        images: images,
                        onBack: onClose,
                        onCreateSignature: onOpenSignatureFlow
                    )
                    .navigationBarBackButtonHidden(true)
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    LOG("PDF", "no url returned")
                    onClose()
                    return
                }
                loadPDF(url)
            case .failure(let err):

                LOG("PDF", "import failed/cancelled: \(err)")
                onClose()
            }
        }
        .onChange(of: showImporter) { presented in

            if presented == false, images.isEmpty, isLoading == false {
                LOG("PDF", "import closed with no selection → back")
                onClose()
            }
        }
    }

    private func loadPDF(_ pickerURL: URL) {
        isLoading = true
        errorText = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            var localURL: URL?

            let didAccess = pickerURL.startAccessingSecurityScopedResource()
            defer {
                if didAccess { pickerURL.stopAccessingSecurityScopedResource() }
            }

            let coord = NSFileCoordinator()
            var coordError: NSError?
            coord.coordinate(
                readingItemAt: pickerURL,
                options: [],
                error: &coordError
            ) { readURL in

                if (try? readURL.resourceValues(forKeys: [.isUbiquitousItemKey]))?
                    .isUbiquitousItem == true
                {
                    try? fm.startDownloadingUbiquitousItem(at: readURL)
                    var attempts = 0
                    while attempts < 50 {
                        let rv = try? readURL.resourceValues(forKeys: [
                            .ubiquitousItemDownloadingStatusKey
                        ])
                        let status = rv?.ubiquitousItemDownloadingStatus
                        if status == URLUbiquitousItemDownloadingStatus.current
                            || status
                                == URLUbiquitousItemDownloadingStatus.downloaded
                        {
                            break
                        }
                        Thread.sleep(forTimeInterval: 0.1)
                        attempts += 1
                    }
                }

                let dest = fm.temporaryDirectory.appendingPathComponent(
                    "import-\(UUID().uuidString).pdf"
                )
                try? fm.removeItem(at: dest)
                do {
                    try fm.copyItem(at: readURL, to: dest)
                    localURL = dest
                } catch {
                    LOG("PDF", "copy to sandbox failed: \(error)")
                }
            }

            if let e = coordError {
                LOG("PDF", "coordination error: \(e)")
            }

            guard let safeURL = localURL else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorText = "Failed to access the selected file."
                    onClose()
                }
                return
            }

            guard let doc = CGPDFDocument(safeURL as CFURL) else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorText = "Failed to read PDF pages."
                    onClose()
                }
                return
            }

            var out: [UIImage] = []
            let pageCount = doc.numberOfPages
            for idx in 1...pageCount {
                guard let page = doc.page(at: idx) else { continue }
                let media = page.getBoxRect(.mediaBox)

                let scale: CGFloat = 2.0
                let size = CGSize(
                    width: max(media.width, 1) * scale,
                    height: max(media.height, 1) * scale
                )

                let img = UIGraphicsImageRenderer(size: size).image { ctx in
                    UIColor.white.setFill()
                    ctx.fill(CGRect(origin: .zero, size: size))

                    ctx.cgContext.saveGState()

                    ctx.cgContext.translateBy(x: 0, y: size.height)
                    ctx.cgContext.scaleBy(x: scale, y: -scale)
                    ctx.cgContext.drawPDFPage(page)
                    ctx.cgContext.restoreGState()
                }
                out.append(img)
            }

            DispatchQueue.main.async {
                self.isLoading = false
                if out.isEmpty {
                    LOG("PDF", "no pages rendered")
                    self.errorText = "Failed to render PDF pages."
                    onClose()
                } else {
                    self.images = out
                }
            }
        }
    }
}

extension PDFSignView {

    fileprivate func pdfPagesAsImages(url: URL, maxDimension: CGFloat = 1800)
        -> [UIImage]
    {
        guard let doc = PDFDocument(url: url) else { return [] }
        var result: [UIImage] = []
        result.reserveCapacity(doc.pageCount)

        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let box = page.bounds(for: .mediaBox)
            let longest = max(box.width, box.height)
            let scale = max(1.0, min(maxDimension / max(longest, 1), 4.0))
            let targetSize = CGSize(
                width: box.width * scale,
                height: box.height * scale
            )

            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            let renderer = UIGraphicsImageRenderer(
                size: targetSize,
                format: format
            )

            let img = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: targetSize))
                let cg = ctx.cgContext
                cg.saveGState()

                cg.scaleBy(x: scale, y: scale)
                page.draw(with: .mediaBox, to: cg)
                cg.restoreGState()
            }
            result.append(img)
        }
        return result
    }
}
