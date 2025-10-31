import SwiftUI

struct SuccessSignView: View {
    let image: UIImage
    var onMenu: () -> Void
    var onScanNew: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Image("loading_bg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            GeometryReader { geo in
                let horizontalPadding: CGFloat = 24
                let safeBottom = geo.safeAreaInsets.bottom

                VStack(spacing: 0) {

                    VStack(spacing: 10) {

                        Spacer()
                        Spacer()

                        Text("Great")
                            .font(.system(size: 48, weight: .heavy))
                            .foregroundColor(.black)
                            .offset(y: -70)

                        ZStack {

                            ZStack {
                                CheckerboardBackground(size: 8)
                                    .frame(width: 104, height: 104)

                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(hex: "FFAE00"), lineWidth: 1)
                            )
                            .offset(y: -70)
                            Image("app_ic_wealth")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 327, height: 155)
                        }

                        Text("The sign was saved successfully!")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.black)

                        Spacer()

                        Button(action: { onMenu() }) {
                            ZStack {
                                Text(
                                    "Return to menu"
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
                        .buttonStyle(BackCTAStyle())
                        .padding(.bottom, 5)
                        Button(action: { onScanNew() }) {
                            ZStack {
                                Text(
                                    "Scan new signature"
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

                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 100)
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

struct BackCTAStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#BB4800"), Color(hex: "#BB4800"),
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
    SuccessSignView(
        image: UIImage(named: "app_ic_wealth") ?? UIImage(),
        onMenu: {},
        onScanNew: {}
    )
}
