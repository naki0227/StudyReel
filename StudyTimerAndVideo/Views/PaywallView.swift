import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var storeKit: StoreKitManager
    private let privacyPolicyURL = URL(string: "https://enludus.com/products/studyreel-privacy")!
    private let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    #if DEBUG
    @State private var showDebugTools = false
    #endif

    @State private var selectedProductID: String?

    var body: some View {
        NavigationStack {
            ZStack {
                ReelTheme.background
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        heroCard
                        comparisonCard
                        productCard
                        legalFooter
                        #if DEBUG
                        debugCard
                        #endif
                    }
                    .padding(20)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.string("閉じる")) {
                        dismiss()
                    }
                    .foregroundColor(ReelTheme.secondary)
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

    // 空の色のヘッダーに、明朝体のひとこと
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("StudyReel Pro")
                .font(ReelTheme.serif(15))
                .foregroundColor(ReelTheme.accentDeep)

            Text(L10n.string("勉強Vlogを、もっと自由に。"))
                .font(ReelTheme.serif(26))
                .foregroundColor(ReelTheme.ink)

            Text(L10n.string("透かしなしの動画、フォント選び、全部録画、テーマカラーが使えます。"))
                .font(ReelTheme.sans(13))
                .foregroundColor(ReelTheme.secondary)

            if storeKit.isProUnlocked {
                Label(L10n.string("Proが有効です"), systemImage: "checkmark.seal")
                    .font(ReelTheme.sans(13, weight: .medium))
                    .foregroundColor(ReelTheme.accentDeep)
                    .padding(.top, 4)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ReelTheme.cornerRadius, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.918, green: 0.953, blue: 0.976), Color(red: 0.800, green: 0.882, blue: 0.945)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
    }

    private var comparisonCard: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text(L10n.string("Free"))
                    .frame(width: 52)
                Text(L10n.string("Pro"))
                    .frame(width: 52)
                    .foregroundColor(ReelTheme.accentDeep)
            }
            .font(.caption.weight(.bold))
            .foregroundColor(.secondary)
            .padding(.bottom, 8)

            comparisonRow(L10n.string("時刻入りのタイムラプス"), free: true)
            Divider()
            comparisonRow(L10n.string("顔にモザイク"), free: true)
            Divider()
            comparisonRow(L10n.string("カット・フィルター・BGM 2曲"), free: true)
            Divider()
            comparisonRow(L10n.string("統計・カレンダー・推移グラフ"), free: true)
            Divider()
            comparisonRow(L10n.string("ロゴなしで保存"), free: false)
            Divider()
            comparisonRow(L10n.string("動画のフォントを選ぶ"), free: false)
            Divider()
            comparisonRow(L10n.string("顔をスタンプで隠す"), free: false)
            Divider()
            comparisonRow(L10n.string("BGM 全4曲"), free: false)
            Divider()
            comparisonRow(L10n.string("全部録画（等速）"), free: false)
            Divider()
            comparisonRow(L10n.string("教科別の内訳"), free: false)
            Divider()
        }
        .padding(20)
        .background(cardBackground)
    }

    private func comparisonRow(_ title: String, free: Bool) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: free ? "checkmark" : "minus")
                .foregroundColor(free ? .primary : .secondary)
                .frame(width: 52)
            Image(systemName: "checkmark")
                .foregroundColor(ReelTheme.accentDeep)
                .frame(width: 52)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.vertical, 10)
    }

    private var productCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if storeKit.isLoading && storeKit.products.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else if storeKit.products.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("プランを読み込めませんでした"))
                        .font(.headline)
                    Button(L10n.string("再読み込み")) {
                        Task {
                            await storeKit.refresh()
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            } else {
                ForEach(storeKit.products, id: \.id) { product in
                    planRow(product)
                }

                purchaseButton
            }

            Button(L10n.string("購入を復元")) {
                Task {
                    await storeKit.restorePurchases()
                }
            }
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .padding(20)
        .background(cardBackground)
    }

    private func planRow(_ product: Product) -> some View {
        let isSelected = selectedProduct?.id == product.id

        return Button {
            selectedProductID = product.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? ReelTheme.accentDeep : .secondary)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(planTitle(for: product))
                            .font(.headline)
                        if isRecommended(product) {
                            Text(L10n.string("おすすめ"))
                                .font(.caption2.weight(.bold))
                                .foregroundColor(ReelTheme.accentDeep)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(ReelTheme.accentSoft)
                                .clipShape(Capsule())
                        }
                    }
                    if let detail = planDetail(for: product) {
                        Text(detail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text(priceLabel(for: product))
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
            }
            .foregroundColor(.primary)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? ReelTheme.accentSoft : ReelTheme.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? ReelTheme.accentDeep : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var purchaseButton: some View {
        Button {
            guard let product = selectedProduct else { return }
            Task {
                await storeKit.purchase(product)
            }
        } label: {
            Text(purchaseButtonTitle)
                .font(ReelTheme.sans(15, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundColor(.white)
                .background(Capsule().fill(ReelTheme.accentDeep))
        }
        .disabled(storeKit.isProUnlocked || selectedProduct == nil)
        .opacity(storeKit.isProUnlocked ? 0.6 : 1)
        .padding(.top, 4)
    }

    private var legalFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string("月額・年額は自動更新のサブスクリプションです。購入確定時（無料期間がある場合は終了時）にApple IDへ請求され、期間終了の24時間前までに解約しない限り自動で更新されます。解約はApple IDの設定からいつでもできます。"))
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(L10n.string("買い切りは一度の購入でずっと使えます。"))
                .font(.caption2)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Link(L10n.string("利用規約"), destination: termsOfUseURL)
                Link(L10n.string("プライバシーポリシー"), destination: privacyPolicyURL)
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 4)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(ReelTheme.card)
    }

    private var selectedProduct: Product? {
        if let selectedProductID, let product = storeKit.products.first(where: { $0.id == selectedProductID }) {
            return product
        }
        return storeKit.products.first(where: { isRecommended($0) }) ?? storeKit.products.first
    }

    private var purchaseButtonTitle: String {
        if storeKit.isProUnlocked {
            return L10n.string("Proは有効です")
        }
        if let product = selectedProduct, storeKit.freeTrialPeriod(for: product) != nil {
            return L10n.string("無料で試す")
        }
        return L10n.string("Proを始める")
    }

    private func planDetail(for product: Product) -> String? {
        var parts: [String] = []
        if let period = storeKit.freeTrialPeriod(for: product) {
            parts.append(L10n.format("最初の%@は無料", periodText(period)))
        }
        if let monthly = monthlyEquivalent(for: product) {
            parts.append(L10n.format("月あたり %@", monthly))
        }
        if product.id == StoreKitManager.lifetimeID {
            parts.append(L10n.string("一度の購入でずっと使える"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func periodText(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day:
            return period.value == 7 ? L10n.string("1週間") : L10n.format("%d日間", period.value)
        case .week:
            return L10n.format("%d週間", period.value)
        case .month:
            return L10n.format("%dか月", period.value)
        case .year:
            return L10n.format("%d年", period.value)
        @unknown default:
            return L10n.format("%d日間", period.value)
        }
    }

    private func planTitle(for product: Product) -> String {
        if product.id == StoreKitManager.lifetimeID {
            return L10n.string("買い切り")
        }
        if product.id.contains("yearly") {
            return L10n.string("年額プラン")
        }
        if product.id.contains("monthly") {
            return L10n.string("月額プラン")
        }
        return product.displayName
    }

    private func priceLabel(for product: Product) -> String {
        if product.id == StoreKitManager.lifetimeID {
            return product.displayPrice
        }
        if product.id.contains("yearly") {
            return L10n.format("%@ / 年", product.displayPrice)
        }
        if product.id.contains("monthly") {
            return L10n.format("%@ / 月", product.displayPrice)
        }
        return product.displayPrice
    }

    private func monthlyEquivalent(for product: Product) -> String? {
        guard product.id.contains("yearly") else { return nil }
        return (product.price / 12).formatted(product.priceFormatStyle)
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
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
    #endif
}
