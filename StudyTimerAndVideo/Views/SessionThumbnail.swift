import SwiftUI

// 記録のサムネイル。画像がない古い記録は、やわらかい色の上に教科名を出す
struct SessionThumbnail: View {
    let fileName: String?
    let subject: String

    var body: some View {
        GeometryReader { geometry in
            if let image = MediaStore.thumbnail(named: fileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [ReelTheme.accentSoft, Color(red: 0.93, green: 0.95, blue: 0.97)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Text(subject)
                        .font(ReelTheme.serif(min(geometry.size.height * 0.22, 20)))
                        .foregroundColor(ReelTheme.accentDeep.opacity(0.8))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                }
            }
        }
    }
}
