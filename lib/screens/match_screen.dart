// lib/screens/match_screen.dart
// リアルタイム対局画面

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/matching_service.dart';
import '../services/network_service.dart';

class MatchScreen extends StatefulWidget {
  final String matchId;
  final bool isPlayer1;

  const MatchScreen({
    super.key,
    required this.matchId,
    required this.isPlayer1,
  });

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final MatchingService _matchingService = MatchingService();
  final NetworkService _networkService = NetworkService();

  late Stream<Map<String, dynamic>?> _matchStream;
  bool _isResigning = false;

  @override
  void initState() {
    super.initState();
    _matchStream = _matchingService.watchMatch(widget.matchId);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 対局中は戻るボタンを無効化
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('対局中です。投了で終了してください。')),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16213E),
          title: const Text('対局中', style: TextStyle(color: Colors.white)),
          automaticallyImplyLeading: false,
        ),
        body: StreamBuilder<Map<String, dynamic>?>(
          stream: _matchStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final match = snapshot.data!;
            final isMyTurn = (match['current_turn'] == 1 && widget.isPlayer1) ||
                (match['current_turn'] == 2 && !widget.isPlayer1);
            final myTime = widget.isPlayer1
                ? match['player1_time'] as int
                : match['player2_time'] as int;
            final opponentTime = widget.isPlayer1
                ? match['player2_time'] as int
                : match['player1_time'] as int;
            final status = match['status'] as String;

            // ゲーム終了時
            if (status == 'finished') {
              return _buildGameOverScreen(match);
            }

            return SafeArea(
              child: Column(
                children: [
                  // ① 対手情報 + タイマー
                  _buildOpponentCard(
                    match['player2_name'] if widget.isPlayer1
                        else match['player1_name'],
                    match['player2_rating'] if widget.isPlayer1
                        else match['player1_rating'],
                    opponentTime,
                  ),

                  const SizedBox(height: 16),

                  // ② 盤面（簡略版）
                  Expanded(
                    child: Center(
                      child: Container(
                        color: Colors.grey.shade900,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '将棋盤\n（実装中）',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: Colors.white54, fontSize: 20),
                            ),
                            const SizedBox(height: 20),
                            if (isMyTurn)
                              const Text(
                                'あなたのターン',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            else
                              const Text(
                                '相手を待機中...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ③ 自分の情報 + タイマー
                  _buildPlayerCard(
                    _networkService.currentUser?.email ?? 'You',
                    match['player1_rating'] if widget.isPlayer1
                        else match['player2_rating'],
                    myTime,
                  ),

                  // ④ 操作ボタン
                  _buildActionButtons(isMyTurn, match),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOpponentCard(String name, int rating, int timeSeconds) {
    final timeDisplay = _formatTime(timeSeconds);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'レート: $rating',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeDisplay,
                style: TextStyle(
                  color: timeSeconds < 60 ? Colors.red : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                '残り時間',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(String name, int rating, int timeSeconds) {
    final timeDisplay = _formatTime(timeSeconds);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade900.withAlpha(100),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'レート: $rating',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeDisplay,
                style: TextStyle(
                  color: timeSeconds < 60 ? Colors.red : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'あなた',
                style: TextStyle(color: Colors.cyan, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isMyTurn, Map<String, dynamic> match) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isMyTurn ? () {} : null,
              icon: const Icon(Icons.check),
              label: const Text('手を指す'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isMyTurn ? Colors.blue.shade700 : Colors.grey,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isResigning ? null : _resignMatch,
            icon: const Icon(Icons.flag),
            label: const Text('投了'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverScreen(Map<String, dynamic> match) {
    final winner = match['winner'] as String?;
    final result = match['result'] as String?;
    final isWinner = winner == _networkService.currentUser?.uid;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isWinner ? Icons.emoji_events : Icons.close_circle,
            size: 80,
            color: isWinner ? Colors.amber : Colors.grey,
          ),
          const SizedBox(height: 20),
          Text(
            isWinner ? '勝利！' : '敗北',
            style: TextStyle(
              color: isWinner ? Colors.amber : Colors.grey,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '結果: $result',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
            ),
            child: const Text('対局一覧に戻る'),
          ),
        ],
      ),
    );
  }

  Future<void> _resignMatch() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('投了しますか？'),
        content: const Text('この対局を終了します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('投了'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isResigning = true);

      // 相手をウィナーとして設定
      final opponentId = widget.isPlayer1
          ? (await _firestore.collection('matches').doc(widget.matchId).get())
              ['player2_id']
          : (await _firestore.collection('matches').doc(widget.matchId).get())
              ['player1_id'];

      await _matchingService.finishMatch(
        widget.matchId,
        opponentId,
        'resignation',
      );

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  late FirebaseFirestore _firestore = FirebaseFirestore.instance;
}
