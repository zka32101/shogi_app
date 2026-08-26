// lib/services/network_service.dart
// Firebase ネットワーク対局・報告機能

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_profile.dart';
import '../models/match.dart';
import '../models/report.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'network_achievement_service.dart'; // 将来の実装用（Cloud Functions移行後に削除可）
import 'daily_challenge_service.dart';     // 将来の実装用
import 'fcm_service.dart';
import 'friend_service.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();

  factory NetworkService() {
    return _instance;
  }

  NetworkService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final NetworkAchievementService _achievementService =
      NetworkAchievementService();
  final DailyChallengeService _dailyChallengeService =
      DailyChallengeService();
  final FcmService _fcmService = FcmService();

  // ── ユーザー認証 ────────────────────────────
  Future<bool> initFirebase() async {
    try {
      // Firebase.initializeApp() は main.dart で実行済み
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously()
            .timeout(const Duration(seconds: 5));
      } else {
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> signOut() async {
    // 認証が切れる前に、この端末のFCMトークンを現ユーザーのfcm_tokensから
    // 削除しておく（呼ばないと、同じ端末で別アカウントにサインインした際に
    // 旧ユーザーが新ユーザー宛のプッシュ通知を受け取り続けてしまう）
    try {
      await _fcmService.removeCurrentToken();
    } catch (_) {}
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  // ── ユーザープロフィール ────────────────────────────
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserProfile.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> createUserProfile(String uid, UserProfile profile) async {
    try {
      await _firestore.collection('users').doc(uid).set(profile.toJson());
    } catch (e) {
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
    }
  }

  // ── 対局情報 ────────────────────────────
  Future<String> createMatch(String player1Id, String player2Id) async {
    try {
      final matchRef = _firestore.collection('matches').doc();
      final match = Match(
        id: matchRef.id,
        player1Id: player1Id,
        player2Id: player2Id,
        boardState: '', // 初期盤面
        winner: null,
        createdAt: DateTime.now(),
      );
      await matchRef.set(match.toJson());
      return matchRef.id;
    } catch (e) {
      return '';
    }
  }

  Future<Match?> getMatch(String matchId) async {
    try {
      final doc = await _firestore.collection('matches').doc(matchId).get();
      if (doc.exists) {
        return Match.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateMatchBoard(String matchId, String boardState) async {
    try {
      await _firestore.collection('matches').doc(matchId).update({
        'board_state': boardState,
      });
    } catch (e) {
    }
  }

  /// マッチを終了し、ステータスを更新
  /// ELO計算はCloud Functions (onMatchFinished) が自動実行
  /// [matchId]: マッチID
  /// [winnerId]: 勝者のUID（null の場合は引き分け）
  /// [result]: 結果種類（'checkmate', 'resignation', 'timeout', 'draw'）
  Future<void> finishMatchWithRating(
    String matchId,
    String? winnerId,
    String result,
  ) async {
    // RTDBを先に更新（必須: MatchScreenのboardStreamが終了を検知する）。
    // 単純なupdate()だと、両者がほぼ同時に異なる結果（例: 片方は詰み検知、
    // もう片方は時間切れ検知）を確定させた場合に後勝ちで結果が入れ替わって
    // しまうため、「まだactive/未終局の場合のみ確定」というトランザクションで
    // 排他制御する。既に別クライアントが終局を確定済みならabortして何もしない
    // （abortは例外を投げないため、呼び出し元の挙動は変わらない）
    await FirebaseDatabase.instance.ref('games/$matchId').runTransaction((Object? current) {
      if (current == null) return Transaction.abort();
      final data = Map<dynamic, dynamic>.from(current as Map);
      final currentStatus = data['status'] as String?;
      if (currentStatus == 'finished' || currentStatus == 'abandoned') {
        return Transaction.abort();
      }
      data['status'] = 'finished';
      data['winner_id'] = winnerId;
      data['result'] = result;
      return Transaction.success(data);
    });
    // Firestoreへの更新（オプション: 認証エラー時はスキップ）
    try {
      await _firestore.collection('matches').doc(matchId).update({
        'status':      'finished',
        'winner_id':   winnerId,
        'result':      result,
        'finished_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ── 報告機能 ────────────────────────────
  /// 不正報告を作成（報告数10件で自動停止 + 報告スパム検出）
  Future<bool> submitReport(
    String reporterUid,
    String reportedUid,
    String matchId,
    String reason,
  ) async {
    try {
      // ① 報告者がスパム状態かチェック
      final isReporterSpam = await _isReporterSpamming(reporterUid);
      if (isReporterSpam) {
        // BAN確定はセキュリティルール上 Cloud Functions / 管理者のみが行える
        // （is_banned 等はクライアントの isOwner 書き込みから保護されているため、
        // 通常ユーザーの実行ではここは失敗しうる）。実際のBAN処理が失敗しても
        // スパム報告者からの当該報告は受け付けない、という判定自体は維持する
        try {
          final reporterProfile = await getUserProfile(reporterUid);
          await _firestore.collection('users').doc(reporterUid).update({
            'is_banned': true,
            'banned_at': DateTime.now(),
            'ban_reason': 'spam_reporting',
          });

          // 📧 報告者に BAN 通知を送信
          final reporterEmail = await _notificationService.getUserEmail(reporterUid);
          if (reporterEmail != null) {
            await _notificationService.sendBanNotification(
              reporterUid,
              reporterEmail,
              reporterProfile?.username ?? 'User',
              'spam_reporting',
            );
          }
        } catch (e) {
        }
        return false; // 報告を受け付けない
      }

      final reportRef = _firestore.collection('reports').doc();
      final report = Report(
        id: reportRef.id,
        reporterId: reporterUid,
        reportedUserId: reportedUid,
        matchId: matchId,
        reason: reason,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      // ② 報告を保存
      await reportRef.set(report.toJson());

      // ③ 報告対象者の報告数をカウント（待機中のみ）
      final reportsSnapshot = await _firestore
          .collection('reports')
          .where('reported_user_id', isEqualTo: reportedUid)
          .where('status', isEqualTo: 'pending')
          .get();

      // 報告数が10以上で自動停止
      // BAN確定はセキュリティルール上 Cloud Functions / 管理者のみが行える
      // （is_banned は自分以外のユーザーに対しては通常ユーザーから書き込み不可のため、
      // ここは失敗しうる）。この処理が失敗しても報告自体は既に保存済みなので、
      // 呼び出し元には成功として返す
      if (reportsSnapshot.docs.length >= 10) {
        try {
          final reportedProfile = await getUserProfile(reportedUid);
          await _firestore.collection('users').doc(reportedUid).update({
            'is_banned': true,
            'banned_at': DateTime.now(),
            'ban_reason': 'too_many_reports',
          });

          // 📧 報告対象者に BAN 通知を送信
          final reportedEmail = await _notificationService.getUserEmail(reportedUid);
          if (reportedEmail != null) {
            await _notificationService.sendBanNotification(
              reportedUid,
              reportedEmail,
              reportedProfile?.username ?? 'User',
              'too_many_reports',
            );
          }
        } catch (e) {
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 報告者がスパム状態かチェック
  /// - 同一ユーザーへ3件以上の報告
  /// - または報告総数10件以上で却下率80%以上
  Future<bool> _isReporterSpamming(String reporterUid) async {
    try {
      // ① 報告者の全報告を取得
      final allReports = await _firestore
          .collection('reports')
          .where('reporter_id', isEqualTo: reporterUid)
          .get();

      if (allReports.docs.length < 5) return false; // 5件未満はスパムではない

      // ② 同一ユーザーへの重複報告をチェック
      final reportCounts = <String, int>{};
      for (var doc in allReports.docs) {
        final reportedUid = doc['reported_user_id'] as String;
        reportCounts[reportedUid] = (reportCounts[reportedUid] ?? 0) + 1;
      }

      // 同じユーザーに3件以上報告 → スパム
      if (reportCounts.values.any((count) => count >= 3)) {
        return true;
      }

      // ③ 却下率をチェック（報告総数10件以上で却下率80%以上）
      if (allReports.docs.length >= 10) {
        final dismissedCount = allReports.docs
            .where((doc) => doc['status'] == 'dismissed')
            .length;
        final dismissalRate = dismissedCount / allReports.docs.length;

        if (dismissalRate >= 0.8) {
          return true; // 却下率80%以上 → スパム
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// ユーザーの報告数を取得
  Future<int> getReportCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .where('reported_user_id', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// ユーザーがバンされているか確認
  Future<bool> isUserBanned(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['is_banned'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 報告を確認（管理者用）
  Future<void> reviewReport(String reportId, bool approved) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': approved ? 'reviewed' : 'dismissed',
      });
    } catch (e) {
    }
  }

  /// BAN を解除（管理者用）
  Future<void> unbanUser(String userId) async {
    try {
      final userProfile = await getUserProfile(userId);
      await _firestore.collection('users').doc(userId).update({
        'is_banned': false,
        'banned_at': null,
      });

      // 📧 BAN 解除通知を送信
      final userEmail = await _notificationService.getUserEmail(userId);
      if (userEmail != null) {
        await _notificationService.sendUnbanNotification(
          userId,
          userEmail,
          userProfile?.username ?? 'User',
        );
      }
    } catch (e) {
    }
  }

  // ── ブロック機能 ────────────────────────────────────────────

  /// 指定ユーザーをブロック（Firestore の blocked_users サブコレクションに保存）
  Future<void> blockUser(String targetUserId) async {
    final me = currentUser;
    if (me == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(me.uid)
          .collection('blocked_users')
          .doc(targetUserId)
          .set({'blocked_at': FieldValue.serverTimestamp()});

      // ブロック済みでも既存のフレンド関係が残っていると、オンライン状態が
      // 見えたり対局招待を送れたりしてしまうため、フレンド関係があれば解除する
      try {
        await FriendService().removeFriend(me.uid, targetUserId);
      } catch (e) {
      }
    } catch (e) {
    }
  }

  /// ブロック解除
  Future<void> unblockUser(String targetUserId) async {
    final me = currentUser;
    if (me == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(me.uid)
          .collection('blocked_users')
          .doc(targetUserId)
          .delete();
    } catch (e) {
    }
  }

  /// ブロック済みかどうかを確認
  Future<bool> isBlocked(String targetUserId) async {
    final me = currentUser;
    if (me == null) return false;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(me.uid)
          .collection('blocked_users')
          .doc(targetUserId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// ブロック済みユーザー一覧を取得
  Future<List<String>> getBlockedUserIds() async {
    final me = currentUser;
    if (me == null) return [];
    try {
      final snap = await _firestore
          .collection('users')
          .doc(me.uid)
          .collection('blocked_users')
          .get();
      return snap.docs.map((d) => d.id).toList();
    } catch (e) {
      return [];
    }
  }

  // ── ストリーム（リアルタイム監視） ────────────────────────────
  Stream<Match?> watchMatch(String matchId) {
    return _firestore.collection('matches').doc(matchId).snapshots().map((doc) {
      return doc.exists ? Match.fromJson(doc.data()!) : null;
    });
  }

  Stream<UserProfile?> watchUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      return doc.exists ? UserProfile.fromJson(doc.data()!) : null;
    });
  }
}
