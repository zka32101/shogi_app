// lib/services/chat_service.dart
// 対局中チャット + 定型文メッセージ

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final bool isPreset; // 定型文かどうか
  final DateTime sentAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.isPreset = false,
    required this.sentAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_id': senderId,
        'sender_name': senderName,
        'text': text,
        'is_preset': isPreset,
        'sent_at': sentAt,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        senderId: json['sender_id'] as String,
        senderName: json['sender_name'] as String,
        text: json['text'] as String,
        isPreset: json['is_preset'] as bool? ?? false,
        sentAt: json['sent_at'] is Timestamp
            ? (json['sent_at'] as Timestamp).toDate()
            : DateTime.parse(json['sent_at'].toString()),
      );
}

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 定型文リスト（将棋の礼儀・対局中のコミュニケーション）
  static const List<String> presetMessages = [
    'よろしくお願いします🙇',
    'ありがとうございました🙏',
    'お疲れ様でした！',
    '良い対局でした👍',
    'もう一局お願いします！',
    '考え中...',
    '惜しかった！',
    '参りました🙇',
  ];

  // ── メッセージ送信 ────────────────────────────

  Future<void> sendMessage({
    required String matchId,
    required String senderId,
    required String senderName,
    required String text,
    bool isPreset = false,
  }) async {
    try {
      // チャットは1マッチ100件まで（スパム防止）
      final count = await _getMessageCount(matchId);
      if (count >= 100) return;

      final ref = _firestore
          .collection('matches')
          .doc(matchId)
          .collection('chat')
          .doc();

      final msg = ChatMessage(
        id: ref.id,
        senderId: senderId,
        senderName: senderName,
        text: text,
        isPreset: isPreset,
        sentAt: DateTime.now(),
      );

      await ref.set(msg.toJson());
    } catch (e) {
      print('Send message error: $e');
    }
  }

  Future<void> sendPresetMessage({
    required String matchId,
    required String senderId,
    required String senderName,
    required String presetText,
  }) =>
      sendMessage(
        matchId: matchId,
        senderId: senderId,
        senderName: senderName,
        text: presetText,
        isPreset: true,
      );

  // ── メッセージ取得 ────────────────────────────

  Stream<List<ChatMessage>> watchMessages(String matchId) {
    return _firestore
        .collection('matches')
        .doc(matchId)
        .collection('chat')
        .orderBy('sent_at', descending: false)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatMessage.fromJson(d.data()))
            .toList());
  }

  Future<int> _getMessageCount(String matchId) async {
    final snap = await _firestore
        .collection('matches')
        .doc(matchId)
        .collection('chat')
        .count()
        .get();
    return snap.count ?? 0;
  }

  // ── 対局後チャット（観戦・感想戦） ────────────────────────────

  Future<void> sendPostMatchMessage({
    required String matchId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    try {
      final ref = _firestore
          .collection('matches')
          .doc(matchId)
          .collection('post_chat')
          .doc();

      await ref.set({
        'id': ref.id,
        'sender_id': senderId,
        'sender_name': senderName,
        'text': text,
        'sent_at': DateTime.now(),
      });
    } catch (e) {
      print('Send post match message error: $e');
    }
  }

  Stream<List<ChatMessage>> watchPostMatchMessages(String matchId) {
    return _firestore
        .collection('matches')
        .doc(matchId)
        .collection('post_chat')
        .orderBy('sent_at', descending: false)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatMessage.fromJson(d.data()))
            .toList());
  }
}
