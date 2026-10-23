import UIKit
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform

/// Ad unit IDs from the Kickoff Manager app in AdMob.
/// TestFlight and debug builds use Google's public test units, so testers never click
/// real ads (AdMob can suspend accounts for that). App Store builds use the real ones.
enum AdConfig {
    /// TestFlight installs carry a sandbox receipt.
    static let useTestAds: Bool = {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }()

    static let interstitialUnitID = useTestAds
        ? "ca-app-pub-3940256099942544/4411468910"
        : "ca-app-pub-7480304536097194/6775385155"
    static let rewardedUnitID = useTestAds
        ? "ca-app-pub-3940256099942544/1712485313"
        : "ca-app-pub-7480304536097194/9955996543"
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
    /// Order matters: first Google's consent form (shown only in the EEA, UK and Switzerland),
    /// then Apple's tracking prompt, then the ads SDK. Rewarded ads are optional, so the SDK
    /// starts even for players who removed ads.
    func start() {
        guard !started, !GameStore.isScreenshotMode else { return }
        started = true
        UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: UMPRequestParameters()) { _ in
            Task { @MainActor in
                UMPConsentForm.loadAndPresentIfRequired(from: Self.topViewController()) { _ in
                    Task { @MainActor in self.requestTrackingAndStartAds() }
                }
            }
        }
    }

    private func requestTrackingAndStartAds() {
        ATTrackingManager.requestTrackingAuthorization { _ in
            Task { @MainActor in
                // Without consent (where it's required) no ads can be requested.
                guard UMPConsentInformation.sharedInstance.canRequestAds else { return }
                GADMobileAds.sharedInstance().start(completionHandler: nil)
                self.load()
                self.loadRewarded()
            }
        }
    }

    /// Players in the EEA can change their ad consent from settings.
    var privacyOptionsRequired: Bool {
        UMPConsentInformation.sharedInstance.privacyOptionsRequirementStatus == .required
    }

    func showPrivacyOptions() {
        UMPConsentForm.presentPrivacyOptionsForm(from: Self.topViewController()) { _ in }
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
