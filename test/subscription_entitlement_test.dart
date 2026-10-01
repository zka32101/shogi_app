import 'package:flutter_test/flutter_test.dart';
import 'package:shogi_app/purchase_service.dart';

void main() {
  group('月額プランの権利判定', () {
    test('有効な購入に含まれていれば権利あり', () {
      expect(
        entitlementAfterVerification(
          productId: 'liki_shogi_plan_300',
          activeProductIds: {'liki_shogi_plan_300'},
        ),
        isTrue,
      );
    });

    test('解約・期限切れで有効な購入に無ければ権利を外す', () {
      expect(
        entitlementAfterVerification(
          productId: 'liki_shogi_plan_300',
          activeProductIds: <String>{},
        ),
        isFalse,
      );
    });

    test('別のプランだけ有効なら、もう一方の権利は付与しない', () {
      expect(
        entitlementAfterVerification(
          productId: 'liki_shogi_plan_300',
          activeProductIds: {'liki_shogi_plan_500'},
        ),
        isFalse,
      );
      expect(
        entitlementAfterVerification(
          productId: 'liki_shogi_plan_500',
          activeProductIds: {'liki_shogi_plan_500'},
        ),
        isTrue,
      );
    });
  });
}
