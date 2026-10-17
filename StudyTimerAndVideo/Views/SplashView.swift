import SwiftUI

// 09 スプラッシュ。空と雲の中に、StudyReel とひとこと
struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.918, green: 0.953, blue: 0.976),
                    Color(red: 0.800, green: 0.882, blue: 0.945),
                    Color(red: 0.690, green: 0.816, blue: 0.918)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // ふんわりした雲
            GeometryReader { geometry in
                let w = geometry.size.width
                let h = geometry.size.height
                ZStack {
                    cloud(width: w * 0.9, height: h * 0.16).position(x: w * 0.25, y: h * 0.78)
                    cloud(width: w * 0.8, height: h * 0.14).position(x: w * 0.8, y: h * 0.86)
                    cloud(width: w * 0.7, height: h * 0.10).position(x: w * 0.7, y: h * 0.22)
                    cloud(width: w * 0.5, height: h * 0.08).position(x: w * 0.15, y: h * 0.32)
                }
            }

            VStack(spacing: 10) {
                Text("StudyReel")
                    .font(ReelTheme.serif(36))
                    .foregroundColor(ReelTheme.ink)
                Text(L10n.string("勉強した時間が、ひとつのVlogになる。"))
                    .font(ReelTheme.serif(13))
                    .foregroundColor(ReelTheme.secondary)
            }
        }
        .ignoresSafeArea()
    }

    private func cloud(width: CGFloat, height: CGFloat) -> some View {
        Ellipse()
            .fill(Color.white.opacity(0.75))
            .frame(width: width, height: height)
            .blur(radius: height * 0.35)
    }
}
