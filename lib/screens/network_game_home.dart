// lib/screens/network_game_home.dart
// ネットワーク対局ホーム画面

import 'package:flutter/material.dart';
import '../services/network_service.dart';

class NetworkGameHome extends StatefulWidget {
  const NetworkGameHome({super.key});

  @override
  State<NetworkGameHome> createState() => _NetworkGameHomeState();
}

class _NetworkGameHomeState extends State<NetworkGameHome> {
  final NetworkService _networkService = NetworkService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('ネットワーク対局', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                'ネットワーク対局',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

              // 対局ボタン
              ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _startNetworkGame(context),
                icon: const Icon(Icons.public),
                label: const Text('対局を探す'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),

              // マッチング中の表示
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                  ),
                ),

              const SizedBox(height: 40),

              // 説明
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '対局時のルール',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '• ソフト指し（AI支援）は禁止です\n'
                      '• 不正な行動を検出した場合は報告できます\n'
                      '• 一定数の報告でアカウントが停止されます\n'
                      '• 健全なコミュニティを保ちましょう',
                      style: TextStyle(color: Colors.white70, height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startNetworkGame(BuildContext context) async {
    setState(() => _isLoading = true);

    try {
      final currentUser = _networkService.currentUser;
      if (currentUser == null) {
        throw Exception('ログインが必要です');
      }

      // ✅ 対局前 BAN チェック
      final isBanned = await _networkService.isUserBanned(currentUser.uid);
      if (isBanned) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('アカウント停止'),
              content: const Text(
                'このアカウントは不正行為のため停止されています。\n\n'
                '詳細は support@kouki.jp までお問い合わせください。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('閉じる'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // ② ユーザー情報を取得
      final userProfile = await _networkService.getUserProfile(currentUser.uid);
      if (userProfile == null) {
        throw Exception('ユーザー情報が見つかりません');
      }

      // ③ マッチング処理開始
      // TODO: マッチング実装
      // 実装例：
      // 1. 同時にマッチング待機中のユーザーを検索
      // 2. レーティング近いユーザーとマッチング
      // 3. Match ドキュメント作成 → MatchScreen へ遷移

      await Future.delayed(const Duration(seconds: 2)); // ダミー

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('対戦相手が見つかりました')),
        );
        // TODO: Navigator.push(context, MaterialPageRoute(builder: (_) => MatchScreen(...)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
