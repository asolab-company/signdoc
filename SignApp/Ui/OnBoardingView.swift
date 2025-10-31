import SwiftUI

struct OnBoardingView: View {

    struct Page: Identifiable, Hashable {
        let id = UUID()
        let imageName: String
        let title: String
        let subtitle: String
    }

    private let pages: [Page] = [
        .init(
            imageName: "onb_1",
            title: "Instant scan",
            subtitle: "Get a clean, sharp\ndocument in seconds."
        ),
        .init(
            imageName: "onb_2",
            title: "Unique signature",
            subtitle:
                "Design your own digital signature or stamp — \nonly yours."
        ),
        .init(
            imageName: "onb_3",
            title: "One tap to finish",
            subtitle: "Save and share\ndocuments effortlessly."
        ),
    ]

    @State private var pageIndex = 0

    var onFinish: () -> Void

    init(onFinish: @escaping () -> Void = {}) {
        self.onFinish = onFinish

        UIPageControl.appearance().backgroundStyle = .minimal
        UIPageControl.appearance().backgroundColor = .clear
        UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(
            Color(hex: "#FFAE00")
        )
        UIPageControl.appearance().pageIndicatorTintColor = UIColor(
            Color(hex: "#8E8E8E")
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            Image("loading_bg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            GeometryReader { geo in
                let horizontalPadding: CGFloat = 24
                let safeBottom = geo.safeAreaInsets.bottom

                let footerMinHeight: CGFloat =
                    (Device.isSmall ? 200 : 180) + safeBottom

                VStack(spacing: 0) {

                    TabView(selection: $pageIndex) {
                        ForEach(Array(pages.enumerated()), id: \.offset) {
                            idx,
                            page in
                            OnboardingSlideView(
                                imageName: page.imageName,
                                title: page.title,
                                subtitle: page.subtitle,
                                headerHeight: geo.size.height
                                    * (Device.isSmall ? 0.52 : 0.54),
                                horizontalPadding: horizontalPadding
                            )
                            .tag(idx)
                        }
                    }
                    .ignoresSafeArea(edges: .top)
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .indexViewStyle(.page(backgroundDisplayMode: .interactive))
                    .frame(height: max(0, geo.size.height - footerMinHeight))

                    VStack(spacing: 10) {

                        if !Device.isSmall {
                            Spacer().frame(height: 16)
                        }

                        Button(action: {
                            if pageIndex == pages.count - 1 {
                                onFinish()
                            } else {
                                withAnimation(.easeInOut) { pageIndex += 1 }
                            }
                        }) {
                            ZStack {
                                Text(
                                    pageIndex == pages.count - 1
                                        ? "Continue" : "Next"
                                )
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

                        TermsFooter()
                            .padding(.horizontal, 50)
                            .padding(.bottom, 50)
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
    }
}

private struct OnboardingSlideView: View {
    let imageName: String
    let title: String
    let subtitle: String
    let headerHeight: CGFloat
    let horizontalPadding: CGFloat

    var body: some View {
        VStack(spacing: 20) {

            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: headerHeight)
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 10) {
                Text(title)
                    .foregroundColor(.black)
                    .font(.system(size: 32, weight: .heavy))
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(subtitle)
                    .foregroundColor(.black)
                    .font(.system(size: 16, weight: .regular))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, horizontalPadding)

            if !Device.isSmall {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
private struct TermsFooter: View {
    var body: some View {
        VStack(spacing: 2) {
            Text("By Proceeding You Accept")
                .foregroundColor(Color.init(hex: "8E8E8E"))
                .font(.footnote)

            HStack(spacing: 0) {
                Text("Our ")
                    .foregroundColor(Color.init(hex: "8E8E8E"))
                    .font(.footnote)

                Link("Terms Of Use", destination: AppLinks.termsOfUse)
                    .font(.footnote)
                    .foregroundColor(Color.init(hex: "FF5500"))
                    .underline()

                Text(" And ")
                    .foregroundColor(Color.init(hex: "8E8E8E"))
                    .font(.footnote)

                Link("Privacy Policy", destination: AppLinks.privacyPolicy)
                    .font(.footnote)
                    .foregroundColor(Color.init(hex: "FF5500"))
                    .underline()
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
}

struct GreenCTAStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#FFAE00"), Color(hex: "#FFAE00"),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .foregroundColor(.black)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        Color.white.opacity(
                            configuration.isPressed ? 0.25 : 0.12
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

#Preview {
    OnBoardingView(onFinish: {})
}
