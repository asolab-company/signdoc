import SwiftUI

@main
struct SignAppApp: App {
    @StateObject private var overlay = OverlayManager()

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(IAPManager.shared)
                .environmentObject(overlay)
        }
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
