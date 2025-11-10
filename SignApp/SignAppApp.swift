import AppTrackingTransparency
import AppsFlyerLib
import SwiftUI

extension Notification.Name {
    static let requestATT = Notification.Name("com.signapp.requestATT")
}

@main
struct SignAppApp: App {
    @StateObject private var overlay = OverlayManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(IAPManager.shared)
                .environmentObject(overlay)

                .onOpenURL { url in
                    AppsFlyerLib.shared().handleOpen(url, options: [:])
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { ua in
                    AppsFlyerLib.shared().continue(ua, restorationHandler: nil)
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        appDelegate.handleSceneDidBecomeActive()
                    }
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {

    private let devKey = "cSRFayvDVGvzuDdmHNu9BZ"
    private let appID = "6753080957"
    private var hasStartedAF = false

    private func startAppsFlyerIfNeeded(reason: String) {
        guard !hasStartedAF else {

            return
        }
        AppsFlyerLib.shared().start()
        hasStartedAF = true

    }

    func handleSceneDidBecomeActive() {

        if #available(iOS 14, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus

            if status == .notDetermined {

                requestATTAndStart()
            } else {
                startAppsFlyerIfNeeded(
                    reason:
                        "scenePhase .active with decided ATT (\(status.rawValue))"
                )
            }
        } else {
            startAppsFlyerIfNeeded(reason: "scenePhase .active on iOS < 14")
        }
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication
            .LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        let af = AppsFlyerLib.shared()
        af.appsFlyerDevKey = devKey
        af.appleAppID = appID
        af.isDebug = false

        af.delegate = self
        af.waitForATTUserAuthorization(timeoutInterval: 60)

        // Listen for a post-Onboarding signal to request ATT when UI is visible
        NotificationCenter.default.addObserver(
            forName: .requestATT,
            object: nil,
            queue: .main
        ) { [weak self] _ in

            self?.requestATTAndStart()
        }

        return true
    }

    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: .requestATT,
            object: nil
        )
    }

    private func requestATTAndStart() {
        guard #available(iOS 14, *) else {
            startAppsFlyerIfNeeded(reason: "iOS < 14 — no ATT")
            return
        }

        let status = ATTrackingManager.trackingAuthorizationStatus

        switch status {
        case .notDetermined:

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ATTrackingManager.requestTrackingAuthorization { _ in
                    DispatchQueue.main.async {
                        let newStatus = ATTrackingManager
                            .trackingAuthorizationStatus

                        self.startAppsFlyerIfNeeded(reason: "after ATT prompt")
                    }
                }
            }

        case .authorized, .denied, .restricted:

            startAppsFlyerIfNeeded(
                reason: "ATT already decided (\(status.rawValue))"
            )

        @unknown default:

            startAppsFlyerIfNeeded(reason: "unknown ATT status")
        }
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        AppsFlyerLib.shared().handleOpen(url, options: options)
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {

        if #available(iOS 14, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus

            if status == .notDetermined {

                requestATTAndStart()
            } else {
                startAppsFlyerIfNeeded(
                    reason:
                        "didBecomeActive with decided ATT (\(status.rawValue))"
                )
            }
        } else {
            startAppsFlyerIfNeeded(reason: "didBecomeActive on iOS < 14")
        }
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
        return true
    }
}

extension AppDelegate: AppsFlyerLibDelegate {

    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        LOG("AF", "onConversionDataSuccess: \(data)")
    }
    func onConversionDataFail(_ error: Error) {
        LOG("AF", "onConversionDataFail: \(error.localizedDescription)")
    }

    func onAppOpenAttribution(_ attributionData: [AnyHashable: Any]) {
        LOG("AF", "onAppOpenAttribution: \(attributionData)")
    }
    func onAppOpenAttributionFailure(_ error: Error) {
        LOG("AF", "onAppOpenAttributionFailure: \(error.localizedDescription)")
    }
}

@inline(__always)
func LOG(
    _ tag: String,
    _ msg: String,
    file: String = #fileID,
    line: Int = #line,
    funcName: String = #function
) {
    print("📍[\(tag)] \(msg)  — \(file)#\(line) \(funcName)")
}
