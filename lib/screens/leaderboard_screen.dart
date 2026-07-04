import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/game_analysis.dart';
import '../models/game_statistics.dart';

class LeaderboardScreen extends StatefulWidget {
  final List<GameAnalysis> games;

  const LeaderboardScreen({
    required this.games,
    super.key,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _selectedTab = 0; // 0: 全期間, 1: 今月, 2: 先月

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('スコアボード'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // タブバー
          Container(
            color: const Color(0xFF16213E),
            child: Row(
              children: [
                _buildLeaderboardTab('全期間', 0),
                _buildLeaderboardTab('今月', 1),
                _buildLeaderboardTab('先月', 2),
              ],
            ),
          ),
          // コンテンツ
          Expanded(
            child: _buildLeaderboardContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.cyan : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.cyan : Colors.white54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardContent() {
    DateTime startDate;
    DateTime endDate = DateTime.now();

    switch (_selectedTab) {
      case 0:
        // 全期間
        startDate = widget.games.isEmpty ? DateTime.now() : widget.games.last.playedAt;
        break;
      case 1:
        // 今月
        startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
        break;
      case 2:
        // 先月（月末日の23:59:59.999まで含める）
        final now = DateTime.now();
        endDate = DateTime(now.year, now.month, 1).subtract(const Duration(milliseconds: 1));
        startDate = DateTime(endDate.year, endDate.month, 1);
        break;
      default:
        startDate = DateTime.now();
    }

    final filtered = widget.games
        .where((g) => !g.playedAt.isBefore(startDate) && !g.playedAt.isAfter(endDate))
        .toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Text(
          '対局データがありません',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 成績サマリー
          _buildSummaryStat(filtered),
          const SizedBox(height: 24),
          // ランキングセクション
          _sectionHeader(Icons.menu_book, '定跡別成績'),
          const SizedBox(height: 12),
          ..._buildOpeningRankings(filtered),
          const SizedBox(height: 24),
          // 時間帯別ランキング
          _sectionHeader(Icons.schedule, '時間帯別パフォーマンス'),
          const SizedBox(height: 12),
          ..._buildHourlyRankings(filtered),
          const SizedBox(height: 24),
          // 連勝記録
          _sectionHeader(Icons.insights, 'パフォーマンス'),
          const SizedBox(height: 12),
          _buildPerformanceCard(filtered),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String label) {
    return Row(children: [
      Icon(icon, size: 16, color: Colors.amber.shade300),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          color: Colors.amber.shade200,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    ]);
  }

  Widget _buildSummaryStat(List<GameAnalysis> games) {
    final totalGames = games.length;
    final wins = games.where((g) => g.playerWon).length;
    final winRate = totalGames == 0 ? 0.0 : (wins / totalGames * 100);
    final avgMoves = totalGames == 0
        ? 0.0
        : games.fold<int>(0, (sum, g) => sum + g.movesCount) / totalGames;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.cyan.withAlpha(40), Colors.blue.withAlpha(20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.cyan.withAlpha(80)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '成績サマリー',
            style: TextStyle(
              color: Colors.cyan,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatBadge('対局数', totalGames.toString(), Colors.cyan),
              _buildStatBadge('勝利', wins.toString(), Colors.green),
              _buildStatBadge('勝率', '${winRate.toStringAsFixed(1)}%', Colors.orange),
              _buildStatBadge('平均手', avgMoves.toStringAsFixed(1), Colors.white70),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildOpeningRankings(List<GameAnalysis> games) {
    final openingStats = <String, (int, int)>{};

    for (final game in games) {
      final opening = game.openingName ?? '不明';
      final (g, w) = openingStats[opening] ?? (0, 0);
      openingStats[opening] = (g + 1, w + (game.playerWon ? 1 : 0));
    }

    final rankings = openingStats.entries
        .map((e) {
          final name = e.key;
          final (games, wins) = e.value;
          final winRate = games == 0 ? 0.0 : (wins / games * 100);
          return (name: name, games: games, wins: wins, winRate: winRate);
        })
        .toList()
        ..sort((a, b) => b.winRate.compareTo(a.winRate));

    return rankings.isEmpty
        ? [
            const Text(
              '定跡データがありません',
              style: TextStyle(color: Colors.white54),
            )
          ]
        : rankings.asMap().entries.map((e) {
            final idx = e.key;
            final rank = e.value;
            return _buildOpeningRankCard(idx + 1, rank);
          }).toList();
  }

  static const _medals = {1: '🥇', 2: '🥈', 3: '🥉'};

  Widget _buildOpeningRankCard(
    int rank,
    ({String name, int games, int wins, double winRate}) rankData,
  ) {
    final color = rank == 1
        ? Colors.amber
        : rank == 2
            ? Colors.grey
            : rank == 3
                ? const Color(0xFFCD7F32)
                : Colors.cyan;
    final medal = _medals[rank];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        border: Border.all(color: color.withAlpha(80)),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(45), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          // 順位バッジ
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(60),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: medal != null
                  ? Text(medal, style: const TextStyle(fontSize: 20))
                  : Text(
                      '$rank',
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // 定跡情報
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rankData.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${rankData.wins}勝 / ${rankData.games}局',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // 勝率
          Text(
            '${rankData.winRate.toStringAsFixed(1)}%',
            style: TextStyle(
              color: rankData.winRate >= 60
                  ? Colors.green
                  : rankData.winRate >= 40
                      ? Colors.cyan
                      : Colors.orange,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(List<GameAnalysis> games) {
    final longestWinStreak = _calculateLongestWinStreak(games);
    final maxMovesGame = games.isEmpty ? 0 : games.map((g) => g.movesCount).reduce((a, b) => a > b ? a : b);
    final minMovesGame = games.isEmpty ? 0 : games.map((g) => g.movesCount).reduce((a, b) => a < b ? a : b);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(45), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPerformanceRow('最長連勝', '$longestWinStreak連勝', Colors.green),
          const SizedBox(height: 10),
          _buildPerformanceRow('最長対局', '$maxMovesGame手', Colors.cyan),
          const SizedBox(height: 10),
          _buildPerformanceRow('最短対局', '$minMovesGame手', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildPerformanceRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  int _calculateLongestWinStreak(List<GameAnalysis> games) {
    if (games.isEmpty) return 0;

    int maxStreak = 0;
    int currentStreak = 0;

    for (final game in games) {
      if (game.playerWon) {
        currentStreak++;
        maxStreak = currentStreak > maxStreak ? currentStreak : maxStreak;
      } else {
        currentStreak = 0;
      }
    }

    return maxStreak;
  }

  List<Widget> _buildHourlyRankings(List<GameAnalysis> games) {
    final hourlyStats = StatisticsCalculator.calculateHourlyStats(games);
    final activeHours = hourlyStats
        .where((h) => h.games > 0)
        .toList()
        ..sort((a, b) => b.winRate.compareTo(a.winRate));

    if (activeHours.isEmpty) {
      return [
        const Text(
          '時間帯データがありません',
          style: TextStyle(color: Colors.white54),
        )
      ];
    }

    return activeHours.take(5).toList().asMap().entries.map((e) {
      final idx = e.key;
      final hour = e.value;
      final rank = idx + 1;
      final color = idx == 0
          ? Colors.amber
          : idx == 1
              ? Colors.grey
              : idx == 2
                  ? const Color(0xFFCD7F32)
                  : Colors.cyan;
      final medal = _medals[rank];

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(8),
          border: Border.all(color: color.withAlpha(80)),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(45), blurRadius: 6, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            // 順位バッジ
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(60),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: medal != null
                    ? Text(medal, style: const TextStyle(fontSize: 20))
                    : Text(
                        '$rank',
                        style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // 時間帯情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${hour.hour.toString().padLeft(2, '0')}:00～${(hour.hour + 1).toString().padLeft(2, '0')}:00',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${hour.wins}勝 / ${hour.games}局',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // 勝率
            Text(
              '${hour.winRate.toStringAsFixed(1)}%',
              style: TextStyle(
                color: hour.winRate >= 60
                    ? Colors.green
                    : hour.winRate >= 40
                        ? Colors.cyan
                        : Colors.orange,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
