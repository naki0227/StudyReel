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
        NavigationView {
            ZStack {
                AppPalette.paywallGradient(for: colorScheme)
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
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("StudyReel Pro"))
                .font(.subheadline.weight(.bold))
                .foregroundColor(AppPalette.accentText(for: colorScheme))

            Text(L10n.string("振り返りを、もっと細かく。"))
                .font(.title2.weight(.bold))

            Text(L10n.string("教科ごとの伸びや、集中しやすい時間帯がわかります。"))
                .font(.subheadline)
                .foregroundColor(.secondary)

            if storeKit.isProUnlocked {
                Label(L10n.string("Proが有効です"), systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.green)
                    .padding(.top, 4)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var comparisonCard: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text(L10n.string("Free"))
                    .frame(width: 52)
                Text(L10n.string("Pro"))
                    .frame(width: 52)
                    .foregroundColor(AppPalette.accentText(for: colorScheme))
            }
            .font(.caption.weight(.bold))
            .foregroundColor(.secondary)
            .padding(.bottom, 8)

            comparisonRow(L10n.string("タイマー・タイムラプス"), free: true)
            Divider()
            comparisonRow(L10n.string("基本の統計・カレンダー"), free: true)
            Divider()
            comparisonRow(L10n.string("教科別の先週比"), free: false)
            Divider()
            comparisonRow(L10n.string("集中しやすい時間帯"), free: false)
            Divider()
            comparisonRow(L10n.string("勉強時間の推移グラフ"), free: false)
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
                .foregroundColor(AppPalette.accentText(for: colorScheme))
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
                    .foregroundColor(isSelected ? AppPalette.accentText(for: colorScheme) : .secondary)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(planTitle(for: product))
                            .font(.headline)
                        if isRecommended(product) {
                            Text(L10n.string("おすすめ"))
                                .font(.caption2.weight(.bold))
                                .foregroundColor(AppPalette.ink)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(AppPalette.orange)
                                .clipShape(Capsule())
                        }
                    }
                    if let monthly = monthlyEquivalent(for: product) {
                        Text(L10n.format("月あたり %@", monthly))
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
                    .fill(isSelected ? AppPalette.sky.opacity(colorScheme == .dark ? 0.16 : 0.22) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? AppPalette.skyDeep : Color.clear, lineWidth: 1.5)
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
            Text(storeKit.isProUnlocked ? L10n.string("Proは有効です") : L10n.string("Proを始める"))
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundColor(AppPalette.ink)
                .background(AppPalette.sky)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(storeKit.isProUnlocked || selectedProduct == nil)
        .opacity(storeKit.isProUnlocked ? 0.6 : 1)
        .padding(.top, 4)
    }

    private var legalFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string("購入確定時にApple IDへ請求されます。期間終了の24時間前までに解約しない限り自動で更新されます。解約はApple IDの設定からいつでもできます。"))
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
            .fill(AppPalette.cardFill(for: colorScheme))
    }

    private var selectedProduct: Product? {
        if let selectedProductID, let product = storeKit.products.first(where: { $0.id == selectedProductID }) {
            return product
        }
        return storeKit.products.first(where: { isRecommended($0) }) ?? storeKit.products.first
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

    private func priceLabel(for product: Product) -> String {
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
