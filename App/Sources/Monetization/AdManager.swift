import UIKit
import AppTrackingTransparency
import GoogleMobileAds

/// Ad unit IDs. These are Google's public TEST IDs, which always serve test ads.
/// Replace them (and GADApplicationIdentifier in project.yml) with the IDs from your
/// AdMob account before releasing on the App Store.
enum AdConfig {
    static let interstitialUnitID = "ca-app-pub-3940256099942544/4411468910"
    static let rewardedUnitID = "ca-app-pub-3940256099942544/1712485313"
    /// An interstitial is shown after this many played weeks.
    static let weeksPerAd = 5
}

/// Loads and shows full-screen ads every few played weeks, unless "Remove Ads" was bought.
@MainActor
final class AdManager: NSObject, GADFullScreenContentDelegate {
    static let shared = AdManager()

    private var interstitial: GADInterstitialAd?
    private var rewarded: GADRewardedAd?
    private var isLoadingRewarded = false
    private var isLoading = false
    private var started = false
    private let counterKey = "weeksSinceLastAd"

    /// Asks for tracking permission (iOS shows it once), then starts the SDK and preloads an ad.
    /// Rewarded ads are optional, so the SDK starts even for players who removed ads.
    func start() {
        guard !started else { return }
        started = true
        ATTrackingManager.requestTrackingAuthorization { _ in
            Task { @MainActor in
                GADMobileAds.sharedInstance().start(completionHandler: nil)
                self.load()
                self.loadRewarded()
            }
        }
    }

    var isRewardedReady: Bool { rewarded != nil }

    func loadRewarded() {
        guard rewarded == nil, !isLoadingRewarded else { return }
        isLoadingRewarded = true
        GADRewardedAd.load(withAdUnitID: AdConfig.rewardedUnitID, request: GADRequest()) { [weak self] ad, _ in
            Task { @MainActor in
                guard let self else { return }
                self.isLoadingRewarded = false
                self.rewarded = ad
                self.rewarded?.fullScreenContentDelegate = self
            }
        }
    }

    /// Shows a rewarded ad. `onReward` runs only if the player watched it to the end.
    /// Returns false when no ad is loaded yet.
    @discardableResult
    func showRewarded(onReward: @escaping @MainActor () -> Void) -> Bool {
        guard let ad = rewarded, let root = Self.topViewController() else {
            loadRewarded()
            return false
        }
        rewarded = nil
        ad.present(fromRootViewController: root) {
            Task { @MainActor in onReward() }
        }
        return true
    }

    private func load() {
        guard interstitial == nil, !isLoading, !PurchaseManager.adsRemovedCached else { return }
        isLoading = true
        GADInterstitialAd.load(withAdUnitID: AdConfig.interstitialUnitID, request: GADRequest()) { [weak self] ad, _ in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                self.interstitial = ad
                self.interstitial?.fullScreenContentDelegate = self
            }
        }
    }

    /// Call after every played week.
    func recordPlayedWeek() {
        guard !PurchaseManager.adsRemovedCached else { return }
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: counterKey) + 1, forKey: counterKey)
        if interstitial == nil { load() }
    }

    var isAdDue: Bool {
        !PurchaseManager.adsRemovedCached && UserDefaults.standard.integer(forKey: counterKey) >= AdConfig.weeksPerAd
    }

    /// Shows the ad if one is due and loaded. If it isn't loaded yet it is shown next time.
    func presentIfDue() {
        guard isAdDue else { return }
        guard let ad = interstitial, let root = Self.topViewController() else {
            load()
            return
        }
        UserDefaults.standard.set(0, forKey: counterKey)
        ad.present(fromRootViewController: root)
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        let isRewarded = ad is GADRewardedAd
        Task { @MainActor in
            if isRewarded {
                self.loadRewarded()
            } else {
                self.interstitial = nil
                self.load()
            }
        }
    }

    nonisolated func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        let isRewarded = ad is GADRewardedAd
        Task { @MainActor in
            if isRewarded {
                self.rewarded = nil
                self.loadRewarded()
            } else {
                self.interstitial = nil
                self.load()
            }
        }
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
