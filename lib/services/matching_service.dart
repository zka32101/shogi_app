// lib/services/matching_service.dart
// マッチングシステム

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/matching_queue.dart';
import '../models/user_profile.dart';

class MatchingService {
  static final MatchingService _instance = MatchingService._internal();

  factory MatchingService() {
    return _instance;
  }

  MatchingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // マッチングタイムアウト（秒）
  static const matchingTimeoutSeconds = 300; // 5分

  // ── マッチング待機 ────────────────────────────

  /// マッチング待機キューに参加
  /// [ratingRange]: 対戦相手レーティング許容範囲（±100等）
  Future<String> joinMatchingQueue(
    String userId,
    UserProfile userProfile,
    int ratingRange,
  ) async {
    try {
      final queueRef = _firestore.collection('matching_queue').doc();
      final minRating = (userProfile.rating - ratingRange).clamp(0, 3500);
      final maxRating = userProfile.rating + ratingRange;

      final queue = MatchingQueue(
        id: queueRef.id,
        userId: userId,
        username: userProfile.username,
        rating: userProfile.rating,
        minRatingRange: minRating,
        maxRatingRange: maxRating,
        queuedAt: DateTime.now(),
        status: 'waiting',
      );

      await queueRef.set(queue.toJson());

      // マッチング試行（即座に相手を探す）
      await _tryMatchmaking(queue);

      return queueRef.id;
    } catch (e) {
      print('Join matching queue error: $e');
      rethrow;
    }
  }

  /// マッチング待機をキャンセル
  Future<void> cancelMatchingQueue(String queueId) async {
    try {
      await _firestore.collection('matching_queue').doc(queueId).update({
        'status': 'cancelled',
      });
    } catch (e) {
      print('Cancel matching queue error: $e');
    }
  }

  // ── 自動マッチング ────────────────────────────

  /// マッチメイキング試行
  Future<void> _tryMatchmaking(MatchingQueue queue) async {
    try {
      // 待機中の他ユーザーを検索
      final otherQueues = await _firestore
          .collection('matching_queue')
          .where('status', isEqualTo: 'waiting')
          .where('user_id', isNotEqualTo: queue.userId)
          .get();

      // 相互にレーティング範囲内のユーザーを探す
      for (final doc in otherQueues.docs) {
        final otherQueue = MatchingQueue.fromJson(doc.data());

        // 双方向でレーティング範囲内か確認
        if (queue.canMatch(otherQueue.rating) &&
            otherQueue.canMatch(queue.rating)) {
          // マッチング成立
          await _createMatch(queue, otherQueue);
          return;
        }
      }

      // 相手が見つからない場合、タイムアウトリスナーを設定
      _setMatchingTimeout(queue.id);
    } catch (e) {
      print('Try matchmaking error: $e');
    }
  }

  /// マッチング成立 → Match ドキュメント作成
  Future<void> _createMatch(
    MatchingQueue queue1,
    MatchingQueue queue2,
  ) async {
    try {
      final matchRef = _firestore.collection('matches').doc();
      final now = DateTime.now();

      await matchRef.set({
        'id': matchRef.id,
        'player1_id': queue1.userId,
        'player1_name': queue1.username,
        'player1_rating': queue1.rating,
        'player2_id': queue2.userId,
        'player2_name': queue2.username,
        'player2_rating': queue2.rating,
        'board_state': '', // 初期盤面（詰将棋なら空）
        'current_turn': 1, // 先手のターン
        'moves': [], // 指し手の履歴
        'player1_time': 600, // 時間（秒）
        'player2_time': 600,
        'status': 'playing', // playing, finished, cancelled
        'winner': null,
        'result': null, // 'checkmate', 'resignation', 'timeout', 'draw'
        'created_at': now,
        'started_at': now,
        'finished_at': null,
      });

      // マッチング待機キューを更新
      await _firestore.collection('matching_queue').doc(queue1.id).update({
        'status': 'matched',
        'matched_with': queue2.userId,
        'match_id': matchRef.id,
      });

      await _firestore.collection('matching_queue').doc(queue2.id).update({
        'status': 'matched',
        'matched_with': queue1.userId,
        'match_id': matchRef.id,
      });

      print('Match created: ${matchRef.id}');
    } catch (e) {
      print('Create match error: $e');
    }
  }

  /// マッチングタイムアウト設定（5分待機して見つからない場合キャンセル）
  void _setMatchingTimeout(String queueId) {
    Future.delayed(const Duration(seconds: matchingTimeoutSeconds), () async {
      try {
        final doc = await _firestore
            .collection('matching_queue')
            .doc(queueId)
            .get();

        if (doc.exists && doc['status'] == 'waiting') {
          await cancelMatchingQueue(queueId);
          print('Matching timeout for queue: $queueId');
        }
      } catch (e) {
        print('Matching timeout error: $e');
      }
    });
  }

  // ── マッチング状態監視 ────────────────────────────

  /// マッチング待機キューをリアルタイム監視
  Stream<MatchingQueue?> watchMatchingQueue(String queueId) {
    return _firestore
        .collection('matching_queue')
        .doc(queueId)
        .snapshots()
        .map((doc) {
      return doc.exists ? MatchingQueue.fromJson(doc.data()!) : null;
    });
  }

  /// マッチを監視
  Stream<Map<String, dynamic>?> watchMatch(String matchId) {
    return _firestore.collection('matches').doc(matchId).snapshots().map((doc) {
      return doc.exists ? doc.data() : null;
    });
  }

  // ── ゲーム終了 ────────────────────────────

  /// マッチを終了
  Future<void> finishMatch(
    String matchId,
    String? winnerId,
    String result, // 'checkmate', 'resignation', 'timeout', 'draw'
  ) async {
    try {
      await _firestore.collection('matches').doc(matchId).update({
        'status': 'finished',
        'winner': winnerId,
        'result': result,
        'finished_at': DateTime.now(),
      });

      print('Match finished: $matchId, winner: $winnerId, result: $result');
    } catch (e) {
      print('Finish match error: $e');
    }
  }

  /// マッチをキャンセル（接続エラー等）
  Future<void> cancelMatch(String matchId) async {
    try {
      await _firestore.collection('matches').doc(matchId).update({
        'status': 'cancelled',
        'finished_at': DateTime.now(),
      });
    } catch (e) {
      print('Cancel match error: $e');
    }
  }
}
