import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import '../models/game_analysis.dart';

class GrowthStoryCard extends StatelessWidget {
  final List<GameAnalysis> allGames;
  final int daysAgo;

  const GrowthStoryCard({
    required this.allGames,
    required this.daysAgo,
  });

  String _getDateLabel(int daysAgo) {
    if (daysAgo == 90) return '3ヶ月前';
    if (daysAgo == 30) return '1ヶ月前';
    if (daysAgo == 14) return '2週間前';
    if (daysAgo == 7) return '1週間前';
    return '${daysAgo}日前';
  }

  Map<String, dynamic> _calculateStats(DateTime targetDate) {
    final pastGames = allGames
        .where((g) => g.playedAt.isBefore(
            DateTime.now().subtract(Duration(days: daysAgo))))
        .toList();
    final recentGames = allGames
        .where((g) => g.playedAt
            .isAfter(DateTime.now().subtract(Duration(days: daysAgo))))
        .toList();

    final pastWins =
        pastGames.where((g) => g.playerWon).length;
    final recentWins =
        recentGames.where((g) => g.playerWon).length;

    final pastWinRate = pastGames.isEmpty
        ? 0.0
        : pastWins / pastGames.length * 100;
    final recentWinRate = recentGames.isEmpty
        ? 0.0
        : recentWins / recentGames.length * 100;

    return {
      'pastWinRate': pastWinRate,
      'recentWinRate': recentWinRate,
      'pastGames': pastGames.length,
      'recentGames': recentGames.length,
      'rateChange': recentWinRate - pastWinRate,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats(
        DateTime.now().subtract(Duration(days: daysAgo)));
    final dateLabel = _getDateLabel(daysAgo);
    final rateChange = stats['rateChange'] as double;
    final isImproved = rateChange > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A2E),
            const Color(0xFF0F3460),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isImproved
              ? Colors.green.withAlpha(100)
              : Colors.orange.withAlpha(100),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isImproved
                ? Colors.green.withAlpha(40)
                : Colors.orange.withAlpha(40),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトル
          Row(
            children: [
              const Icon(Icons.trending_up, color: Colors.cyan, size: 24),
              const SizedBox(width: 12),
              Text(
                'あなたの成長',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.cyan,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 日付
          Text(
            '2026年7月2日',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 20),

          // 過去 → 現在
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  label: dateLabel,
                  winRate:
                      stats['pastWinRate'].toStringAsFixed(0),
                  games: stats['pastGames'] as int,
                  isPast: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  isImproved ? Icons.arrow_forward : Icons.trending_down,
                  color: isImproved
                      ? Colors.green.shade400
                      : Colors.orange.shade400,
                  size: 28,
                ),
              ),
              Expanded(
                child: _buildStatBox(
                  label: '現在',
                  winRate:
                      stats['recentWinRate'].toStringAsFixed(0),
                  games: stats['recentGames'] as int,
                  isPast: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 成長指標
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isImproved
                  ? Colors.green.withAlpha(30)
                  : Colors.orange.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isImproved
                      ? '勝率向上'
                      : '勝率低下',
                  style: TextStyle(
                    color: isImproved
                        ? Colors.green.shade400
                        : Colors.orange.shade400,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${isImproved ? '+' : ''}${rateChange.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: isImproved
                        ? Colors.green.shade400
                        : Colors.orange.shade400,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // メッセージ
          Text(
            isImproved
                ? '${daysAgo}日前のあなたより強くなりました！'
                : '${daysAgo}日前に比べて調整中です。練習を続けましょう！',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required String winRate,
    required int games,
    required bool isPast,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$winRate%',
            style: const TextStyle(
              color: Colors.cyan,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${games}対局',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// 成長ストーリーカードを画像で出力
class GrowthStoryImageGenerator {
  static Future<Uint8List?> generateImage({
    required BuildContext context,
    required List<GameAnalysis> allGames,
    required int daysAgo,
  }) async {
    try {
      final card = GrowthStoryCard(
        allGames: allGames,
        daysAgo: daysAgo,
      );

      final RenderRepaintBoundary repaintBoundary =
          RenderRepaintBoundary();

      final RenderView renderView = RenderView(
        window: WidgetsBinding.instance.window,
        child: RenderPositionedBox(
          alignment: Alignment.center,
          child: card,
        ),
      );

      final PipelineOwner pipelineOwner = PipelineOwner();
      pipelineOwner.rootNode = renderView;
      renderView.prepareInitialFrame();

      final ui.Image image = await repaintBoundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('❌ 画像生成エラー: $e');
      return null;
    }
  }
}
