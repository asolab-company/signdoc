import SwiftUI

struct LoadingView: View {
    @State private var progress: CGFloat = 0
    private let progressTrackWidth: CGFloat = 300
    private let progressTrackHeight: CGFloat = 7
    private let minimumProgressDuration: TimeInterval = 2.0

    var body: some View {
        ZStack {
        

            Image("loading")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .center
                )

            VStack(spacing: 12) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.black.opacity(0.3))
                        .frame(width: progressTrackWidth, height: progressTrackHeight)

                    Capsule()
                        .fill(Color(hex: "#FFAE00"))
                        .frame(
                            width: max(0, min(progressTrackWidth, progressTrackWidth * progress)),
                            height: progressTrackHeight
                        )
                }
                .frame(width: progressTrackWidth, height: progressTrackHeight)
            }
            .padding(.bottom, 24)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .bottom
            )
        }
        .background(
            Image("gradient_bg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        )
        .task {
            let startedAt = Date()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000)
                let elapsed = Date().timeIntervalSince(startedAt)
                let normalized = min(1, elapsed / minimumProgressDuration)
                progress = CGFloat(normalized)
            }
        }
    }
}

#Preview {
    LoadingView()
}
