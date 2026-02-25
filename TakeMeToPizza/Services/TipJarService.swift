import StoreKit

@Observable
@MainActor
final class TipJarService {

    // MARK: - Product IDs

    static let productIDs: [String] = [
        "tip.slice",
        "tip.pie",
        "tip.party",
    ]

    // MARK: - State

    enum PurchaseState: Equatable {
        case ready
        case purchasing
        case thankyou(slices: Int)
        case failed(String)
    }

    private(set) var products: [Product] = []
    var purchaseState: PurchaseState = .ready

    private nonisolated(unsafe) var updatesTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func start() {
        listenForTransactions()
        Task { await loadProducts() }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Load Products

    private func loadProducts() async {
        do {
            let fetched = try await Product.products(for: Self.productIDs)
            products = fetched.sorted { $0.price < $1.price }
        } catch {
            products = []
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                let dollars = product.price as Decimal
                let cents = NSDecimalNumber(decimal: dollars).doubleValue * 100
                let slices = Int((cents / 20.32).rounded())
                purchaseState = .thankyou(slices: slices)
            case .userCancelled:
                purchaseState = .ready
            case .pending:
                purchaseState = .ready
            @unknown default:
                purchaseState = .ready
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() {
        updatesTask = Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let transaction = try? self.checkVerified(result) {
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Verification

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let item):
            return item
        }
    }
}
