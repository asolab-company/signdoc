import Combine
import Foundation
import StoreKit

@MainActor
final class IAPManager: NSObject, ObservableObject {
    static let shared = IAPManager()

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isSubscribed: Bool = false
    @Published var isLoadingProducts: Bool = false

    private let productIDs: Set<String> = [AppLinks.weekly]

    private override init() {
        super.init()
        Task {
            observeTransactionUpdates()
            await fetchProducts()
            await refreshEntitlements()
        }
    }

    func fetchProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: Array(productIDs))

            let subsOnly = loaded.filter { $0.type == .autoRenewable }

            products = subsOnly.sorted { $0.price < $1.price }
        } catch {
            print("❌ fetchProducts:", error)
        }
    }

    func purchase(id: String) async {
        guard let product = products.first(where: { $0.id == id }) else {
            return
        }
        await purchase(product: product)
    }

    func purchase(product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let tx):
                    await tx.finish()
                    await refreshEntitlements()
                case .unverified(_, let error):
                    print("⚠️ Unverified transaction:", error)
                }
            case .userCancelled:
                break
            case .pending:
                print("⏳ Pending (Ask to Buy)")
            @unknown default:
                break
            }
        } catch {
            print("❌ purchase:", error)
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            print("❌ restore:", error)
        }
    }

    func refreshEntitlements() async {
        var owned = Set<String>()
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let tx) = entitlement {
                owned.insert(tx.productID)
            }
        }
        purchasedProductIDs = owned
        isSubscribed = await computeActiveSubscription()
    }

    private func computeActiveSubscription() async -> Bool {

        guard let id = productIDs.first else { return false }
        if let latest = await Transaction.latest(for: id),
            case .verified(let tx) = latest,
            tx.revocationDate == nil,
            (tx.expirationDate ?? .distantFuture) > Date()
        {
            return true
        }
        return false
    }

    func observeTransactionUpdates() {
        Task { [weak self] in
            guard let self else { return }
            for await update in Transaction.updates {
                if case .verified(let tx) = update {
                    await tx.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }
}
