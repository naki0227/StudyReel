import SwiftUI

// 動画に焼き込む文字のフォントを選ぶ画面
struct VideoStyleView: View {
    @EnvironmentObject private var storeKit: StoreKitManager
    @AppStorage(OverlayFont.storageKey) private var overlayFontRaw = OverlayFont.defaultFont.rawValue
    @AppStorage(FaceHideStyle.storageKey) private var hideStyleRaw = FaceHideStyle.mosaic.rawValue
    @AppStorage(FaceStamp.storageKey) private var stamp = FaceStamp.defaultStamp
    @State private var showPaywall = false

    @AppStorage(OverlayLayout.storageKey) private var layoutRaw = OverlayLayout.clock.rawValue
    @AppStorage(OverlayColor.storageKey) private var colorRaw = OverlayColor.white.rawValue
    @AppStorage(OverlayBadge.storageKey) private var badgeRaw = OverlayBadge.none.rawValue
    @AppStorage(OverlayPosition.storageKey) private var positionRaw = OverlayPosition.center.rawValue
    @AppStorage(OverlaySize.storageKey) private var sizeRaw = OverlaySize.medium.rawValue
    @AppStorage(OverlayDecor.customDigitsKey) private var usesCustomDigits = false
    // 交換所で交換したら描き直す
    @AppStorage(Rewards.storageKey) private var unlockedRaw = ""
    @State private var digitsVersion = 0

    private var decor: OverlayDecor {
        _ = (colorRaw, badgeRaw, positionRaw, sizeRaw, usesCustomDigits, unlockedRaw, digitsVersion)
        return OverlayDecor.current(isPro: storeKit.isProUnlocked)
    }

    private var digitsUnlocked: Bool {
        _ = unlockedRaw
        return storeKit.isProUnlocked || Rewards.isUnlocked("digits")
    }

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

            Section(header: Text(L10n.string("時刻の色"))) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(OverlayColor.allCases) { color in
                            Button {
                                if color.isPro && !storeKit.isProUnlocked { showPaywall = true } else { colorRaw = color.rawValue }
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle().fill(Color(color.uiColor)).frame(width: 30, height: 30)
                                            .overlay(Circle().stroke(ReelTheme.line, lineWidth: 1))
                                        if decor.color == color {
                                            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                                                .foregroundColor(color == .white ? ReelTheme.ink : .white)
                                        } else if color.isPro && !storeKit.isProUnlocked {
                                            Image(systemName: "lock.fill").font(.system(size: 9)).foregroundColor(.white)
                                        }
                                    }
                                    Text(color.title).font(ReelTheme.sans(10)).foregroundColor(ReelTheme.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(ReelTheme.card)
            }

            Section(header: Text(L10n.string("時刻の飾り"))) {
                ForEach(OverlayBadge.allCases) { badge in
                    Button {
                        if badge.isPro && !storeKit.isProUnlocked { showPaywall = true } else { badgeRaw = badge.rawValue }
                    } label: {
                        HStack {
                            Text(badge.title).font(ReelTheme.sans(15)).foregroundColor(ReelTheme.ink)
                            Spacer()
                            if badge.isPro && !storeKit.isProUnlocked {
                                Text(L10n.string("Pro")).font(.caption.weight(.bold)).foregroundColor(.secondary)
                            } else if decor.badge == badge {
                                Image(systemName: "checkmark").foregroundColor(ReelTheme.accentDeep)
                            }
                        }
                    }
                }
                .listRowBackground(ReelTheme.card)
                Picker(L10n.string("置き場所"), selection: $positionRaw) {
                    ForEach(OverlayPosition.allCases) { item in
                        Text(item.title).tag(item.rawValue)
                    }
                }
                .listRowBackground(ReelTheme.card)
                Picker(L10n.string("大きさ"), selection: $sizeRaw) {
                    ForEach(OverlaySize.allCases) { item in
                        Text(item.title).tag(item.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(ReelTheme.card)
            }

            Section {
                if digitsUnlocked {
                    Toggle(L10n.string("自分の数字を使う"), isOn: $usesCustomDigits)
                        .disabled(!CustomDigits.isComplete)
                        .listRowBackground(ReelTheme.card)
                    NavigationLink {
                        CustomDigitsView { digitsVersion += 1 }
                    } label: {
                        Text(CustomDigits.isComplete ? L10n.string("数字を書き直す・撮り直す") : L10n.string("0〜9 と「:」を書く・撮る"))
                    }
                    .listRowBackground(ReelTheme.card)
                } else {
                    Button { showPaywall = true } label: {
                        HStack {
                            Text(L10n.string("自分で書いた・撮った数字で時刻を出す"))
                            Spacer()
                            Text(L10n.string("Pro")).font(.caption.weight(.bold)).foregroundColor(.secondary)
                        }
                    }
                    .listRowBackground(ReelTheme.card)
                }
            } header: {
                Text(L10n.string("自分の数字"))
            } footer: {
                Text(L10n.string("0〜9 と「:」の11文字を、指で書くか、紙に書いた字やシールを撮って作ります。動画の時刻がその字になります。"))
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
        let canvas = CGSize(width: 1280, height: 720)
        let style = VideoOverlayStyle(font: font, showsWatermark: !storeKit.isProUnlocked, layout: layout, decor: decor)
        let image = VideoOverlayRenderer.makeImage(text: sample, style: style, canvasSize: canvas)
        return ZStack {
            LinearGradient(
                colors: [Color(red: 0.20, green: 0.24, blue: 0.28), Color(red: 0.08, green: 0.10, blue: 0.13)],
                startPoint: .top,
                endPoint: .bottom
            )
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(height: large ? 200 : 120)
    }
}
