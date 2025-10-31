import SwiftUI

struct SettingsView: View {
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var overlay: OverlayManager
    @EnvironmentObject var iap: IAPManager
    @Environment(\.openURL) private var openURL
    @State private var showShare = false

    var body: some View {
        ZStack {
            Color(hex: "#DDDDDD")
                .ignoresSafeArea()

            GeometryReader { geo in

                VStack(spacing: 20) {
                    HStack {
                        Button {
                            if let onClose { onClose() } else { dismiss() }
                        } label: {
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
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    if !iap.isSubscribed {
                        Button(action: { overlay.show() }) {
                            HStack(spacing: 14) {

                                Image("app_ic_vip")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 88, height: 88)

                                (Text("Get ") + Text("Pro").fontWeight(.heavy)
                                    + Text(" Version"))
                                    .font(.system(size: 20, weight: .regular))
                                    .foregroundColor(.black)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 20)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: 18,
                                    style: .continuous
                                )
                                .fill(Color(hex: "#FFAE00"))
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }

                    VStack(spacing: 16) {
                        SettingsRow(
                            icon: "app_ic_share",
                            title: "Share app",
                            onTap: { showShare = true }
                        )

                        SettingsRow(
                            icon: "app_ic_terms",
                            title: "Terms and Conditions",
                            onTap: { openURL(AppLinks.termsOfUse) }
                        )

                        SettingsRow(
                            icon: "app_ic_privacy",
                            title: "Privacy",
                            onTap: { openURL(AppLinks.privacyPolicy) }
                        )
                        if !iap.isSubscribed {
                            SettingsRow(
                                icon: "app_ic_restore",
                                title: "Restore Purchases",
                                onTap: {
                                    Task {
                                        await iap.restore()
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .top
                )

            }
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: AppLinks.shareItems)
        }
    }

}

private struct SettingsRow: View {
    let icon: String
    let title: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(Color(hex: "#FFAE00"))
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: "#000000").opacity(0.8))
            )
        }
        .buttonStyle(.plain)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
    }
    func updateUIViewController(
        _ vc: UIActivityViewController,
        context: Context
    ) {}
}

#Preview {
    SettingsView()
        .environmentObject(IAPManager.shared)
        .environmentObject(OverlayManager())
}
