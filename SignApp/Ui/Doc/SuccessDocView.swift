import SwiftUI

struct SuccessDocView: View {
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

                VStack(spacing: 0) {

                    VStack(spacing: 10) {

                        Spacer()
                        Spacer()

                        Text("Great")
                            .font(.system(size: 48, weight: .heavy))
                            .foregroundColor(.black)

                        ZStack {

                            Image("app_ic_wealth")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 327, height: 155)
                        }

                        Text("The document was saved successfully!")
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
                                    "Scan new document"
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

#Preview {
    SuccessDocView(
        onMenu: {},
        onScanNew: {}
    )
}
