import SwiftUI

// 動画に焼き込む文字のフォントを選ぶ画面
struct VideoStyleView: View {
    @EnvironmentObject private var storeKit: StoreKitManager
    @AppStorage(OverlayFont.storageKey) private var overlayFontRaw = OverlayFont.standard.rawValue
    @State private var showPaywall = false

    private let sample = HourBlockText(sessionStart: Date(), elapsedSeconds: 0)

    private var selectedFont: OverlayFont {
        OverlayFont.resolved(rawValue: overlayFontRaw, isPro: storeKit.isProUnlocked)
    }

    var body: some View {
        List {
            Section {
                preview(font: selectedFont, large: true)
                    .listRowInsets(EdgeInsets())
            } footer: {
                if !storeKit.isProUnlocked {
                    Text(L10n.string("無料版の動画には右下に「StudyReel」の透かしが入ります。"))
                }
            }

            Section(header: Text(L10n.string("文字のフォント"))) {
                ForEach(OverlayFont.allCases) { font in
                    Button {
                        if font.isPro && !storeKit.isProUnlocked {
                            showPaywall = true
                        } else {
                            overlayFontRaw = font.rawValue
                        }
                    } label: {
                        HStack {
                            Text(font.displayName)
                                .font(font.font(size: 17))
                                .foregroundColor(.primary)
                            Spacer()
                            if font.isPro && !storeKit.isProUnlocked {
                                Text(L10n.string("Pro"))
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.secondary)
                            } else if font == selectedFont {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppPalette.skyDeep)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.string("動画"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private func preview(font: OverlayFont, large: Bool) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.20, green: 0.24, blue: 0.28), Color(red: 0.08, green: 0.10, blue: 0.13)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 4) {
                Text(sample.range)
                    .font(font.font(size: 34))
                Text(sample.caption)
                    .font(font.font(size: 17))
                    .opacity(0.92)
            }
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.45), radius: 6)

            if !storeKit.isProUnlocked {
                Text("StudyReel")
                    .font(OverlayFont.standard.font(size: 12))
                    .foregroundColor(.white.opacity(0.75))
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .frame(height: large ? 200 : 120)
    }
}
