import SwiftUI

// 動画に焼き込む文字のフォントを選ぶ画面
struct VideoStyleView: View {
    @EnvironmentObject private var storeKit: StoreKitManager
    @AppStorage(OverlayFont.storageKey) private var overlayFontRaw = OverlayFont.defaultFont.rawValue
    @AppStorage(FaceHideStyle.storageKey) private var hideStyleRaw = FaceHideStyle.mosaic.rawValue
    @AppStorage(FaceStamp.storageKey) private var stamp = FaceStamp.defaultStamp
    @State private var showPaywall = false

    @AppStorage(OverlayLayout.storageKey) private var layoutRaw = OverlayLayout.clock.rawValue

    private var layout: OverlayLayout {
        OverlayLayout(rawValue: layoutRaw) ?? .clock
    }

    private var sample: OverlayText {
        OverlayText(sessionStart: Date(), elapsedSeconds: 0, layout: layout)
    }

    private var selectedHideStyle: FaceHideStyle {
        FaceHideStyle.resolved(rawValue: hideStyleRaw, isPro: storeKit.isProUnlocked)
    }

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

            Section(header: Text(L10n.string("真ん中に出す文字"))) {
                Picker(L10n.string("真ん中に出す文字"), selection: $layoutRaw) {
                    ForEach(OverlayLayout.allCases) { item in
                        Text(item.title).tag(item.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(ReelTheme.card)
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
                                .foregroundColor(ReelTheme.ink)
                            Spacer()
                            if font.isPro && !storeKit.isProUnlocked {
                                Text(L10n.string("Pro"))
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.secondary)
                            } else if font == selectedFont {
                                Image(systemName: "checkmark")
                                    .foregroundColor(ReelTheme.accentDeep)
                            }
                        }
                    }
                }
            }

            Section {
                ForEach(FaceHideStyle.allCases) { style in
                    Button {
                        if style.isPro && !storeKit.isProUnlocked {
                            showPaywall = true
                        } else {
                            hideStyleRaw = style.rawValue
                        }
                    } label: {
                        HStack {
                            Text(style.title)
                                .font(ReelTheme.sans(15))
                                .foregroundColor(ReelTheme.ink)
                            Spacer()
                            if style.isPro && !storeKit.isProUnlocked {
                                Text(L10n.string("Pro"))
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.secondary)
                            } else if style == selectedHideStyle {
                                Image(systemName: "checkmark")
                                    .foregroundColor(ReelTheme.accentDeep)
                            }
                        }
                    }
                }

                if selectedHideStyle == .stamp {
                    HStack {
                        ForEach(FaceStamp.options, id: \.self) { option in
                            Button {
                                stamp = option
                            } label: {
                                Text(option)
                                    .font(.title2)
                                    .frame(maxWidth: .infinity, minHeight: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(option == stamp ? ReelTheme.accentSoft : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } header: {
                Text(L10n.string("顔の隠し方"))
            } footer: {
                Text(L10n.string("顔の位置は端末の中だけで検出し、保存も送信もしません。"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(ReelTheme.background.ignoresSafeArea())
        .listRowBackground(ReelTheme.card)
        .tint(ReelTheme.accentDeep)
        .navigationTitle(L10n.string("文字と顔の隠し方"))
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
                Text(sample.primary)
                    .font(font.font(size: layout == .clock ? 26 : 34))
                if let secondary = sample.secondary {
                    Text(secondary)
                        .font(font.font(size: 17))
                        .opacity(0.92)
                }
            }
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.45), radius: 6)

            if !storeKit.isProUnlocked {
                Text("StudyReel")
                    .font(ReelTheme.serif(12))
                    .foregroundColor(.white.opacity(0.75))
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .frame(height: large ? 200 : 120)
    }
}
