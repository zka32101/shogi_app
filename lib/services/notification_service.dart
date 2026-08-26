// lib/services/notification_service.dart
// BAN通知とメール送信

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// BANユーザーに通知メールを送信（Cloud Functions 経由）
  Future<void> sendBanNotification(
    String userId,
    String userEmail,
    String username,
    String banReason,
  ) async {
    try {
      // Cloud Functions を呼び出す
      // 実装例: Cloud Functions の HTTP トリガー
      await _firestore.collection('notifications').add({
        'type': 'ban_notification',
        'user_id': userId,
        'email': userEmail,
        'username': username,
        'reason': banReason,
        'created_at': DateTime.now(),
        'sent': false,
      });
    } catch (e) {
    }
  }

  /// BANが解除されたことをメールで通知
  Future<void> sendUnbanNotification(
    String userId,
    String userEmail,
    String username,
  ) async {
    try {
      await _firestore.collection('notifications').add({
        'type': 'unban_notification',
        'user_id': userId,
        'email': userEmail,
        'username': username,
        'created_at': DateTime.now(),
        'sent': false,
      });
    } catch (e) {
    }
  }

  /// ユーザーのメールアドレスを取得
  Future<String?> getUserEmail(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc['email'] as String?;
    } catch (e) {
      return null;
    }
  }
}
