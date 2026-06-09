// lib/screens/network_game_home.dart
// ネットワーク対局ホーム画面

import 'package:flutter/material.dart';
import '../services/network_service.dart';
import '../services/matching_service.dart';
import 'match_screen.dart';

class NetworkGameHome extends StatefulWidget {
  const NetworkGameHome({super.key});

  @override
  State<NetworkGameHome> createState() => _NetworkGameHomeState();
}

class _NetworkGameHomeState extends State<NetworkGameHome> {
  final NetworkService _networkService = NetworkService();
  final MatchingService _matchingService = MatchingService();
  bool _isLoading = false;
  String? _queueId;

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
      final userProfile =
          await _networkService.getUserProfile(currentUser.uid);
      if (userProfile == null) {
        throw Exception('ユーザー情報が見つかりません');
      }

      // ③ マッチング待機キューに参加
      final queueId = await _matchingService.joinMatchingQueue(
        currentUser.uid,
        userProfile,
        100, // ±100のレーティング範囲
      );

      setState(() => _queueId = queueId);

      // ④ マッチング結果を待機
      if (mounted) {
        _showMatchingWaitDialog(context, queueId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  /// マッチング待機ダイアログ
  void _showMatchingWaitDialog(BuildContext context, String queueId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          '対戦相手を探索中...',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
            const SizedBox(height: 16),
            const Text(
              '相手が見つかるまでお待ちください\n（最大5分）',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            StreamBuilder<dynamic>(
              stream: _matchingService.watchMatchingQueue(queueId),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  final queue = snapshot.data;

                  // マッチング成功
                  if (queue.isMatched && queue.matchId != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Navigator.pop(context); // ダイアログを閉じる
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MatchScreen(
                            matchId: queue.matchId,
                            isPlayer1: true, // TODO: 実装で確認
                          ),
                        ),
                      );
                    });
                  }

                  // マッチング失敗（タイムアウト）
                  if (queue.isCancelled) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('相手が見つかりませんでした'),
                        ),
                      );
                      if (mounted) {
                        setState(() => _isLoading = false);
                      }
                    });
                  }
                }

                return ElevatedButton(
                  onPressed: () async {
                    await _matchingService.cancelMatchingQueue(queueId);
                    if (mounted) {
                      Navigator.pop(context);
                      setState(() => _isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                  ),
                  child: const Text('キャンセル'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
