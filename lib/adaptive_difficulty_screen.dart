import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert' as convert;
import 'dart:async';

// ──────────────────────────────────────────────
// Model: AdaptiveProblem
// ──────────────────────────────────────────────
class AdaptiveProblem {
  final String id;
  final String title;
  final String description;
  final int difficultyLevel; // 1-10
  final List<List<dynamic>> board; // Simplified board representation
  final String correctAnswer;
  final String explanation;

  AdaptiveProblem({
    required this.id,
    required this.title,
    required this.description,
    required this.difficultyLevel,
    required this.board,
    required this.correctAnswer,
    required this.explanation,
  });
}

// ──────────────────────────────────────────────
// Model: AdaptiveStats
// ──────────────────────────────────────────────
class AdaptiveStats {
  double currentDifficultyLevel; // 1.0-10.0
  int correctCount;
  int totalSolved;
  List<int> responseTimes; // milliseconds
  List<int> difficultySequence; // Track difficulty progression
  DateTime lastRecalculationTime;

  AdaptiveStats({
    required this.currentDifficultyLevel,
    this.correctCount = 0,
    this.totalSolved = 0,
    this.responseTimes = const [],
    this.difficultySequence = const [],
    DateTime? lastRecalculationTime,
  }) : lastRecalculationTime = lastRecalculationTime ?? DateTime.now();

  double get correctRate => totalSolved > 0 ? (correctCount / totalSolved) * 100 : 0;

  double get averageResponseTime {
    if (responseTimes.isEmpty) return 0;
    return responseTimes.reduce((a, b) => a + b) / responseTimes.length / 1000;
  }

  void reset() {
    correctCount = 0;
    totalSolved = 0;
    responseTimes = [];
    difficultySequence = [];
    lastRecalculationTime = DateTime.now();
  }

  // Flow theory-based difficulty adjustment
  // Ideal correct rate: 70-80%
  // If >80%: difficulty too easy, increase
  // If <60%: difficulty too hard, decrease
  void recalculateDifficulty() {
    final rate = correctRate;

    if (rate > 80) {
      // Too easy, increase difficulty
      currentDifficultyLevel = (currentDifficultyLevel + 0.5).clamp(1.0, 10.0);
    } else if (rate < 60) {
      // Too hard, decrease difficulty
      currentDifficultyLevel = (currentDifficultyLevel - 0.5).clamp(1.0, 10.0);
    }
    // Otherwise, within ideal range 60-80%, maintain current level

    reset();
    lastRecalculationTime = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
        'currentDifficultyLevel': currentDifficultyLevel,
        'correctCount': correctCount,
        'totalSolved': totalSolved,
        'responseTimes': responseTimes,
        'difficultySequence': difficultySequence,
        'lastRecalculationTime': lastRecalculationTime.toIso8601String(),
      };

  factory AdaptiveStats.fromJson(Map<String, dynamic> json) => AdaptiveStats(
        currentDifficultyLevel: json['currentDifficultyLevel'] ?? 5.0,
        correctCount: json['correctCount'] ?? 0,
        totalSolved: json['totalSolved'] ?? 0,
        responseTimes: List<int>.from(json['responseTimes'] ?? []),
        difficultySequence: List<int>.from(json['difficultySequence'] ?? []),
        lastRecalculationTime: json['lastRecalculationTime'] != null
            ? DateTime.parse(json['lastRecalculationTime'])
            : null,
      );
}

// ──────────────────────────────────────────────
// Main Screen: AdaptiveDifficultyScreen
// ──────────────────────────────────────────────
class AdaptiveDifficultyScreen extends StatefulWidget {
  final String userId;
  final bool isPremium;

  const AdaptiveDifficultyScreen({
    super.key,
    required this.userId,
    this.isPremium = false,
  });

  @override
  State<AdaptiveDifficultyScreen> createState() =>
      _AdaptiveDifficultyScreenState();
}

