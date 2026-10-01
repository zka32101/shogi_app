// lib/purchase_messages.dart
// 購入結果をユーザー向けの文言にする（画面から分離してテスト可能にする）
import 'purchase_service.dart';

String purchaseOutcomeMessage(PurchaseOutcome outcome, String planLabel) {
  switch (outcome) {
    case PurchaseOutcome.purchased:
      return '$planLabelプランを購入しました！';
    case PurchaseOutcome.canceled:
      return '購入をキャンセルしました';
    case PurchaseOutcome.unavailable:
      return '現在この商品を購入できません。Google Playから商品情報を取得できませんでした。'
          'しばらくしてからもう一度お試しください';
    case PurchaseOutcome.failed:
      return '購入を完了できませんでした。しばらくしてからもう一度お試しください';
  }
}
