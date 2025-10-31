import SwiftUI
import VisionKit

struct DocumentScannerPresenter: UIViewControllerRepresentable {
    var onScanCompleted: ([UIImage]) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanCompleted: onScanCompleted, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> PresenterVC {
        let vc = PresenterVC()
        vc.onScanCompleted = onScanCompleted
        vc.onCancel = onCancel
        vc.coordinator = context.coordinator
        return vc
    }

    func updateUIViewController(
        _ uiViewController: PresenterVC,
        context: Context
    ) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate,
        UIAdaptivePresentationControllerDelegate
    {
        let onScanCompleted: ([UIImage]) -> Void
        let onCancel: () -> Void
        private var signalled = false

        init(
            onScanCompleted: @escaping ([UIImage]) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.onScanCompleted = onScanCompleted
            self.onCancel = onCancel
        }

        private func signalCancelOnce() {
            guard !signalled else { return }
            signalled = true
            onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            onScanCompleted(images)
        }

        func documentCameraViewControllerDidCancel(
            _ controller: VNDocumentCameraViewController
        ) {
            signalCancelOnce()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            signalCancelOnce()
        }

        func presentationControllerDidDismiss(
            _ presentationController: UIPresentationController
        ) {
            signalCancelOnce()
        }
    }

    final class PresenterVC: UIViewController {
        var onScanCompleted: (([UIImage]) -> Void)?
        var onCancel: (() -> Void)?
        weak var coordinator: Coordinator?
        private var didPresent = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !didPresent else { return }
            didPresent = true

            let scanner = VNDocumentCameraViewController()
            scanner.delegate = coordinator
            scanner.modalPresentationStyle = .fullScreen
            scanner.view.backgroundColor = .black
            scanner.presentationController?.delegate = coordinator

            present(scanner, animated: false)
        }
    }
}