class _AdaptiveDifficultyScreenState extends State<AdaptiveDifficultyScreen>
    with TickerProviderStateMixin {
  late SharedPreferences _prefs;
  late AdaptiveStats _stats;
  late List<AdaptiveProblem> _problemPool;
  List<AdaptiveProblem> _currentProblemSet = [];

  int _currentProblemIndex = 0;
  bool _isLoading = true;
  bool _showingRecalculationAnimation = false;
  late AnimationController _recalcAnimController;
  late AnimationController _levelIndicatorController;

  final Stopwatch _problemTimer = Stopwatch();

  @override
  void initState() {
    super.initState();
    _recalcAnimController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _levelIndicatorController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _initialize();
  }

  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadStats();
    _buildProblemPool();
    _selectNextProblemSet();
    setState(() => _isLoading = false);
  }

  void _loadStats() {
    final json = _prefs.getString('adaptive_stats');
    if (json != null) {
      _stats = AdaptiveStats.fromJson(_jsonDecode(json));
    } else {
      _stats = AdaptiveStats(currentDifficultyLevel: 5.0);
    }
  }

  Future<void> _saveStats() async {
    await _prefs.setString('adaptive_stats', _jsonEncode(_stats.toJson()));
  }

  void _buildProblemPool() {
    // Generate 100+ problems across difficulty 1-10
    // In production, this would come from a database
    _problemPool = _generateProblems();
  }

  List<AdaptiveProblem> _generateProblems() {
    final problems = <AdaptiveProblem>[];
    for (int d = 1; d <= 10; d++) {
      for (int i = 0; i < 15; i++) {
        // 15 problems per difficulty level
        problems.add(AdaptiveProblem(
          id: 'problem_${d}_$i',
          title: '問題${d * 10 + i}',
          description: 'レベル$d 難易度調整問題 #$i',
          difficultyLevel: d,
          board: List.generate(9, (_) => List.generate(9, (_) => null)),
          correctAnswer: '7四歩',
          explanation: 'この局面での最適な手は7四歩です。',
        ));
      }
    }
    return problems;
  }

  void _selectNextProblemSet() {
    final targetLevel = _stats.currentDifficultyLevel.round();
    final minLevel = (targetLevel - 1).clamp(1, 10);
    final maxLevel = (targetLevel + 1).clamp(1, 10);

    _currentProblemSet = _problemPool
        .where((p) => p.difficultyLevel >= minLevel && p.difficultyLevel <= maxLevel)
        .toList();

    if (_currentProblemSet.isEmpty) {
      _currentProblemSet = _problemPool
          .where((p) => p.difficultyLevel == targetLevel)
          .toList();
    }

    _currentProblemSet.shuffle();
    _currentProblemSet = _currentProblemSet.take(5).toList();
    _currentProblemIndex = 0;
  }

  void _startProblem() {
    _problemTimer.reset();
    _problemTimer.start();
  }

  void _recordProblemResult(bool isCorrect) {
    _problemTimer.stop();
    final responseTime = _problemTimer.elapsedMilliseconds;

    _stats.totalSolved++;
    if (isCorrect) {
      _stats.correctCount++;
    }
    _stats.responseTimes.add(responseTime);

    final currentProblem = _currentProblemSet[_currentProblemIndex];
    _stats.difficultySequence.add(currentProblem.difficultyLevel);

    if (_currentProblemIndex < _currentProblemSet.length - 1) {
      _currentProblemIndex++;
      _saveStats();
      setState(() {});
    } else {
      // Completed 5 problems, trigger recalculation
      _showRecalculation();
    }
  }

  Future<void> _showRecalculation() async {
    setState(() => _showingRecalculationAnimation = true);
    await _recalcAnimController.forward();

    _stats.recalculateDifficulty();
    _saveStats();
    _selectNextProblemSet();

    await _recalcAnimController.reverse();
    setState(() => _showingRecalculationAnimation = false);
  }

  AdaptiveProblem get _currentProblem => _currentProblemSet[_currentProblemIndex];

  @override
  void dispose() {
    _recalcAnimController.dispose();
    _levelIndicatorController.dispose();
    _problemTimer.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('難易度自動調整 👑')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!widget.isPremium) {
      return Scaffold(
        appBar: AppBar(title: const Text('難易度自動調整 👑')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'プレミアム機能',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'この機能はプレミアム会員のみ利用可能です',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('戻る'),
              ),
            ],
          ),
        ),
      );
    }

    if (_showingRecalculationAnimation) {
      return _buildRecalculationScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('難易度自動調整 👑'),
        elevation: 0,
        backgroundColor: Colors.deepPurple[400],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current difficulty level indicator
          _buildDifficultyLevelCard(),
          const SizedBox(height: 24),

          // Flow state indicator
          _buildFlowStateIndicator(),
          const SizedBox(height: 24),

          // Current problem
          _buildProblemCard(),
          const SizedBox(height: 24),

          // Problem difficulty label
          _buildDifficultyLabel(),
          const SizedBox(height: 16),

          // Action buttons
          _buildActionButtons(),
          const SizedBox(height: 24),

          // Stats
          _buildStatsCard(),
        ],
      ),
    );
  }

  Widget _buildDifficultyLevelCard() {
    final level = _stats.currentDifficultyLevel;
    final fillPercentage = (level - 1) / 9;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'あなたにちょうどいい難しさ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: fillPercentage,
                      minHeight: 24,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation(
                        _getColorForLevel(level),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  level.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'レベル 1-10',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowStateIndicator() {
    final rate = _stats.correctRate;
    final inFlow = rate >= 60 && rate <= 80;
    final emoji = inFlow ? '✨' : '🎯';
    final message = inFlow ? '流れを感じる…' : '調整中…';
    final color = inFlow ? Colors.amber : Colors.blue;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        border: Border.all(color: color.withAlpha(102)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '正答率 ${rate.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _currentProblem.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_currentProblemIndex + 1}/5',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _currentProblem.description,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            // Simplified board visualization
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.brown[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.brown),
              ),
              child: Center(
                child: Text(
                  '将棋盤\n${_currentProblem.difficultyLevel}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyLabel() {
    final level = _currentProblem.difficultyLevel;
    final color = _getColorForLevel(level.toDouble());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'レベル $level',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              _startProblem();
              _recordProblemResult(true);
            },
            icon: const Icon(Icons.check_circle),
            label: const Text('正解'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              _startProblem();
              _recordProblemResult(false);
            },
            icon: const Icon(Icons.cancel),
            label: const Text('不正解'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '現在のセッション統計',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'データ: 正答率',
                  '${_stats.correctRate.toStringAsFixed(1)}%',
                  _stats.correctCount,
                  _stats.totalSolved,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey[300],
                ),
                _buildStatItem(
                  'データ: 平均応答時間',
                  '${_stats.averageResponseTime.toStringAsFixed(1)}秒',
                  null,
                  null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    int? correct,
    int? total,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          if (correct != null && total != null)
            Text(
              '$correct/$total',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }

  Widget _buildRecalculationScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('難易度自動調整 👑'),
        elevation: 0,
        backgroundColor: Colors.deepPurple[400],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0)
              .animate(_recalcAnimController),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.refresh,
                size: 64,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 24),
              const Text(
                '難易度を再計算中…',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'あなたのペースに合わせています',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              CircularProgressIndicator(
                value: _recalcAnimController.value,
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColorForLevel(double level) {
    if (level <= 2) return Colors.green;
    if (level <= 4) return Colors.lime;
    if (level <= 6) return Colors.yellow[700]!;
    if (level <= 8) return Colors.orange;
    return Colors.red;
  }
}

// ──────────────────────────────────────────────
// JSON Helper Functions
// ──────────────────────────────────────────────
Map<String, dynamic> _jsonDecode(String json) {
  try {
    return convert.jsonDecode(json) as Map<String, dynamic>;
  } catch (e) {
    return {};
  }
}

String _jsonEncode(Map<String, dynamic> data) {
  try {
    return convert.jsonEncode(data);
  } catch (e) {
    return '{}';
  }
}
