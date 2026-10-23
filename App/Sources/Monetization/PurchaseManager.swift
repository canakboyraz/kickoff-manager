import Foundation
import Observation
import StoreKit

/// One-time "Remove Ads" purchase (non-consumable, StoreKit 2).
/// The product must be created in App Store Connect with the same product ID.
@MainActor
@Observable
final class PurchaseManager {
    static let removeAdsProductID = "com.canakboyraz.kickoffmanager.removeads"
    private nonisolated static let cacheKey = "adsRemoved"

    /// Read from anywhere (the ad manager checks this before every ad).
    nonisolated static var adsRemovedCached: Bool {
        UserDefaults.standard.bool(forKey: cacheKey)
    }

    private(set) var adsRemoved = PurchaseManager.adsRemovedCached
    private(set) var product: Product?
    private(set) var isWorking = false
    var message: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
        Task { await prepare() }
    }

    func prepare() async {
        product = try? await Product.products(for: [Self.removeAdsProductID]).first
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var owned = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == Self.removeAdsProductID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        setAdsRemoved(owned)
    }

    func buyRemoveAds() async {
        guard let product else {
            message = L("store.unavailable")
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    setAdsRemoved(true)
                    message = L("store.thanks")
                }
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = L("store.failed")
        }
    }

    func restore() async {
        isWorking = true
        defer { isWorking = false }
        try? await AppStore.sync()
        await refreshEntitlements()
        message = adsRemoved ? L("store.restored") : L("store.nothingToRestore")
    }

    private func setAdsRemoved(_ value: Bool) {
        adsRemoved = value
        UserDefaults.standard.set(value, forKey: Self.cacheKey)
    }
}
