import Combine
import SwiftUI

final class OverlayManager: ObservableObject {
    @Published var showPaywall: Bool = false

    var isOverlayActive: Bool { showPaywall }

    func show() { showPaywall = true }
    func hide() { showPaywall = false }
}
