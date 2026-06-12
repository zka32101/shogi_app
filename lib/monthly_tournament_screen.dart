// lib/monthly_tournament_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

class MonthlyTournamentScreen extends StatefulWidget {
  const MonthlyTournamentScreen({super.key});

  @override
  State<MonthlyTournamentScreen> createState() =>
      _MonthlyTournamentScreenState();
}

class _MonthlyTournamentScreenState extends State<MonthlyTournamentScreen>
    with SingleTickerProviderStateMixin {
  bool _registered = false;
  String _divisionName = '級位者の部';
  int _currentRating = 500;
  late TabController _tabController;

  static const Color _gold = Color(0xFFFFD700);
  static const Color _bgDark = Color(0xFF1A1A2E);
  static const Color _navyDark = Color(0xFF16213E);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPrefs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final key =
        'tournament_registered_${now.year}-${now.month.toString().padLeft(2, '0')}';
    final rating = prefs.getInt('rating_current') ?? 500;
    final registered = prefs.getBool(key) ?? false;
    setState(() {
      _currentRating = rating;
      _registered = registered;
      _divisionName = rating >= 800 ? '有段者の部' : '級位者の部';
    });
  }

  Future<void> _register() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final key =
        'tournament_registered_${now.year}-${now.month.toString().padLeft(2, '0')}';
    await prefs.setBool(key, true);
    setState(() {
      _registered = true;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('参加登録が完了しました！'),
        backgroundColor: Color(0xFF2E7D32),
      ),
    );
  }

  String _getTournamentTitle() {
    final now = DateTime.now();
    return '第${now.month}回 月例トーナメント';
  }

  String _getTournamentPeriod() {
    final now = DateTime.now();
    final month = now.month;
    DateTime day = DateTime(now.year, month, 1);
    int satCount = 0;
    while (satCount < 3) {
      if (day.weekday == DateTime.saturday) satCount++;
      if (satCount < 3) day = day.add(const Duration(days: 1));
    }
    final sat = day;
    final sun = sat.add(const Duration(days: 1));
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return '${month}月${sat.day}日(${weekdays[sat.weekday - 1]}) 〜 ${month}月${sun.day}日(${weekdays[sun.weekday - 1]})';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        title: const Text(
          '月例トーナメント',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _navyDark,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _gold,
          labelColor: _gold,
          unselectedLabelColor: const Color(0x99FFFFFF),
          tabs: const [
            Tab(text: '大会情報'),
            Tab(text: '対戦表'),
            Tab(text: '結果'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(),
          _buildBracketTab(),
          _buildResultsTab(),
        ],
      ),
    );
  }

  // ─── Tab 1: 大会情報 ──────────────────────────────────────────────────────

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTournamentInfoCard(),
          const SizedBox(height: 16),
          _buildPrizeSection(),
          const SizedBox(height: 16),
          _buildRulesSection(),
        ],
      ),
    );
  }

  Widget _buildTournamentInfoCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16213E), Color(0xFF0F3460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withOpacity(0.5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: _gold, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getTournamentTitle(),
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.calendar_today, '開催期間', _getTournamentPeriod()),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.group, 'あなたの部門', _divisionName),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.person, '参加者数', '24人エントリー'),
            const SizedBox(height: 20),
            _registered
                ? Center(
                    child: Chip(
                      avatar: const Icon(Icons.check_circle,
                          color: Colors.white, size: 18),
                      label: const Text(
                        '参加登録済み ✓',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: const Color(0xFF2E7D32),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                    ),
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _navyDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '参加登録する',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _gold, size: 18),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildPrizeSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.card_giftcard, color: Colors.amber, size: 22),
                SizedBox(width: 8),
                Text(
                  '賞品・特典',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPrizeRow(
                '🥇', '1位', '称号バッジ + Rating +100', const Color(0xFFFFD700)),
            const SizedBox(height: 8),
            _buildPrizeRow('🥈', '2位', 'Rating +60', const Color(0xFFC0C0C0)),
            const SizedBox(height: 8),
            _buildPrizeRow('🥉', '3位', 'Rating +30', const Color(0xFFCD7F32)),
            const SizedBox(height: 8),
            _buildPrizeRow('🎖️', '参加賞', '参加バッジ', const Color(0xFF90CAF9)),
          ],
        ),
      ),
    );
  }

  Widget _buildPrizeRow(
      String emoji, String rank, String reward, Color rankColor) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            rank,
            style: TextStyle(
                color: rankColor,
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          reward,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildRulesSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33FFFFFF), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.gavel, color: Color(0xDEFFFFFF), size: 22),
                SizedBox(width: 8),
                Text(
                  '大会ルール',
                  style: TextStyle(
                    color: Color(0xDEFFFFFF),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRuleRow('⏱️', '持ち時間', '10分 + 30秒加算'),
            const SizedBox(height: 6),
            _buildRuleRow('⚖️', '勝敗判定', '通常ルール'),
            const SizedBox(height: 6),
            _buildRuleRow('🚶', '不戦勝', '相手が5分以内に現れない場合'),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleRow(String emoji, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 13),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    );
  }

  // ─── Tab 2: 対戦表 ────────────────────────────────────────────────────────

  Widget _buildBracketTab() {
    final players = [
      {'name': '棋士A', 'rank': '15級', 'result': 'win'},
      {'name': '棋士B', 'rank': '14級', 'result': 'lose'},
      {'name': '棋士C', 'rank': '13級', 'result': 'win'},
      {'name': '棋士D', 'rank': '12級', 'result': 'lose'},
      {'name': '棋士E', 'rank': '11級', 'result': 'win'},
      {'name': '棋士F', 'rank': '10級', 'result': 'lose'},
      {'name': '棋士G', 'rank': '9級', 'result': 'win'},
      {'name': '棋士H', 'rank': '8級', 'result': 'lose'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withOpacity(0.4), width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'トーナメント表',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 320,
                  child: CustomPaint(
                    painter: _BracketPainter(players: players),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F3460).withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _gold.withOpacity(0.3), width: 1),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: _gold, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'あなたの対戦相手はトーナメント開始後に決定します',
                    style: TextStyle(
                      color: Color(0xDEFFFFFF),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildBracketLegend(),
        ],
      ),
    );
  }

  Widget _buildBracketLegend() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _LegendItem(color: Color(0xFFFFD700), label: '優勝'),
          _LegendItem(color: Color(0xFF4CAF50), label: '勝ち'),
          _LegendItem(color: Color(0xFFEF5350), label: '負け'),
          _LegendItem(color: Color(0xFF90A4AE), label: '未定'),
        ],
      ),
    );
  }

  // ─── Tab 3: 結果 ──────────────────────────────────────────────────────────

  Widget _buildResultsTab() {
    final mockResults = [
      {
        'tournament': '第5回 月例トーナメント',
        'period': '2026年5月',
        'result': 'ベスト4',
        'rank': 3,
      },
      {
        'tournament': '第4回 月例トーナメント',
        'period': '2026年4月',
        'result': '予選落ち',
        'rank': 0,
      },
      {
        'tournament': '第3回 月例トーナメント',
        'period': '2026年3月',
        'result': '2位',
        'rank': 2,
      },
      {
        'tournament': '第2回 月例トーナメント',
        'period': '2026年2月',
        'result': '1位 🏆',
        'rank': 1,
      },
      {
        'tournament': '第1回 月例トーナメント',
        'period': '2026年1月',
        'result': 'ベスト4',
        'rank': 3,
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ...mockResults.map((r) => _buildResultCard(r)),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result) {
    final rank = result['rank'] as int;
    Color borderColor;
    Color rankColor;
    IconData rankIcon;

    switch (rank) {
      case 1:
        borderColor = const Color(0xFFFFD700);
        rankColor = const Color(0xFFFFD700);
        rankIcon = Icons.emoji_events;
        break;
      case 2:
        borderColor = const Color(0xFFC0C0C0);
        rankColor = const Color(0xFFC0C0C0);
        rankIcon = Icons.emoji_events;
        break;
      case 3:
        borderColor = const Color(0xFFCD7F32);
        rankColor = const Color(0xFFCD7F32);
        rankIcon = Icons.emoji_events;
        break;
      default:
        borderColor = const Color(0x33FFFFFF);
        rankColor = const Color(0x99FFFFFF);
        rankIcon = Icons.sports_martial_arts;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(rankIcon, color: rankColor, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result['tournament'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result['period'] as String,
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: rankColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: rankColor.withOpacity(0.5), width: 1),
              ),
              child: Text(
                result['result'] as String,
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Legend Item ──────────────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xDEFFFFFF), fontSize: 12),
        ),
      ],
    );
  }
}

