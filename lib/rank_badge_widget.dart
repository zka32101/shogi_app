// lib/rank_badge_widget.dart — 段位バッジウィジェット

import 'package:flutter/material.dart';
import 'stats_screen.dart' show ratingToRank, ratingToColor, rankProgress, nextRankInfo, isDan;

/// 段位バッジ（コンパクト表示）
class RankBadge extends StatelessWidget {
  final int rating;
  final double size;
  final bool showLabel;

  const RankBadge({
    super.key,
    required this.rating,
    this.size = 48,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final rank = ratingToRank(rating);
    final color = ratingToColor(rating);
    final isDanRank = isDan(rank);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withAlpha(200),
                color.withAlpha(80),
              ],
            ),
            border: Border.all(
              color: color,
              width: size >= 60 ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(100),
                blurRadius: size / 3,
              ),
            ],
          ),
          child: Center(
            child: Text(
              rank,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.28,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            'ELO $rating',
            style: TextStyle(color: color.withAlpha(200), fontSize: 10),
          ),
        ],
      ],
    );
  }
}

/// 段位進捗バー
class RankProgressBar extends StatelessWidget {
  final int rating;

  const RankProgressBar({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    final rank = ratingToRank(rating);
    final color = ratingToColor(rating);
    final progress = rankProgress(rating);
    final next = nextRankInfo(rating);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(
              rank,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (next != null) ...[
              Text(
                '次: ${next.$1} まで ${next.$2} ELO',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ] else
              const Text('最高位', style: TextStyle(color: Colors.amber, fontSize: 11)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ELO: $rating',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

/// 段位昇段ダイアログを表示する
Future<void> showRankUpDialog(BuildContext context, String newRank, Color rankColor) {
  return showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF16213E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(
            '昇段おめでとうございます！',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [rankColor.withAlpha(200), rankColor.withAlpha(60)],
              ),
              border: Border.all(color: rankColor, width: 4),
              boxShadow: [BoxShadow(color: rankColor.withAlpha(120), blurRadius: 24)],
            ),
            child: Center(
              child: Text(
                newRank,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$newRank に昇段しました！',
            style: TextStyle(color: rankColor, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: rankColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('ありがとう！', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}
