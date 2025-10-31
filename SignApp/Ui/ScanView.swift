import AVFoundation
import SwiftUI
import VisionKit

extension Transaction {
    static var noAnimation: Transaction {
        var t = Transaction()
        t.animation = nil
        t.disablesAnimations = true
        return t
    }
}

@inline(__always)
func withoutAnimation(_ updates: () -> Void) {
    withTransaction(.noAnimation) { updates() }
}

@inline(__always)
func withoutUIKitAnimation(_ updates: () -> Void) {
    let enabled = UIView.areAnimationsEnabled
    UIView.setAnimationsEnabled(false)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    updates()
    CATransaction.commit()
    UIView.setAnimationsEnabled(enabled)
}

enum ScanKind {
    case document
    case signature
}

struct ScanView: View {

    let kind: ScanKind
    let onClose: () -> Void
    var onOpenSignatureFlow: () -> Void = {}
    @State private var pendingOpenSignature = false

    @Environment(\.scenePhase) private var scenePhase
    @State private var showScanner = false

    @State private var cameraStatus: AVAuthorizationStatus =
        AVCaptureDevice.authorizationStatus(for: .video)

    @State private var scannedPage: ScannedPage?

    private var bgColor: Color {
        cameraStatus == .authorized ? .black : Color.init(hex: "DDDDDD")
    }

    var body: some View {
        ZStack {

            bgColor.ignoresSafeArea()

            VStack(spacing: 20) {

                HStack {
                    if cameraStatus != .authorized {
                        Button(action: onClose) {
                            RoundedRectangle(
                                cornerRadius: 10,
                                style: .continuous
                            )
                            .fill(.black.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                if cameraStatus != .authorized {
                    AccessPrompt(
                        title: "Allow Camera\nAccess",
                        subtitle:
                            "Use your camera to scan\nand enhance documents",
                        primaryTitle: (cameraStatus == .denied
                            ? "Settings" : "Continue"),
                        primaryAction: {
                            if cameraStatus == .denied {
                                openAppSettings()
                            } else {
                                requestCameraAccess()
                            }
                        },
                        background: bgColor
                    )
                    .padding(.horizontal, 16)
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }

        .transaction { t in
            t.animation = nil
            t.disablesAnimations = true
        }

        .animation(nil, value: showScanner)
        .animation(nil, value: scannedPage?.id)
        .animation(nil, value: cameraStatus)
        .animation(nil, value: scenePhase)

        .onAppear {
            LOG("SCAN", "appear kind=\(kind)")
            refreshCameraStatus()
            LOG("SCAN", "camera=\(cameraStatus.rawValue)")
            if cameraStatus == .authorized {
                LOG("SCAN", "show scanner (onAppear)")
                withoutUIKitAnimation {
                    withoutAnimation { showScanner = true }
                }
            }
        }
        .onChange(of: cameraStatus) { newValue in
            LOG("SCAN", "camera changed -> \(newValue.rawValue)")
            if newValue == .authorized {
                LOG("SCAN", "show scanner (onChange)")
                withoutUIKitAnimation {
                    withoutAnimation { showScanner = true }
                }
            }
        }

        .fullScreenCover(isPresented: $showScanner) {
            ZStack {
                Color.black.ignoresSafeArea()
                DocumentScannerPresenter(
                    onScanCompleted: { images in
                        LOG("SCAN", "onScanCompleted images=\(images.count)")
                        guard !images.isEmpty else {
                            LOG("SCAN", "empty images, ignore")
                            return
                        }
                        withoutUIKitAnimation {
                            withoutAnimation {
                                scannedPage = ScannedPage(images: images)
                                LOG("SCAN", "set scannedPage, close scanner")
                            }
                            withoutAnimation { showScanner = false }
                        }
                    },
                    onCancel: {
                        LOG(
                            "SCAN",
                            "scanner cancel -> close scanner & onClose()"
                        )
                        withoutUIKitAnimation {
                            withoutAnimation { showScanner = false }
                        }
                        onClose()
                    }
                )
                .transaction { t in
                    t.animation = nil
                    t.disablesAnimations = true
                }
            }

            .transaction { t in
                t.animation = nil
                t.disablesAnimations = true
            }
            .background(bgColor)
        }
        .interactiveDismissDisabled(true)

        .fullScreenCover(
            item: $scannedPage,
            onDismiss: {
                LOG(
                    "SCAN",
                    "editor dismissed, pendingOpenSignature=\(pendingOpenSignature)"
                )
                let shouldOpenSignature = pendingOpenSignature
                pendingOpenSignature = false

                if shouldOpenSignature {
                    LOG("SCAN", "notify Root to open signature flow")
                    DispatchQueue.main.async { onOpenSignatureFlow() }
                } else {
                    LOG("SCAN", "normal close")
                    onClose()
                }
            }
        ) { page in
            Group {
                switch kind {
                case .document:
                    EditDocFlow(
                        images: page.images,
                        onClose: {
                            LOG("SCAN", "EditDocFlow.onClose -> dismiss editor")
                            scannedPage = nil
                        },
                        onScanNew: {
                            LOG(
                                "SCAN",
                                "EditDocFlow.onScanNew -> reopen scanner"
                            )
                            scannedPage = nil
                            showScanner = true
                        },
                        onOpenSignatureScanner: {
                            LOG(
                                "SCAN",
                                "EditDocFlow.onOpenSignatureScanner -> dismiss editor & schedule switch"
                            )
                            pendingOpenSignature = true
                            scannedPage = nil
                        }
                    )

                case .signature:
                    EditSignFlow(
                        images: page.images,
                        onClose: {
                            LOG(
                                "SCAN",
                                "EditSignFlow.onClose -> dismiss editor"
                            )
                            scannedPage = nil
                        },
                        onScanNew: {
                            LOG(
                                "SCAN",
                                "EditSignFlow.onScanNew -> reopen scanner"
                            )
                            scannedPage = nil
                            showScanner = true
                        }
                    )
                }
            }
            .background(bgColor.ignoresSafeArea())
            .transaction { t in
                t.animation = nil
                t.disablesAnimations = true
            }
        }
        .interactiveDismissDisabled(true)

    }

    private func refreshCameraStatus() {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        print("🔍 Refreshed camera status = \(cameraStatus.rawValue)")
    }

    private func requestCameraAccess() {
        AVCaptureDevice.requestAccess(for: .video) { _ in
            DispatchQueue.main.async { self.refreshCameraStatus() }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }
}

struct ScannedPage: Identifiable, Equatable {
    let id = UUID()
    let images: [UIImage]
    static func == (lhs: ScannedPage, rhs: ScannedPage) -> Bool {
        lhs.id == rhs.id
    }
}

private struct AccessPrompt: View {
    let title: String
    let subtitle: String
    let primaryTitle: String
    let primaryAction: () -> Void
    let background: Color

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            VStack(spacing: 10) {
                Spacer()
                Image("app_ic_no photo")
                    .resizable().scaledToFit()
                    .frame(width: 150, height: 150)

                Text(title)
                    .font(.system(size: 32, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)

                Text(subtitle)
                    .font(.system(size: 16, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black.opacity(0.9))

                Spacer()

                Button(action: primaryAction) {
                    ZStack {
                        Text(primaryTitle)
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
                .padding(.bottom, 5)
            }
            .padding(.bottom)
        }
        .transaction { t in
            t.animation = nil
            t.disablesAnimations = true
        }
    }
}

#Preview {

    ScanView(kind: .document, onClose: {})

}
