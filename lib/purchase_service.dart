// lib/purchase_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService {
  // サブスクリプション (月額・広告非表示)
  static const String _subId = 'liki_shogi_no_ads_monthly';
  static const String _prefKey = 'subscription_active';

  // テーマパック (一回払い)
  static const String _themePackId = 'liki_shogi_theme_pack';
  static const String _themePackPrefKey = 'theme_pack_purchased';

  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;

  static bool _isAvailable = false;
  static bool _hasSubscription = false;
  static bool _hasThemePack = false;
  static ProductDetails? _product;
  static ProductDetails? _themePackProduct;

  static bool get isAvailable => _isAvailable && !kIsWeb;
  static bool get hasSubscription => _hasSubscription;
  static bool get hasThemePack => _hasThemePack;
  static ProductDetails? get product => _product;
  static ProductDetails? get themePackProduct => _themePackProduct;

  /// アプリ起動時に呼ぶ
  static Future<void> initialize() async {
    if (kIsWeb) return;

    // SharedPreferences から既存の購入状態を復元
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasSubscription = prefs.getBool(_prefKey) ?? false;
      _hasThemePack = prefs.getBool(_themePackPrefKey) ?? false;
    } catch (_) {}

    try {
      _isAvailable = await _iap.isAvailable();
      if (!_isAvailable) return;

      // 購入イベントを購読
      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onError: (_) {},
      );

      // 未完了の購入を復元
      await _iap.restorePurchases();

      // 商品情報を取得（サブスク + テーマパック）
      final response = await _iap.queryProductDetails({_subId, _themePackId});
      for (final p in response.productDetails) {
        if (p.id == _subId) _product = p;
        if (p.id == _themePackId) _themePackProduct = p;
      }
    } catch (_) {}
  }

  static void dispose() {
    _subscription?.cancel();
  }

  /// サブスクリプション購入開始
  static Future<bool> purchase() async {
    if (!_isAvailable || _product == null) return false;
    try {
      final param = PurchaseParam(productDetails: _product!);
      return await _iap.buyNonConsumable(purchaseParam: param);
    } catch (_) {
      return false;
    }
  }

  /// テーマパック購入（一回払い）
  static Future<bool> purchaseThemePack() async {
    if (!_isAvailable || _themePackProduct == null) return false;
    try {
      final param = PurchaseParam(productDetails: _themePackProduct!);
      return await _iap.buyNonConsumable(purchaseParam: param);
    } catch (_) {
      return false;
    }
  }

  /// 購入復元
  static Future<void> restore() async {
    if (!_isAvailable) return;
    try {
      await _iap.restorePurchases();
    } catch (_) {}
  }

  static void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID == _subId) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          await _setSubscription(true);
        }
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.productID == _themePackId) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          await _setThemePack(true);
        }
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  static Future<void> _setSubscription(bool value) async {
    _hasSubscription = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {}
  }

  static Future<void> _setThemePack(bool value) async {
    _hasThemePack = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themePackPrefKey, value);
    } catch (_) {}
  }
}
