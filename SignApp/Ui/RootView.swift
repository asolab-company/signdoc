import SwiftUI

struct RootView: View {
    @EnvironmentObject var iap: IAPManager
    @EnvironmentObject var overlay: OverlayManager

    enum Phase { case splash, onboarding, menu }

    @State private var phase: Phase = .splash
    @State private var path: [Route] = []

    var body: some View {
        content
            .navigationBarBackButtonHidden(true)
            .environmentObject(iap)
            .environmentObject(overlay)
            .fullScreenCover(
                isPresented: $overlay.showPaywall,
                onDismiss: { phase = .menu }
            ) {
                PaywallView(
                    onContinue: {
                        overlay.showPaywall = false
                        phase = .menu
                    }
                )
                .environmentObject(iap)
                .environmentObject(overlay)
            }

            .onChange(of: iap.isSubscribed) { sub in
                if sub { overlay.showPaywall = false }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .splash:
            LoadingView()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        let didShow = UserDefaults.standard.bool(
                            forKey: "didShowOnboarding"
                        )
                        if didShow {

                            phase = .menu
                            if !iap.isSubscribed { overlay.showPaywall = true }
                        } else {
                            phase = .onboarding
                        }
                    }
                }

        case .onboarding:
            OnBoardingView(onFinish: {
                UserDefaults.standard.set(true, forKey: "didShowOnboarding")

                phase = .menu
                if !iap.isSubscribed { overlay.showPaywall = true }
            })

        case .menu:
            NavigationStack(path: $path) {
                MenuView(
                    onSettings: { path.append(.settings) },
                    onCreateSignature: { path.append(.createSignature) },
                    onSignDocuments: { path.append(.signDocuments) },
                    onScanDocuments: { path.append(.scanDocuments) }
                )
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .settings:
                        SettingsView(onClose: { safePop() })
                            .navigationBarBackButtonHidden(true)

                    case .createSignature:
                        ScanView(kind: .signature, onClose: { safePop() })
                            .navigationBarBackButtonHidden(true)

                    case .signDocuments:
                        PDFSignView(
                            onClose: { safePop() },
                            onOpenSignatureFlow: {

                                safePop()
                                DispatchQueue.main.asyncAfter(
                                    deadline: .now() + 0.1
                                ) {
                                    path.append(.createSignature)
                                }
                            }
                        )
                        .navigationBarBackButtonHidden(true)

                    case .scanDocuments:
                        ScanView(
                            kind: .document,
                            onClose: { safePop() },
                            onOpenSignatureFlow: {

                                safePop()
                                DispatchQueue.main.asyncAfter(
                                    deadline: .now() + 0.1
                                ) {

                                    path.append(.createSignature)
                                }
                            }
                        )
                        .navigationBarBackButtonHidden(true)
                    }
                }
            }
        }
    }

    private func safePop(_ n: Int = 1) {

        guard n > 0, path.count >= n else {

            return
        }
        path.removeLast(n)

    }
}

enum Route: Hashable {
    case settings
    case createSignature
    case signDocuments
    case scanDocuments
}
