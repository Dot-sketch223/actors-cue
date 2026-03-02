import SwiftUI

struct SplashView: View {
    @State private var glowScale: CGFloat = 0.7
    @State private var glowOpacity: Double = 0.0
    @State private var contentOpacity: Double = 0.0

    var body: some View {
        ZStack {
            Color(red: 12 / 255, green: 12 / 255, blue: 22 / 255)
                .ignoresSafeArea()

            // Warm amber glow
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.72, blue: 0.18).opacity(0.55),
                    Color(red: 1.0, green: 0.45, blue: 0.08).opacity(0.25),
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 260
            )
            .frame(width: 520, height: 520)
            .scaleEffect(glowScale)
            .opacity(glowOpacity)

            VStack(spacing: 22) {
                // Mic icon
                Image(systemName: "microphone.fill")
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                .white,
                                Color(red: 1.0, green: 0.88, blue: 0.62)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(spacing: 6) {
                    Text("Actor's Cue")
                        .font(.system(size: 34, weight: .thin, design: .serif))
                        .foregroundColor(.white)

                    Text("KNOW YOUR LINES")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(.white.opacity(0.4))
                        .kerning(3.5)
                }
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                glowScale = 1.0
                glowOpacity = 1.0
                contentOpacity = 1.0
            }
        }
    }
}
