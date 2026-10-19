import SwiftUI

// 教材の表紙。画像がなければ、やわらかい色の上に教材名を縦長に出す
struct MaterialCover: View {
    let material: StudyMaterial?
    var cornerRadius: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            if let image = MediaStore.thumbnail(named: material?.coverFileName) {
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
                    if let material {
                        Text(material.name)
                            .font(ReelTheme.serif(min(geometry.size.width * 0.16, 15)))
                            .foregroundColor(ReelTheme.accentDeep)
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                            .minimumScaleFactor(0.6)
                            .padding(6)
                    } else {
                        Image(systemName: "book.closed")
                            .foregroundColor(ReelTheme.accentDeep.opacity(0.7))
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
