import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            Image("loading_bg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            GeometryReader { geo in
                let horizontalPadding: CGFloat = 24

                Image("app_ic_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width - horizontalPadding * 10)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .center
                    )
            }
        }
    }
}

#Preview {
    LoadingView()
}
