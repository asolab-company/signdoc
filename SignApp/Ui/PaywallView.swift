import StoreKit
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var iap: IAPManager
    @Environment(\.dismiss) private var dismiss
    var onContinue: () -> Void = {}

    private var product: Product? { iap.products.first }

    private var priceLine: String {
        guard let p = product,
            let sub = p.subscription
        else { return "" }

        let period = sub.subscriptionPeriod
        let price = p.displayPrice
        let unit = periodString(period)

        if let offer = sub.introductoryOffer,
            offer.paymentMode == .freeTrial
        {
            return
                "Try \(periodString(offer.period)) for FREE, then \(price) / \(unit)"
        } else {
            return "\(price) / \(unit)"
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Image("loading_bg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            GeometryReader { geo in
                let horizontalPadding: CGFloat = 24
                let headerH = geo.size.height * (Device.isSmall ? 0.43 : 0.45)

                VStack(spacing: 20) {
                    Image("app_bg_paywall")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: headerH)
                        .ignoresSafeArea(edges: .top)

                    VStack(spacing: 10) {
                        Text("What you get with the app")
                            .foregroundColor(.black)
                            .font(.system(size: 18, weight: .semibold))
                            .padding(.bottom)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 18) {
                            BulletRow("Unlimited signatures")
                            BulletRow("Sign any document")
                            BulletRow("Authentic digital signing")

                            Button(action: { dismiss() }) {
                                HStack(
                                    alignment: .firstTextBaseline,
                                    spacing: 12
                                ) {
                                    Text("Continue with limitations")
                                        .foregroundColor(Color.black)
                                        .font(
                                            .system(size: 18, weight: .regular)
                                        )
                                        .multilineTextAlignment(.leading)
                                        .underline()
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.black)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom)
                        .padding(.leading)

                        if !Device.isSmall {
                            Spacer()
                        }

                        Text(priceLine)
                            .foregroundColor(.black)
                            .font(.system(size: 14, weight: .regular))
                            .multilineTextAlignment(.leading)
                            .padding(.bottom, 5)
                            .redacted(
                                reason: (product == nil
                                    && iap.isLoadingProducts)
                                    ? .placeholder : []
                            )

                        Button(action: continueTapped) {
                            ZStack {
                                if iap.isLoadingProducts {
                                    ProgressView()
                                } else {
                                    Text("Continue").font(
                                        .system(size: 16, weight: .bold)
                                    )
                                }
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
                        .disabled(iap.isLoadingProducts)
                        .padding(.bottom, 5)

                        TermsFooter()
                            .padding(.bottom, Device.isSmall ? 50 : 50)
                    }
                    .padding(.horizontal, horizontalPadding)
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .top
                )
            }
        }
        .onAppear {

            if iap.products.isEmpty && !iap.isLoadingProducts {
                Task { await iap.fetchProducts() }
            }
        }
    }

    private func continueTapped() {

        if iap.isSubscribed {
            onContinue()
            dismiss()
            return
        }

        guard let p = product else {
            Task { await iap.fetchProducts() }
            return
        }

        Task {
            await iap.purchase(product: p)
            if iap.isSubscribed {
                onContinue()
                dismiss()
            }
        }
    }

    private func periodString(_ p: Product.SubscriptionPeriod) -> String {
        switch p.unit {
        case .day: return p.value == 1 ? "day" : "\(p.value) days"
        case .week: return p.value == 1 ? "week" : "\(p.value) weeks"
        case .month: return p.value == 1 ? "month" : "\(p.value) months"
        case .year: return p.value == 1 ? "year" : "\(p.value) years"
        @unknown default: return "period"
        }
    }
}

private struct BulletRow: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(text)
                .foregroundColor(.black)
                .font(.system(size: 18, weight: .regular))
                .multilineTextAlignment(.leading)
            Spacer()
            ZStack {
                Circle()
                    .fill(Color(hex: "#FFAE00"))
                    .frame(width: 20, height: 20)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
            }
        }
        .padding(.horizontal)
    }
}

private struct TermsFooter: View {
    var body: some View {
        HStack(spacing: 0) {
            Link("Privacy Policy", destination: AppLinks.privacyPolicy)
                .font(.footnote)
                .foregroundColor(Color(hex: "8E8E8E"))
            Spacer()
            Link("Terms Of Use", destination: AppLinks.termsOfUse)
                .font(.footnote)
                .foregroundColor(Color(hex: "8E8E8E"))
        }
        .padding(.horizontal, 70)
    }
}

#Preview {
    PaywallView()
        .environmentObject(IAPManager.shared)
}
