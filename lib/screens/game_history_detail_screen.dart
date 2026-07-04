import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/game_analysis.dart';
import '../models/game_statistics.dart';
import 'leaderboard_screen.dart';

class GameHistoryDetailScreen extends StatefulWidget {
  final List<GameAnalysis> games;

  const GameHistoryDetailScreen({
    required this.games,
    super.key,
  });

  @override
  State<GameHistoryDetailScreen> createState() => _GameHistoryDetailScreenState();
}

class _GameHistoryDetailScreenState extends State<GameHistoryDetailScreen> {
  int _selectedTab = 0; // 0: 週間, 1: 月間

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('対局記録詳細'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'スコアボード',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => LeaderboardScreen(games: widget.games),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // タブバー
          Container(
            color: const Color(0xFF16213E),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTab == 0 ? Colors.cyan : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        '週間推移',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTab == 0 ? Colors.cyan : Colors.white54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTab == 1 ? Colors.cyan : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        '月間詳細',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTab == 1 ? Colors.cyan : Colors.white54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // コンテンツ
          Expanded(
            child: _selectedTab == 0
                ? _buildWeeklyView()
                : _buildMonthlyView(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyView() {
    final weeklies = _calculateWeeklyStats(widget.games);

    if (weeklies.isEmpty) {
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
          // グラフ
          Container(
            height: 280,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(8),
              border: Border.all(color: Colors.cyan.withAlpha(60)),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: _buildWeeklyChart(weeklies),
          ),
          const SizedBox(height: 24),
          // 週ごとのカード
          _sectionHeader(Icons.calendar_view_week, '週ごとの成績'),
          const SizedBox(height: 12),
          ...weeklies.asMap().entries.map((e) {
            final idx = e.key;
            final week = e.value;
            return _buildWeekCard(idx, week);
          }),
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

  Widget _buildWeeklyChart(List<WeeklyStat> weeklies) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        maxY: weeklies.fold(0.0, (max, w) => w.totalGames > max ? w.totalGames.toDouble() : max) + 2,
        barGroups: weeklies.asMap().entries.map((e) {
          final idx = e.key;
          final week = e.value;
          final winRate = week.totalGames == 0 ? 0.0 : week.wins / week.totalGames;

          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: week.totalGames.toDouble(),
                color: week.totalGames == 0
                    ? Colors.white12
                    : winRate >= 0.6
                        ? Colors.green
                        : winRate >= 0.4
                            ? Colors.cyan
                            : Colors.orange,
                width: 12,
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 28),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < weeklies.length) {
                  final week = weeklies[idx];
                  return Text(
                    week.weekLabel,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildWeekCard(int idx, WeeklyStat week) {
    final winRate = week.totalGames == 0 ? 0.0 : (week.wins / week.totalGames * 100);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                week.weekLabel,
                style: const TextStyle(
                  color: Colors.cyan,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${week.wins}勝 ${week.losses}敗',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '勝率：${winRate.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                '対局数：${week.totalGames}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyView() {
    final monthlies = StatisticsCalculator.calculateMonthlyStats(widget.games);

    if (monthlies.isEmpty) {
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
        children: monthlies.where((m) => m.totalGames > 0).map((month) {
          return _buildMonthCard(month);
        }).toList(),
      ),
    );
  }

  Widget _buildMonthCard(GameStatistics month) {
    final monthLabel = DateFormat('yyyy年M月').format(month.periodStart);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        border: Border.all(color: Colors.cyan.withAlpha(80)),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(45), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthLabel,
            style: const TextStyle(
              color: Colors.cyan,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('対局数', month.totalGames.toString(), Colors.white),
              _buildStatItem('勝利', month.wins.toString(), Colors.green),
              _buildStatItem('敗北', month.losses.toString(), Colors.orange),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('勝率', '${month.winRate.toStringAsFixed(1)}%', Colors.cyan),
              _buildStatItem('平均手数', month.avgMoves.toStringAsFixed(1), Colors.white70),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
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
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  List<WeeklyStat> _calculateWeeklyStats(List<GameAnalysis> games) {
    if (games.isEmpty) return [];

    final now = DateTime.now();
    final weeks = <WeeklyStat>[];

    for (int i = 0; i < 8; i++) {
      final endDate = now.subtract(Duration(days: i * 7));
      final startDate = endDate.subtract(const Duration(days: 7));

      final filtered = games
          .where((g) => !g.playedAt.isBefore(startDate) && g.playedAt.isBefore(endDate))
          .toList();

      final wins = filtered.where((g) => g.playerWon).length;
      final losses = filtered.length - wins;

      weeks.add(WeeklyStat(
        weekStart: startDate,
        weekEnd: endDate,
        wins: wins,
        losses: losses,
        totalGames: filtered.length,
      ));
    }

    return weeks.reversed.toList();
  }
}

class WeeklyStat {
  final DateTime weekStart;
  final DateTime weekEnd;
  final int wins;
  final int losses;
  final int totalGames;

  WeeklyStat({
    required this.weekStart,
    required this.weekEnd,
    required this.wins,
    required this.losses,
    required this.totalGames,
  });

  String get weekLabel {
    final formatter = DateFormat('M/d');
    return '${formatter.format(weekStart)}～';
  }
}
