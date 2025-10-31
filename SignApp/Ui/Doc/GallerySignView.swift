import SwiftUI
import UIKit

struct GallerySignView: View {

    var onBack: () -> Void = {}

    @State private var items: [SignItem] = []
    @State private var selection = Set<URL>()
    @State private var isLoading = true

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 3
    )
    private let cellSize: CGFloat = 100

    var body: some View {
        VStack(spacing: 0) {

            ZStack {
                Text("Gallery Signs")
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

                    Button(action: deleteSelected) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                .black.opacity(selection.isEmpty ? 0.35 : 0.8)
                            )
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "trash")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    .disabled(selection.isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Group {
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if items.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Text("No saved signatures yet")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.black.opacity(0.7))
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(items) { item in
                                SignCell(
                                    image: item.thumb ?? UIImage(),
                                    size: cellSize,
                                    selected: selection.contains(item.url)
                                )
                                .onTapGesture {
                                    toggleSelect(item.url)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        selection = [item.url]
                                        deleteSelected()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(12)
                    }
                }
            }
            .onAppear(perform: loadGallery)
        }
        .background(Color.white.ignoresSafeArea())
    }

    private func toggleSelect(_ url: URL) {
        if selection.contains(url) {
            selection.remove(url)
        } else {
            selection.insert(url)
        }
    }

    private func deleteSelected() {
        guard !selection.isEmpty else { return }
        let fm = FileManager.default
        var newItems = items
        for url in selection {
            try? fm.removeItem(at: url)
            newItems.removeAll { $0.url == url }
        }
        selection.removeAll()
        items = newItems
    }

    private func loadGallery() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = loadSignaturesFromDisk(maxThumbSide: 400)
            DispatchQueue.main.async {
                self.items = loaded
                self.isLoading = false
            }
        }
    }
}

private struct SignItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let date: Date
    let thumb: UIImage?
}

private func signaturesDirectory() -> URL? {
    let fm = FileManager.default
    return
        try? fm
        .url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("Signatures", isDirectory: true)
}

private func loadSignaturesFromDisk(maxThumbSide: CGFloat) -> [SignItem] {
    let fm = FileManager.default
    guard let dir = signaturesDirectory(),
        fm.fileExists(atPath: dir.path),
        let urls = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [
                .creationDateKey, .contentModificationDateKey,
            ],
            options: [.skipsHiddenFiles]
        )
    else { return [] }

    let pngs = urls.filter { $0.pathExtension.lowercased() == "png" }
    var result: [SignItem] = []
    result.reserveCapacity(pngs.count)

    for url in pngs {
        let rv = try? url.resourceValues(forKeys: [
            .contentModificationDateKey, .creationDateKey,
        ])
        let date =
            rv?.contentModificationDate ?? rv?.creationDate ?? .distantPast
        let ui = UIImage(contentsOfFile: url.path)
        let thumb = ui?.scaled(maxSide: maxThumbSide)
        result.append(SignItem(url: url, date: date, thumb: thumb))
    }

    return result.sorted { $0.date > $1.date }
}

extension UIImage {
    fileprivate func scaled(maxSide: CGFloat) -> UIImage {
        let maxSide = max(maxSide, 1)
        let w = size.width
        let h = size.height
        guard w > 0, h > 0 else { return self }
        let scaleFactor = min(maxSide / max(w, h), 1)
        if scaleFactor == 1 { return self }

        let newSize = CGSize(width: w * scaleFactor, height: h * scaleFactor)
        let r = UIGraphicsImageRenderer(size: newSize)
        return r.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

private struct SignCell: View {
    let image: UIImage
    let size: CGFloat
    let selected: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
                .frame(width: size, height: size)

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size - 4, height: size - 4)

            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    selected ? Color(hex: "FFAE00") : Color.black.opacity(0.08),
                    lineWidth: selected ? 2 : 1
                )
                .frame(width: size, height: size)

            if selected {
                HStack {
                    Spacer()
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "FFAE00"))
                            .shadow(radius: 2)
                            .padding(6)
                        Spacer()
                    }
                }
                .frame(width: size, height: size)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    GallerySignView()
}
