import SwiftUI

struct Loading: View {
    @State private var progress: CGFloat = 0.0
    @State private var isFinished = false
    @State private var timer: Timer? = nil

    private let duration: Double = 1.5

    var body: some View {
        ZStack {

            GeometryReader { geo in
                let horizontalPadding: CGFloat = 40
                let barWidth = geo.size.width - horizontalPadding * 4

                VStack(spacing: 28) {
                    Spacer()

                    Image("app_ic_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width - horizontalPadding * 5)

                    Spacer()

                    VStack(spacing: 10) {
                        Text("\(Int(progress * 100))%")
                            .foregroundColor(.black)
                            .font(.system(size: 16, weight: .bold))
                            .monospacedDigit()

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(hex: "000000"))
                                .frame(width: barWidth, height: 8)

                            Capsule()
                                .fill(Color(hex: "#FFAE00"))
                                .frame(
                                    width: max(
                                        0,
                                        min(barWidth * progress, barWidth)
                                    ),
                                    height: 8
                                )
                        }
                    }
                    .padding(.bottom, 60)
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .top
                )
                .padding(.horizontal, horizontalPadding)
            }
        }
        .background(
            Image("loading_bg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        )
        .onAppear {
            startProgress()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func startProgress() {
        progress = 0
        timer?.invalidate()

        let stepCount = 100
        let interval = duration / Double(stepCount)
        var tick = 0

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true)
        { t in
            tick += 1
            progress = min(1.0, CGFloat(tick) / CGFloat(stepCount))

            if tick >= stepCount {
                t.invalidate()
                isFinished = true

            }
        }

        RunLoop.main.add(timer!, forMode: .common)
    }
}

#Preview {
    Loading()
}
