import 'package:flutter/material.dart';
import '../models/game_analysis.dart';
import '../models/game_statistics.dart';
import '../services/kifu_analytics_service.dart';
import 'game_history_detail_screen.dart';
import 'custom_period_analysis_screen.dart';
import 'personalized_lesson_screen.dart';

class GameStatisticsScreen extends StatefulWidget {
  const GameStatisticsScreen({super.key});

  @override
  State<GameStatisticsScreen> createState() => _GameStatisticsScreenState();
}

class _GameStatisticsScreenState extends State<GameStatisticsScreen> {
  List<GameAnalysis>? _allGames;
  bool _isLoading = true;
  int _selectedTab = 0; // 0: 月別, 1: 時間帯, 2: 詳細

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    try {
      final games = await KifuAnalyticsService().getAllAnalyses();
      setState(() {
        _allGames = games;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ ゲーム読み込みエラー: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('成績分析'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allGames == null || _allGames!.isEmpty
              ? const Center(
                  child: Text(
                    '対局データがありません',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : Column(
                  children: [
                    // タブバー
                    Container(
                      color: const Color(0xFF16213E),
                      child: Row(
                        children: [
                          _buildTab('月別', 0),
                          _buildTab('時間帯', 1),
                          _buildTab('詳細', 2),
                        ],
                      ),
                    ),
                    // コンテンツ
                    Expanded(
                      child: _buildTabContent(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.cyan : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.cyan : Colors.white54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildMonthlyStats();
      case 1:
        return _buildHourlyStats();
      case 2:
        return _buildDetailedStats();
      default:
        return const SizedBox();
    }
  }

  Widget _buildMonthlyStats() {
    if (_allGames == null) return const SizedBox();

    final monthlyStats = StatisticsCalculator.calculateMonthlyStats(_allGames!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '月別成績',
            style: TextStyle(
              color: Colors.cyan,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...monthlyStats.where((s) => s.totalGames > 0).map((stats) {
            return _buildStatCard(
              title: _getMonthLabel(stats.periodStart),
              games: stats.totalGames,
              record: stats.recordText,
              winRate: stats.winRate,
              avgMoves: stats.avgMoves,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHourlyStats() {
    if (_allGames == null) return const SizedBox();

    final hourlyStats = StatisticsCalculator.calculateHourlyStats(_allGames!);
    final activeHours = hourlyStats.where((h) => h.games > 0).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '時間帯別パフォーマンス',
            style: TextStyle(
              color: Colors.cyan,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...activeHours.map((stats) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(8),
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stats.timeRange,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${stats.games}局',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: stats.winRate / 100,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        stats.winRate > 50 ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '勝率: ${stats.winRate.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.cyan,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetailedStats() {
    if (_allGames == null) return const SizedBox();

    final totalStats = StatisticsCalculator.calculateStats(_allGames!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '全期間の統計',
            style: TextStyle(
              color: Colors.cyan,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatCard(
            title: '全対局',
            games: totalStats.totalGames,
            record: totalStats.recordText,
            winRate: totalStats.winRate,
            avgMoves: totalStats.avgMoves,
          ),
          const SizedBox(height: 20),
          // ボタングループ
          Column(
            children: [
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => GameHistoryDetailScreen(games: _allGames!),
                  ),
                ),
                icon: const Icon(Icons.timeline),
                label: const Text('対局記録詳細'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan.withAlpha(100),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => CustomPeriodAnalysisScreen(games: _allGames!),
                  ),
                ),
                icon: const Icon(Icons.date_range),
                label: const Text('カスタム期間分析'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.withAlpha(100),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => const PersonalizedLessonScreen(),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('パーソナライズ学習プラン'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.withAlpha(120),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            '統計情報',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatRow('総手数', '${totalStats.totalMoves}手'),
          _buildStatRow('平均手数', '${totalStats.avgMoves.toStringAsFixed(1)}手'),
          _buildStatRow(
            '勝率',
            '${totalStats.winRate.toStringAsFixed(1)}%',
          ),
          _buildStatRow('勝数', '${totalStats.wins}勝'),
          _buildStatRow('敗数', '${totalStats.losses}敗'),
          if (totalStats.draws > 0)
            _buildStatRow('分数', '${totalStats.draws}分'),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int games,
    required String record,
    required double winRate,
    required double avgMoves,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        border: Border.all(color: Colors.cyan.withAlpha(60)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.cyan,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            record,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '勝率: ${winRate.toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                '平均手数: ${avgMoves.toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.cyan,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthLabel(DateTime date) {
    return '${date.year}年${date.month}月';
  }
}