// ─── Bracket Painter ──────────────────────────────────────────────────────────

class _BracketPainter extends CustomPainter {
  final List<Map<String, String>> players;

  const _BracketPainter({required this.players});

  @override
  void paint(Canvas canvas, Size size) {
    const boxW = 90.0;
    const boxH = 28.0;

    final linePaint = Paint()
      ..color = const Color(0xFFFFFFFF).withOpacity(0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final winFill = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final loseFill = Paint()
      ..color = const Color(0xFFEF5350).withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final goldFill = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final neutralFill = Paint()
      ..color = const Color(0xFF90A4AE).withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final goldBorderPaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const double col0X = 4;
    const double col1X = col0X + boxW + 24;
    const double col2X = col1X + boxW + 24;
    const double col3X = col2X + boxW + 24;

    final double spacing = size.height / 8;
    final List<double> qfY =
        List.generate(8, (i) => spacing * i + spacing / 2 - boxH / 2);

    final List<double> sfY = [
      (qfY[0] + qfY[1]) / 2,
      (qfY[2] + qfY[3]) / 2,
      (qfY[4] + qfY[5]) / 2,
      (qfY[6] + qfY[7]) / 2,
    ];

    final List<double> fY = [
      (sfY[0] + sfY[1]) / 2,
      (sfY[2] + sfY[3]) / 2,
    ];

    final double winY = (fY[0] + fY[1]) / 2;

    // Quarter-final boxes
    for (int i = 0; i < 8; i++) {
      final result = players[i]['result'] ?? '';
      final fill = result == 'win'
          ? winFill
          : (result == 'lose' ? loseFill : neutralFill);
      final textColor = result == 'win'
          ? const Color(0xFF4CAF50)
          : (result == 'lose'
              ? const Color(0xFFEF5350)
              : const Color(0xFF90A4AE));
      _drawBox(
        canvas,
        col0X,
        qfY[i],
        boxW,
        boxH,
        fill,
        borderPaint,
        '${players[i]['name']}(${players[i]['rank']})',
        textColor,
      );
    }

    // QF → SF connectors
    for (int i = 0; i < 4; i++) {
      final topY = qfY[i * 2] + boxH / 2;
      final botY = qfY[i * 2 + 1] + boxH / 2;
      final midY = (topY + botY) / 2;
      const fromX = col0X + boxW;
      const toX = col1X;
      canvas.drawLine(Offset(fromX, topY), Offset(fromX + 12, topY), linePaint);
      canvas.drawLine(Offset(fromX, botY), Offset(fromX + 12, botY), linePaint);
      canvas.drawLine(
          Offset(fromX + 12, topY), Offset(fromX + 12, botY), linePaint);
      canvas.drawLine(Offset(fromX + 12, midY), Offset(toX, midY), linePaint);
    }

    // Semi-final boxes
    for (int i = 0; i < 4; i++) {
      _drawBox(canvas, col1X, sfY[i], boxW, boxH, neutralFill, borderPaint,
          '準決勝', const Color(0xFF90A4AE));
    }

    // SF → Final connectors
    for (int i = 0; i < 2; i++) {
      final topY = sfY[i * 2] + boxH / 2;
      final botY = sfY[i * 2 + 1] + boxH / 2;
      final midY = (topY + botY) / 2;
      const fromX = col1X + boxW;
      const toX = col2X;
      canvas.drawLine(Offset(fromX, topY), Offset(fromX + 12, topY), linePaint);
      canvas.drawLine(Offset(fromX, botY), Offset(fromX + 12, botY), linePaint);
      canvas.drawLine(
          Offset(fromX + 12, topY), Offset(fromX + 12, botY), linePaint);
      canvas.drawLine(Offset(fromX + 12, midY), Offset(toX, midY), linePaint);
    }

    // Final boxes
    for (int i = 0; i < 2; i++) {
      _drawBox(canvas, col2X, fY[i], boxW, boxH, neutralFill, borderPaint,
          '決勝', const Color(0xFF90A4AE));
    }

    // Final → Winner connector
    {
      final topY = fY[0] + boxH / 2;
      final botY = fY[1] + boxH / 2;
      final midY = (topY + botY) / 2;
      const fromX = col2X + boxW;
      const toX = col3X;
      canvas.drawLine(Offset(fromX, topY), Offset(fromX + 12, topY), linePaint);
      canvas.drawLine(Offset(fromX, botY), Offset(fromX + 12, botY), linePaint);
      canvas.drawLine(
          Offset(fromX + 12, topY), Offset(fromX + 12, botY), linePaint);
      canvas.drawLine(Offset(fromX + 12, midY), Offset(toX, midY), linePaint);
    }

    // Winner box
    _drawBox(canvas, col3X, winY - boxH / 2, boxW, boxH, goldFill,
        goldBorderPaint, '🏆 優勝', const Color(0xFFFFD700));
  }

  void _drawBox(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    Paint fill,
    Paint border,
    String label,
    Color textColor,
  ) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, fill);
    canvas.drawRRect(rect, border);

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
            color: textColor, fontSize: 10, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    );
    tp.layout(maxWidth: w - 6);
    tp.paint(canvas, Offset(x + 3, y + (h - tp.height) / 2));
  }

  @override
  bool shouldRepaint(covariant _BracketPainter oldDelegate) =>
      oldDelegate.players != players;
}
