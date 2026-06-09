// lib/screens/report_user_screen.dart
// ユーザー不正報告画面

import 'package:flutter/material.dart';
import '../services/network_service.dart';
import '../models/report.dart';

class ReportUserScreen extends StatefulWidget {
  final String reportedUserId;
  final String reportedUsername;
  final String matchId;

  const ReportUserScreen({
    super.key,
    required this.reportedUserId,
    required this.reportedUsername,
    required this.matchId,
  });

  @override
  State<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen> {
  final NetworkService _networkService = NetworkService();
  String? _selectedReason;
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('ユーザーを報告', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // 報告対象ユーザー
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '報告対象ユーザー',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.reportedUsername,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 報告理由
              const Text(
                '報告理由',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // ラジオボタン
              _buildReasonOption('soft_play', 'ソフト指し（AI支援）'),
              _buildReasonOption('time_cheat', 'タイムチート'),
              _buildReasonOption('other', 'その他の不正'),

              const SizedBox(height: 24),

              // 詳細（オプション）
              const Text(
                '詳細（オプション）',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _detailsController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '不正の詳細を記入してください',
                  hintStyle: TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.grey.shade900,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 警告テキスト
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '⚠️ 虚偽の報告は禁止です。不正な報告を繰り返すと、あなたのアカウントがペナルティを受ける可能性があります。',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),

              const SizedBox(height: 24),

              // 報告ボタン
              ElevatedButton(
                onPressed: _selectedReason == null || _isSubmitting
                    ? null
                    : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('報告を送信'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReasonOption(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: _selectedReason == value
              ? Colors.brown.shade700.withAlpha(100)
              : Colors.grey.shade900,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _selectedReason == value
                ? Colors.brown.shade700
                : Colors.transparent,
          ),
        ),
        child: RadioListTile<String>(
          value: value,
          groupValue: _selectedReason,
          onChanged: (v) => setState(() => _selectedReason = v),
          title: Text(label, style: const TextStyle(color: Colors.white)),
          activeColor: Colors.amber,
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    setState(() => _isSubmitting = true);

    try {
      final currentUser = _networkService.currentUser;
      if (currentUser == null) {
        throw Exception('ログインが必要です');
      }

      final success = await _networkService.submitReport(
        currentUser.uid,
        widget.reportedUserId,
        widget.matchId,
        _selectedReason!,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('報告を送信しました')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('報告に失敗しました')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
