// lib/services/network_service.dart
// Firebase ネットワーク対局・報告機能

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user_profile.dart';
import '../models/match.dart';
import '../models/report.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();

  factory NetworkService() {
    return _instance;
  }

  NetworkService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── ユーザー認証 ────────────────────────────
  Future<bool> initFirebase() async {
    try {
      await Firebase.initializeApp();
      return true;
    } catch (e) {
      print('Firebase init error: $e');
      return false;
    }
  }

  Future<UserProfile?> signInWithGoogle() async {
    try {
      // Google サインイン（実装は GoogleSignIn パッケージが必要）
      // TODO: GoogleSignIn 実装
      return null;
    } catch (e) {
      print('Google sign in error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
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
      print('Get user profile error: $e');
      return null;
    }
  }

  Future<void> createUserProfile(String uid, UserProfile profile) async {
    try {
      await _firestore.collection('users').doc(uid).set(profile.toJson());
    } catch (e) {
      print('Create user profile error: $e');
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      print('Update user profile error: $e');
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
      print('Create match error: $e');
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
      print('Get match error: $e');
      return null;
    }
  }

  Future<void> updateMatchBoard(String matchId, String boardState) async {
    try {
      await _firestore.collection('matches').doc(matchId).update({
        'board_state': boardState,
      });
    } catch (e) {
      print('Update match board error: $e');
    }
  }

  Future<void> finishMatch(String matchId, String winnerId) async {
    try {
      await _firestore.collection('matches').doc(matchId).update({
        'winner': winnerId,
      });
    } catch (e) {
      print('Finish match error: $e');
    }
  }

  // ── 報告機能 ────────────────────────────
  /// 不正報告を作成（報告数10件で自動停止）
  Future<bool> submitReport(
    String reporterUid,
    String reportedUid,
    String matchId,
    String reason,
  ) async {
    try {
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

      // 報告を保存
      await reportRef.set(report.toJson());

      // 報告数をカウント
      final reportsSnapshot = await _firestore
          .collection('reports')
          .where('reported_user_id', isEqualTo: reportedUid)
          .where('status', isEqualTo: 'pending')
          .get();

      // 報告数が10以上で自動停止
      if (reportsSnapshot.docs.length >= 10) {
        await _firestore.collection('users').doc(reportedUid).update({
          'is_banned': true,
          'banned_at': DateTime.now(),
        });
      }

      return true;
    } catch (e) {
      print('Submit report error: $e');
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
      print('Get report count error: $e');
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
      print('Is user banned error: $e');
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
      print('Review report error: $e');
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
