import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'theme/app_theme.dart';

class WeaknessPattern {
  final String patternName;
  final int losses;
  final int totalGames;
  final String recommendation;

  WeaknessPattern({
    required this.patternName,
    required this.losses,
    required this.totalGames,
    required this.recommendation,
  });

  double get lossRate => totalGames > 0 ? (losses / totalGames) * 100 : 0;

  Map<String, dynamic> toJson() => {
    'patternName': patternName,
    'losses': losses,
    'totalGames': totalGames,
    'recommendation': recommendation,
  };

  factory WeaknessPattern.fromJson(Map<String, dynamic> json) => WeaknessPattern(
    patternName: json['patternName'] as String,
    losses: json['losses'] as int,
    totalGames: json['totalGames'] as int,
    recommendation: json['recommendation'] as String? ?? '',
  );
}

class WeaknessMiningScreen extends StatefulWidget {
  const WeaknessMiningScreen({Key? key}) : super(key: key);

  @override
  State<WeaknessMiningScreen> createState() => _WeaknessMiningScreenState();
}

class _WeaknessMiningScreenState extends State<WeaknessMiningScreen> {
  late SharedPreferences _prefs;
  List<WeaknessPattern> _weaknessPatterns = [];
  int _totalAiGames = 0;
  int _aiWins = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    _prefs = await SharedPreferences.getInstance();

    // Load stats（total_ai_games/ai_winsは存在しないキーで常に0だったため修正）
    _totalAiGames = _prefs.getInt('stats_total_ai') ?? 0;
    _aiWins = _prefs.getInt('stats_p1_wins_ai') ?? 0;

    // Load or analyze weakness patterns
    await _loadOrAnalyzeWeaknesses();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadOrAnalyzeWeaknesses() async {
    // Try to load cached weakness patterns
    final cached = _prefs.getString('weakness_patterns_json');

    if (cached != null && cached.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(cached);
        _weaknessPatterns = decoded
            .map((p) => WeaknessPattern.fromJson(p as Map<String, dynamic>))
            .toList();
      } catch (e) {
        print('Error loading cached patterns: $e');
        await _analyzeGameHistory();
      }
    } else {
      // Analyze game history to detect patterns
      await _analyzeGameHistory();
    }

