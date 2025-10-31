import SwiftUI

struct MenuView: View {
    let onSettings: () -> Void
    let onCreateSignature: () -> Void
    let onSignDocuments: () -> Void
    let onScanDocuments: () -> Void

    @EnvironmentObject var iap: IAPManager
    @EnvironmentObject var overlay: OverlayManager

    var body: some View {
        ZStack {

            VStack(spacing: 20) {
                HStack {
                    if !iap.isSubscribed {
                        Button(action: { overlay.show() }) {
                            RoundedRectangle(
                                cornerRadius: 10,
                                style: .continuous
                            )
                            .fill(Color.init(hex: "FFAE00"))
                            .frame(width: 74, height: 36)
                            .overlay(
                                HStack(spacing: 5) {
                                    Image("app_ic_vip")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 22, height: 22)

                                    Text("Pro")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            )
                        }
                    }
                    Spacer()
                    Button(action: onSettings) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.black.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image("ic_settings")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                            )
                    }

                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                let locked = !iap.isSubscribed

                FeatureButton(
                    iconName: "menu_ic_1",
                    title: "Scan new document",
                    isLocked: false,
                    onLocked: { overlay.show() },
                    action: { onScanDocuments() }
                )

                FeatureButton(
                    iconName: "menu_ic_2",
                    title: "Sign document (PDF)",
                    isLocked: locked,
                    onLocked: { overlay.show() },
                    action: { onSignDocuments() }
                )

                FeatureButton(
                    iconName: "menu_ic_3",
                    title: "Create signature",
                    isLocked: locked,
                    onLocked: { overlay.show() },
                    action: { onCreateSignature() }
                )

                Spacer()
                Spacer()
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(
            Image("app_bg_main")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        )
    }
}

struct FeatureButton: View {
    let iconName: String
    let title: String
    let isLocked: Bool
    var onLocked: () -> Void = {}
    var action: () -> Void = {}

    var body: some View {
        Button {
            if isLocked {
                onLocked()
            } else {
                action()
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 16) {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 45, height: 52)
                        .padding(.leading)

                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)

                    Spacer()
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "#FFAE00"))
                )
                .opacity(isLocked ? 0.8 : 1)

                if isLocked {
                    Image("app_ic_lock")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .padding(14)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MenuView(
        onSettings: {},
        onCreateSignature: {},
        onSignDocuments: {},
        onScanDocuments: {}
    )
}
