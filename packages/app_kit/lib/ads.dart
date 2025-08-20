import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:user_messaging_platform/user_messaging_platform.dart' as ump;

class AppAds {
  static bool _initialized = false;
  static InterstitialAd? _interstitial;
  static RewardedAd? _rewarded;

  static Future<void> init({
    required String appIdIOS,
    required String bannerIdIOS,
    required String interstitialIdIOS,
    required String rewardedIdIOS,
  }) async {
    if (_initialized) return;

    // UMP: 同意情報の更新とフォーム表示
    try {
      await ump.ConsentInformation.instance.requestConsentInfoUpdate();
      if (await ump.ConsentInformation.instance.isConsentFormAvailable()) {
        final form = await ump.ConsentForm.load();
        await form.show();
      }
    } catch (_) {}

    // ATT: iOSのトラッキング許可リクエスト
    if (Platform.isIOS) {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    }

    // Mobile Ads 初期化
    await MobileAds.instance.initialize();
    _initialized = true;

    // 広告の事前ロード
    _loadInterstitial(interstitialIdIOS);
    _loadRewarded(rewardedIdIOS);
  }

  static BannerAd createBanner(String unitId) {
    return BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: const BannerAdListener(),
    );
  }

  static Future<void> showInterstitial({required String unitId}) async {
    if (_interstitial == null) {
      await _loadInterstitial(unitId);
    }
    _interstitial?.show();
    _interstitial = null;
    _loadInterstitial(unitId);
  }

  static Future<void> showRewarded({
    required String unitId,
    required void Function(RewardItem reward) onReward,
  }) async {
    if (_rewarded == null) {
      await _loadRewarded(unitId);
    }
    _rewarded?.show(onUserEarnedReward: onReward);
    _rewarded = null;
    _loadRewarded(unitId);
  }

  static Future<void> _loadInterstitial(String unitId) async {
    await InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (e) => _interstitial = null,
      ),
    );
  }

  static Future<void> _loadRewarded(String unitId) async {
    await RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (e) => _rewarded = null,
      ),
    );
  }
}