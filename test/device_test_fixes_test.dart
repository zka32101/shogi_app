import 'package:flutter_test/flutter_test.dart';
import 'package:shogi_app/purchase_messages.dart';
import 'package:shogi_app/purchase_service.dart';
import 'package:shogi_app/services/firebase_logging_service.dart';

void main() {
  group('購入結果の文言', () {
    test('商品が取得できない場合は「キャンセル」と表示しない', () {
      final msg = purchaseOutcomeMessage(PurchaseOutcome.unavailable, '300円');
      expect(msg, isNot(contains('キャンセル')));
      expect(msg, contains('購入できません'));
    });

    test('ユーザーのキャンセルだけが「キャンセル」と表示される', () {
      expect(purchaseOutcomeMessage(PurchaseOutcome.canceled, '300円'),
          contains('キャンセル'));
      expect(purchaseOutcomeMessage(PurchaseOutcome.failed, '300円'),
          isNot(contains('キャンセル')));
    });

    test('購入成功はプラン名入りで表示される', () {
      expect(purchaseOutcomeMessage(PurchaseOutcome.purchased, '500円'),
          '500円プランを購入しました！');
    });

    test('全ての結果に空でない文言がある', () {
      for (final o in PurchaseOutcome.values) {
        expect(purchaseOutcomeMessage(o, '300円'), isNotEmpty);
      }
    });
  });

  group('FirebaseLoggingService', () {
    // Firebase 未初期化の状態では、以前は FirebaseAuth.instance が
    // [core/no-app] を投げ、未処理例外になっていた。
    TestWidgetsFlutterBinding.ensureInitialized();

    test('未初期化でもログ記録が例外を投げない', () async {
      await FirebaseLoggingService.logGameStart(
        gameMode: 'vsAI',
        opponentId: null,
        aiCharacterId: 'test',
        handicap: 0,
      );
      await FirebaseLoggingService.logGameEnd(
        gameMode: 'vsAI',
        opponentId: null,
        result: '先手の勝ち！',
        moveCount: 10,
        elapsedSeconds: 1,
      );
    });
  });
}
