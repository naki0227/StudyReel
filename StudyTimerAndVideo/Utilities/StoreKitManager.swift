import Foundation
import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {
    static let productIDs = [
        "com.ni.StudyReel.pro.monthly",
        "com.ni.StudyReel.pro.yearly"
    ]

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs = Set<String>()
    @Published private(set) var isLoading = false
    @Published var purchaseErrorMessage: String?

    private var updatesTask: Task<Void, Never>?
    #if DEBUG
    private let debugUnlockKey = "debug_pro_unlocked"
    @Published private(set) var isDebugProUnlocked = false
    #endif

    var isProUnlocked: Bool {
        #if DEBUG
        if isDebugProUnlocked {
            return true
        }
        #endif
        return !purchasedProductIDs.isEmpty
    }

    init() {
        #if DEBUG
        isDebugProUnlocked = UserDefaults.standard.bool(forKey: debugUnlockKey)
        #endif
        updatesTask = observeTransactionUpdates()
        Task {
            await refresh()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { $0.price < $1.price }
            await updatePurchasedProducts()
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                purchasedProductIDs.insert(transaction.productID)
                await transaction.finish()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    #if DEBUG
    var canUseDebugUnlock: Bool {
        true
    }

    func enableDebugPro() {
        isDebugProUnlocked = true
        UserDefaults.standard.set(true, forKey: debugUnlockKey)
    }

    func disableDebugPro() {
        isDebugProUnlocked = false
        UserDefaults.standard.removeObject(forKey: debugUnlockKey)
    }
    #endif

    private func updatePurchasedProducts() async {
        var updatedIDs = Set<String>()

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(result) else { continue }
            if Self.productIDs.contains(transaction.productID) {
                updatedIDs.insert(transaction.productID)
            }
        }

        purchasedProductIDs = updatedIDs
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { continue }
                guard let transaction = try? Self.checkVerified(result) else { continue }

                await MainActor.run {
                    if Self.productIDs.contains(transaction.productID) {
                        self.purchasedProductIDs.insert(transaction.productID)
                    }
                }

                await transaction.finish()
            }
        }
    }

    nonisolated private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreKitError.failedVerification
        }
    }
}

enum StoreKitError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return L10n.string("購入確認に失敗しました。")
        }
    }
}
