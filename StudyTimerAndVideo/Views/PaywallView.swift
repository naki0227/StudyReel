import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeKit: StoreKitManager
    private let privacyPolicyURL = URL(string: "https://garrulous-court-1b7.notion.site/2bea705256988039b6fdd92ffb57a410")!
    private let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    #if DEBUG
    @State private var showDebugTools = false
    #endif

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.98, blue: 1.0),
                        Color(red: 0.89, green: 0.94, blue: 0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        heroCard
                        featureCard
                        comparisonCard
                        productCard
                        legalCard
                        #if DEBUG
                        debugCard
                        #endif
                    }
                    .padding(20)
                }
            }
            .navigationTitle(L10n.string("StudyReel Pro"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.string("閉じる")) {
                        dismiss()
                    }
                }
            }
            .task {
                if storeKit.products.isEmpty {
                    await storeKit.refresh()
                }
            }
            .alert(L10n.string("購入エラー"), isPresented: Binding(
                get: { storeKit.purchaseErrorMessage != nil },
                set: { if !$0 { storeKit.purchaseErrorMessage = nil } }
            )) {
                Button(L10n.string("OK"), role: .cancel) {
                    storeKit.purchaseErrorMessage = nil
                }
            } message: {
                Text(storeKit.purchaseErrorMessage ?? "")
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("StudyReel Pro"))
                .font(.headline)
                .foregroundColor(.blue)

            Text(L10n.string("学習の流れを、もっと深く見る"))
                .font(.title2.weight(.bold))

            Text(L10n.string("詳細な統計、教科別の深い分析、今後のバックアップ機能などを Pro で使えるようにします。"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(L10n.string("基本の学習体験は無料のまま、深い振り返りだけを Pro にしています。"))
                .font(.caption)
                .foregroundColor(.secondary)

            if storeKit.isProUnlocked {
                Label(L10n.string("Proが有効です"), systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.green)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.82))
        )
    }

    private var featureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("Proでできること"))
                .font(.headline)
            featureRow(L10n.string("教科別の先週比と強い時間帯"))
            featureRow(L10n.string("詳細な学習パターン分析"))
            featureRow(L10n.string("今後のバックアップと書き出し機能"))
            featureRow(L10n.string("長期の学習傾向を深く振り返る"))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.82))
        )
    }

    private var comparisonCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.string("無料版と Pro"))
                .font(.headline)

            comparisonRow(
                title: L10n.string("タイマー・ストップウォッチ"),
                freeValue: L10n.string("使える"),
                proValue: L10n.string("使える")
            )
            comparisonRow(
                title: L10n.string("タイムラプス記録"),
                freeValue: L10n.string("使える"),
                proValue: L10n.string("使える")
            )
            comparisonRow(
                title: L10n.string("基本統計"),
                freeValue: L10n.string("使える"),
                proValue: L10n.string("使える")
            )
            comparisonRow(
                title: L10n.string("教科別の先週比"),
                freeValue: L10n.string("なし"),
                proValue: L10n.string("使える")
            )
            comparisonRow(
                title: L10n.string("強い時間帯の分析"),
                freeValue: L10n.string("なし"),
                proValue: L10n.string("使える")
            )
            comparisonRow(
                title: L10n.string("書き出し・バックアップ"),
                freeValue: L10n.string("今後対応"),
                proValue: L10n.string("今後対応")
            )
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.82))
        )
    }

    private func featureRow(_ title: String) -> some View {
        Label(title, systemImage: "sparkles")
            .font(.subheadline.weight(.medium))
            .foregroundColor(.primary)
    }

    private func comparisonRow(title: String, freeValue: String, proValue: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 12) {
                comparisonPill(title: L10n.string("Free"), value: freeValue, tint: Color.gray.opacity(0.12))
                comparisonPill(title: L10n.string("Pro"), value: proValue, tint: Color.blue.opacity(0.12))
            }
        }
    }

    private func comparisonPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var productCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("プランを選ぶ"))
                .font(.headline)

            if storeKit.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else if storeKit.products.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("商品がまだ設定されていません"))
                        .font(.headline)
                    Text(L10n.string("App Store Connect に Pro 商品を追加すると、ここに価格と購入ボタンが表示されます。"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(storeKit.products, id: \.id) { product in
                    Button {
                        Task {
                            await storeKit.purchase(product)
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(planTitle(for: product))
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    if isRecommended(product) {
                                        Text(L10n.string("おすすめ"))
                                            .font(.caption.weight(.bold))
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                }

                                Text(planSubtitle(for: product))
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)

                                Text(product.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(product.displayPrice)
                                    .font(.headline.weight(.bold))
                                    .foregroundColor(.blue)

                                if let footnote = planFootnote(for: product) {
                                    Text(footnote)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(16)
                        .background(isRecommended(product) ? Color.blue.opacity(0.1) : Color.blue.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(isRecommended(product) ? Color.blue.opacity(0.24) : Color.clear, lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(L10n.string("購入を復元")) {
                Task {
                    await storeKit.restorePurchases()
                }
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.82))
        )
    }

    private var legalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("サブスクリプション情報"))
                .font(.headline)

            Text(L10n.string("自動更新サブスクリプションです。購入確認後にApple IDへ課金され、現在の期間終了の24時間以上前に自動更新をオフにしない限り自動更新されます。"))
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Link(L10n.string("利用規約"), destination: termsOfUseURL)
                Link(L10n.string("プライバシーポリシー"), destination: privacyPolicyURL)
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.82))
        )
    }

    private func planTitle(for product: Product) -> String {
        if product.id.contains("yearly") {
            return L10n.string("年額プラン")
        }
        if product.id.contains("monthly") {
            return L10n.string("月額プラン")
        }
        return product.displayName
    }

    private func planSubtitle(for product: Product) -> String {
        if product.id.contains("yearly") {
            return L10n.string("じっくり続けたい人向け")
        }
        if product.id.contains("monthly") {
            return L10n.string("まずは気軽に試したい人向け")
        }
        return product.displayName
    }

    private func planFootnote(for product: Product) -> String? {
        if product.id.contains("yearly") {
            return L10n.string("いちばんおすすめ")
        }
        return nil
    }

    private func isRecommended(_ product: Product) -> Bool {
        product.id.contains("yearly")
    }

    #if DEBUG
    private var debugCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(showDebugTools ? L10n.string("開発テストを隠す") : L10n.string("開発テストを表示")) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDebugTools.toggle()
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.blue)

            if showDebugTools {
                Text(L10n.string("simulator や開発ビルドで、購入なしに Pro 導線を確認できます。"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(storeKit.isDebugProUnlocked ? L10n.string("開発用Proを解除する") : L10n.string("開発用にProを有効化")) {
                    if storeKit.isDebugProUnlocked {
                        storeKit.disableDebugPro()
                    } else {
                        storeKit.enableDebugPro()
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(storeKit.isDebugProUnlocked ? Color.red.opacity(0.9) : Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.82))
        )
    }
    #endif
}
