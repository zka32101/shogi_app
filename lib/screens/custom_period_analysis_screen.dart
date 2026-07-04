import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/game_analysis.dart';
import '../models/game_statistics.dart';

class CustomPeriodAnalysisScreen extends StatefulWidget {
  final List<GameAnalysis> games;

  const CustomPeriodAnalysisScreen({
    required this.games,
    super.key,
  });

  @override
  State<CustomPeriodAnalysisScreen> createState() => _CustomPeriodAnalysisScreenState();
}

class _CustomPeriodAnalysisScreenState extends State<CustomPeriodAnalysisScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  late List<GameAnalysis> _filteredGames;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate = now;
    _startDate = now.subtract(const Duration(days: 30));
    _updateFilteredGames();
  }

  void _updateFilteredGames() {
    _filteredGames = widget.games
        .where((g) => !g.playedAt.isBefore(_startDate) && !g.playedAt.isAfter(_endDate))
        .toList();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: widget.games.isEmpty ? DateTime.now() : widget.games.last.playedAt,
      lastDate: _endDate.subtract(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _updateFilteredGames();
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate.add(const Duration(days: 1)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _updateFilteredGames();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = StatisticsCalculator.calculateStats(_filteredGames, startDate: _startDate, endDate: _endDate);
    final hourlyStats = StatisticsCalculator.calculateHourlyStats(_filteredGames);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('カスタム期間分析'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日付選択セクション
            Container(
              padding: const EdgeInsets.all(14),
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
                  Row(
                    children: [
                      Icon(Icons.date_range, size: 15, color: Colors.cyan.shade200),
                      const SizedBox(width: 6),
                      const Text(
                        '分析期間',
                        style: TextStyle(
                          color: Colors.cyan,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectStartDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(5),
                              border: Border.all(color: Colors.white24),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '開始日',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('yyyy/MM/dd').format(_startDate),
                                  style: const TextStyle(
                                    color: Colors.cyan,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward, color: Colors.white54),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectEndDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(5),
                              border: Border.all(color: Colors.white24),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '終了日',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('yyyy/MM/dd').format(_endDate),
                                  style: const TextStyle(
                                    color: Colors.cyan,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_calculateDays()}日間 • ${_filteredGames.length}局',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_filteredGames.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    '該当期間のデータがありません',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 成績サマリー
                  _sectionHeader(Icons.bar_chart, '成績サマリー'),
                  const SizedBox(height: 12),
                  _buildStatCard(stats),
                  const SizedBox(height: 20),

                  // 統計詳細
                  _sectionHeader(Icons.analytics, '詳細統計'),
                  const SizedBox(height: 12),
                  _buildDetailStats(stats),
                  const SizedBox(height: 20),

                  // 時間帯別成績
                  _sectionHeader(Icons.schedule, '時間帯別成績'),
                  const SizedBox(height: 12),
                  ...hourlyStats
                      .where((h) => h.games > 0)
                      .map((h) => _buildHourlyCard(h))
                      .toList(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  int _calculateDays() {
    return _endDate.difference(_startDate).inDays;
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

  Widget _buildStatCard(GameStatistics stats) {
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatBadge('対局数', stats.totalGames.toString(), Colors.cyan),
          _buildStatBadge('勝利', stats.wins.toString(), Colors.green),
          _buildStatBadge('敗北', stats.losses.toString(), Colors.orange),
          _buildStatBadge('勝率', '${stats.winRate.toStringAsFixed(1)}%', Colors.white70),
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
        const SizedBox(height: 6),
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

  Widget _buildDetailStats(GameStatistics stats) {
    final days = _calculateDays().clamp(1, 1 << 30);
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
        children: [
          _buildStatRow('総手数', '${stats.totalMoves}手'),
          const SizedBox(height: 10),
          _buildStatRow('平均手数', '${stats.avgMoves.toStringAsFixed(1)}手'),
          const SizedBox(height: 10),
          _buildStatRow('1日平均対局数', '${(_filteredGames.length / days).toStringAsFixed(2)}局'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
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
          style: const TextStyle(
            color: Colors.cyan,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyCard(HourlyStats hourly) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(45), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${hourly.hour.toString().padLeft(2, '0')}:00～${(hourly.hour + 1).toString().padLeft(2, '0')}:00',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${hourly.wins}勝 / ${hourly.games}局',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          Text(
            '${hourly.winRate.toStringAsFixed(1)}%',
            style: TextStyle(
              color: hourly.winRate >= 60
                  ? Colors.green
                  : hourly.winRate >= 40
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
}
