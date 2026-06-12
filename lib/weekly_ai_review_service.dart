// lib/weekly_ai_review_service.dart
// AI週次振り返りレポート - Cloud Functions経由でClaude APIを呼び出し

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_personality.dart';

class WeeklyAiReview {
  final String weekKey;
  final int gamesPlayed;
  final int wins;
  final int losses;
  final String summary;
  final List<String> dialogues; // AIキャラからのセリフアドバイス
  final String improvementArea;

  WeeklyAiReview({
    required this.weekKey,
    required this.gamesPlayed,
    required this.wins,
    required this.losses,
    required this.summary,
    required this.dialogues,
    required this.improvementArea,
  });
}

class WeeklyAiReviewService {
  static const String _reviewCollection = 'weekly_ai_reviews';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 週次振り返りレポートを生成（Cloud Functions経由）
  static Future<WeeklyAiReview?> generateWeeklyReview() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekKey =
          '${weekStart.year}-W${(weekStart.day / 7).ceil()}';

      // Cloud Functions呼び出し（generate-weekly-review）
      final result = await _firestore.ref('users/$uid/functions/generateWeeklyReview')
          .transaction((transaction) async {
        return await transaction.get();
      }).catch((_) => null);

      if (result == null) {
        // ローカル生成フォールバック
        return await _generateLocalReview(weekKey);
      }

      return WeeklyAiReview(
        weekKey: weekKey,
        gamesPlayed: result['games_played'] ?? 0,
        wins: result['wins'] ?? 0,
        losses: result['losses'] ?? 0,
        summary: result['summary'] ?? '',
        dialogues: List<String>.from(result['dialogues'] as List? ?? []),
        improvementArea: result['improvement_area'] ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// ローカルで簡易レビュー生成（API呼び出し不可の場合）
  static Future<WeeklyAiReview?> _generateLocalReview(String weekKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gamesPlayed = prefs.getInt('weekly_streak_$weekKey') ?? 0;
      final rating = prefs.getInt('rating_current') ?? 0;
      final attack = prefs.getInt('playstyle_attack') ?? 0;
      final total = prefs.getInt('playstyle_total') ?? 1;

      final dialogues = <String>[];
      final improvementArea = _getImprovementArea(attack / total, rating);

      // キャラクターセリフで励まし
      if (gamesPlayed > 10) {
        dialogues.add('よく頑張ったな。10試合以上も指したか。');
      }
      if (rating > 1200) {
        dialogues.add('なかなかの腕前だ。次も期待している。');
      }

      return WeeklyAiReview(
        weekKey: weekKey,
        gamesPlayed: gamesPlayed,
        wins: gamesPlayed,
        losses: 0,
        summary: '今週は $gamesPlayed 回の対局を行いました。',
        dialogues: dialogues,
        improvementArea: improvementArea,
      );
    } catch (_) {
      return null;
    }
  }

  /// 改善区域を判定
  static String _getImprovementArea(double attackRatio, int rating) {
    if (attackRatio > 0.45) {
      return '守備力の強化を心がけましょう';
    } else if (attackRatio < 0.30) {
      return '積極的な攻めを意識してみてください';
    } else if (rating < 1000) {
      return 'ゴースト棋士との対局で経験を積みましょう';
    } else {
      return 'バランスの取れた棋風をさらに磨きましょう';
    }
  }

  /// 振り返りをFirestoreに保存
  static Future<void> saveReview(WeeklyAiReview review) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection(_reviewCollection)
          .doc(review.weekKey)
          .set({
        'week_key': review.weekKey,
        'games_played': review.gamesPlayed,
        'wins': review.wins,
        'losses': review.losses,
        'summary': review.summary,
        'dialogues': review.dialogues,
        'improvement_area': review.improvementArea,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// 過去の振り返りを取得
  static Future<List<WeeklyAiReview>> getPastReviews({int limit = 4}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection(_reviewCollection)
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        return WeeklyAiReview(
          weekKey: data['week_key'] ?? '',
          gamesPlayed: data['games_played'] ?? 0,
          wins: data['wins'] ?? 0,
          losses: data['losses'] ?? 0,
          summary: data['summary'] ?? '',
          dialogues: List<String>.from(data['dialogues'] as List? ?? []),
          improvementArea: data['improvement_area'] ?? '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
