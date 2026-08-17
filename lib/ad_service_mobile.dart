// lib/ad_service_mobile.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static bool _initialized = false;

  // 本番のAd Unit IDはリリースビルド時に --dart-define で注入する
  // （例: flutter build appbundle --release
  //       --dart-define=ADMOB_ANDROID_BANNER_ID=ca-app-pub-xxxx/yyyy
  //       --dart-define=ADMOB_IOS_BANNER_ID=ca-app-pub-xxxx/zzzz ）。
  // 以前はGoogle公式のテスト広告IDがkDebugModeガードなしでハードコードされて
  // おり、本番リリースでもテスト広告のみが配信され続ける状態だった
  // （AdMobプログラムポリシー違反でアカウント停止リスクがあり、広告収益も出ない）。
  static const _androidBannerReleaseId =
      String.fromEnvironment('ADMOB_ANDROID_BANNER_ID');
  static const _iosBannerReleaseId =
      String.fromEnvironment('ADMOB_IOS_BANNER_ID');

  static String get bannerAdUnitId {
    if (kDebugMode) {
      // Google公式のテスト広告ID（デバッグ/開発時のみ使用可能）
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111' // Android テスト
          : 'ca-app-pub-3940256099942544/2934735716'; // iOS テスト
    }
    final id = Platform.isAndroid ? _androidBannerReleaseId : _iosBannerReleaseId;
    assert(
      id.isNotEmpty,
      'ADMOB_ANDROID_BANNER_ID / ADMOB_IOS_BANNER_ID が --dart-define で'
      '設定されていません。本番のAd Unit IDをAdMob Consoleで発行し、'
      'リリースビルド時に指定してください。',
    );
    return id;
  }

  static bool get isSupported => true;

  static Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
  }
}

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox(height: 50);
    }
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
