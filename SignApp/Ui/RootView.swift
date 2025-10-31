import SwiftUI

struct RootView: View {
    @EnvironmentObject var iap: IAPManager
    @EnvironmentObject var overlay: OverlayManager

    enum Phase { case splash, onboarding, menu }

    @State private var phase: Phase = .splash
    @State private var path: [Route] = []

    @AppStorage("didShowOnboarding") private var didShowOnboarding = false

    var body: some View {
        content
            .navigationBarBackButtonHidden(true)
            .environmentObject(iap)
            .environmentObject(overlay)

            .fullScreenCover(
                isPresented: Binding(
                    get: { overlay.showPaywall && phase == .menu },
                    set: { overlay.showPaywall = $0 }
                ),
                onDismiss: { phase = .menu }
            ) {
                PaywallView(onContinue: {
                    overlay.showPaywall = false
                    phase = .menu
                })
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
            Loading()

                .task {

                    try? await Task.sleep(nanoseconds: 1_600_000_000)

                    if didShowOnboarding {
                        phase = .menu
                        if !iap.isSubscribed { overlay.showPaywall = true }
                    } else {
                        phase = .onboarding
                    }
                }

        case .onboarding:
            OnBoardingView(onFinish: {
                didShowOnboarding = true
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
                                LOG(
                                    "ROOT",
                                    "from .signDocuments → open ScanView(.signature)"
                                )
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
                                LOG(
                                    "ROOT",
                                    "from .scanDocuments → open ScanView(.signature)"
                                )
                                safePop()
                                DispatchQueue.main.asyncAfter(
                                    deadline: .now() + 0.1
                                ) {
                                    LOG(
                                        "ROOT",
                                        "push .createSignature (after pop)"
                                    )
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
        LOG("ROOT", "safePop(\(n)) — path.count=\(path.count)")
        guard n > 0, path.count >= n else {
            LOG("ROOT", "safePop blocked (insufficient stack)")
            return
        }
        path.removeLast(n)
        LOG("ROOT", "after pop — path.count=\(path.count)")
    }
}

enum Route: Hashable {
    case settings, createSignature, signDocuments, scanDocuments
}