    // Sort by loss rate (descending) and keep top 5
    _weaknessPatterns.sort((a, b) => b.lossRate.compareTo(a.lossRate));
    if (_weaknessPatterns.length > 5) {
      _weaknessPatterns = _weaknessPatterns.sublist(0, 5);
    }
  }

  Future<void> _analyzeGameHistory() async {
    final gameHistoryJson = _prefs.getString('game_history_json');

    if (gameHistoryJson == null || gameHistoryJson.isEmpty) {
      // Create mock patterns if no history
      _createMockWeaknessPatterns();
      return;
    }

    try {
      final List<dynamic> gameHistory = jsonDecode(gameHistoryJson);
      final patterns = <String, Map<String, int>>{};

      for (final game in gameHistory) {
        if (game is Map<String, dynamic>) {
          final openingType = game['opening'] as String? ?? '序盤';
          final result = game['result'] as String? ?? 'loss';
          final handicap = game['handicap'] as String? ?? '平手';

          final key = '$openingType/$handicap';

          if (!patterns.containsKey(key)) {
            patterns[key] = {'losses': 0, 'total': 0};
          }

          patterns[key]!['total'] = patterns[key]!['total']! + 1;
          if (result == 'loss') {
            patterns[key]!['losses'] = patterns[key]!['losses']! + 1;
          }
        }
      }

      // Convert to WeaknessPattern list
      final recommendations = {
        '穴熊': '穴熊の防御を強化する。駒組み練習に進む',
        '角換わり': '角換わり定跡を学習する。詰将棋練習',
        '4五桂': '4五桂への対抗策を学習する。詰め合い練習',
        '横歩取り': '横歩取り定跡を強化する。詰め合い練習',
        '早仕掛け': '早仕掛けへの対抗策を学習する',
      };

      _weaknessPatterns = patterns.entries
          .map((e) => WeaknessPattern(
                patternName: e.key,
                losses: e.value['losses'] ?? 0,
                totalGames: e.value['total'] ?? 1,
                recommendation: _findRecommendation(e.key, recommendations),
              ))
          .toList();

      // Save to preferences
      await _saveWeaknessPatterns();
    } catch (e) {
      print('Error analyzing game history: $e');
      _createMockWeaknessPatterns();
    }
  }

  String _findRecommendation(String pattern, Map<String, String> recommendations) {
    for (final key in recommendations.keys) {
      if (pattern.contains(key)) {
        return recommendations[key] ?? '詰め合い練習を進める';
      }
    }
    return '定跡学習と詰め合い練習を進める';
  }

  void _createMockWeaknessPatterns() {
    _weaknessPatterns = [
      WeaknessPattern(
        patternName: '穴熊でよく負ける',
        losses: 6,
        totalGames: 10,
        recommendation: '穴熊の防御を強化する。駒組み練習に進む',
      ),
      WeaknessPattern(
        patternName: '4五桂で負ける',
        losses: 5,
        totalGames: 8,
        recommendation: '4五桂への対抗策を学習する',
      ),
      WeaknessPattern(
        patternName: '横歩取りが苦手',
        losses: 4,
        totalGames: 7,
        recommendation: '横歩取り定跡を強化する',
      ),
      WeaknessPattern(
        patternName: '角換わりで敗北',
        losses: 3,
        totalGames: 6,
        recommendation: '角換わり定跡を学習する',
      ),
      WeaknessPattern(
        patternName: '早仕掛けに弱い',
        losses: 3,
        totalGames: 5,
        recommendation: '早仕掛けへの対抗策を学習する',
      ),
    ];
  }

  Future<void> _saveWeaknessPatterns() async {
    final json = jsonEncode(
      _weaknessPatterns.map((p) => p.toJson()).toList(),
    );
    await _prefs.setString('weakness_patterns_json', json);
  }

  Future<void> _refreshAnalysis() async {
    setState(() => _isLoading = true);
    await _prefs.remove('weakness_patterns_json');
    _weaknessPatterns.clear();
    await _loadOrAnalyzeWeaknesses();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text(
          '弱点採掘',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshAnalysis,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Section
                    _buildStatsSection(),
                    const SizedBox(height: 24),

                    // Weakness Patterns Section
                    const Text(
                      '検出された弱点パターン',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_weaknessPatterns.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            'まだ弱点パターンが検出されていません',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _weaknessPatterns
                            .asMap()
                            .entries
                            .map((e) => _buildWeaknessCard(e.value, e.key + 1))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsSection() {
    final aiLosses = _totalAiGames - _aiWins;
    final winRate = _totalAiGames > 0 ? (_aiWins / _totalAiGames) * 100 : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00D4FF).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI対局成績',
            style: TextStyle(
              color: Color(0xFF00D4FF),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('総対局数', '$_totalAiGames'),
              _buildStatItem('勝利数', '$_aiWins'),
              _buildStatItem('敗数', '$aiLosses'),
              _buildStatItem('勝率', '${winRate.toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF00D4FF),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildWeaknessCard(WeaknessPattern pattern, int rank) {
    final lossPercentage = pattern.lossRate.toStringAsFixed(1);
    final severityColor = pattern.lossRate > 70
        ? Colors.red
        : pattern.lossRate > 50
            ? Colors.orange
            : Colors.yellow;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: severityColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Center(
                  child: Icon(
                    Icons.warning,
                    color: severityColor,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${rank}. ${pattern.patternName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'この局面で弱い',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Loss Rate
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: severityColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(
                  '敗率: ',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${pattern.losses}/${pattern.totalGames}戦 $lossPercentage%',
                  style: TextStyle(
                    color: severityColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Recommendation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey[700]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '推奨トレーニング',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  pattern.recommendation,
                  style: const TextStyle(
                    color: Color(0xFF00D4FF),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF),
                foregroundColor: AppTheme.bg,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _handleWeaknessTap(pattern),
              child: const Text(
                'この弱点を克服する',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleWeaknessTap(WeaknessPattern pattern) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${pattern.patternName} の克服トレーニングを開始します'),
        backgroundColor: AppTheme.surface,
        duration: const Duration(seconds: 2),
      ),
    );

    // TODO: Navigate to training screen based on pattern
    // Navigator.push(context, MaterialPageRoute(...))
  }
}
