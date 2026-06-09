// lib/screens/admin_panel_screen.dart
// 管理者向け管理画面

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/network_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final NetworkService _networkService = NetworkService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _tabIndex = 0; // 0: 報告一覧、1: BAN済みユーザー

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('管理パネル', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // タブ
            Container(
              color: const Color(0xFF16213E),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton('報告一覧', 0),
                  ),
                  Expanded(
                    child: _buildTabButton('BAN済みユーザー', 1),
                  ),
                ],
              ),
            ),
            // コンテンツ
            Expanded(
              child: _tabIndex == 0
                  ? _buildReportsList()
                  : _buildBannedUsersList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isActive = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? Colors.amber : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? Colors.amber : Colors.white70,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ① 報告一覧
  Widget _buildReportsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data!.docs;
        if (reports.isEmpty) {
          return const Center(
            child: Text('待機中の報告はありません',
                style: TextStyle(color: Colors.white70)),
          );
        }

        return ListView.builder(
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            final data = report.data() as Map<String, dynamic>;

            return Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '報告ID: ${report.id.substring(0, 8)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(100),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          data['reason'] == 'soft_play'
                              ? 'ソフト指し'
                              : data['reason'] == 'time_cheat'
                                  ? 'タイムチート'
                                  : 'その他',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '報告対象: ${data['reported_user_id'].substring(0, 8)}...',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(
                    '報告者: ${data['reporter_id'].substring(0, 8)}...',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () =>
                            _approveReport(report.id, data['reported_user_id']),
                        icon: const Icon(Icons.check),
                        label: const Text('承認'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _dismissReport(report.id),
                        icon: const Icon(Icons.close),
                        label: const Text('却下'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ② BAN済みユーザー一覧
  Widget _buildBannedUsersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('is_banned', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;
        if (users.isEmpty) {
          return const Center(
            child: Text('BAN済みユーザーはいません',
                style: TextStyle(color: Colors.white70)),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final data = user.data() as Map<String, dynamic>;

            final bannedAt = data['banned_at'] != null
                ? DateTime.parse(data['banned_at'].toString())
                : null;
            final reason = data['ban_reason'] ?? 'unknown';
            final reasonLabel = reason == 'too_many_reports'
                ? '報告多数'
                : reason == 'spam_reporting'
                    ? '報告スパム'
                    : 'その他';

            return Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withAlpha(80),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['username'] ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'UID: ${user.id.substring(0, 8)}...',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          reasonLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (bannedAt != null)
                    Text(
                      'BAN日時: ${bannedAt.toString().substring(0, 16)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _unbanUser(user.id),
                    icon: const Icon(Icons.restore),
                    label: const Text('BAN解除'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 報告を承認（ユーザーをBAN）
  Future<void> _approveReport(String reportId, String reportedUid) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': 'reviewed',
      });

      await _firestore.collection('users').doc(reportedUid).update({
        'is_banned': true,
        'banned_at': DateTime.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('報告を承認しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  // 報告を却下
  Future<void> _dismissReport(String reportId) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': 'dismissed',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('報告を却下しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  // BANを解除
  Future<void> _unbanUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'is_banned': false,
        'banned_at': null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('BAN を解除しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }
}
