// lib/async_training_duel_screen.dart
// 非同期トレーニング対戦画面（5手詰め競争）

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;
import 'piece.dart';
import 'logic.dart';
import 'mini_board_widget.dart';

// ===== データモデル =====

class AsyncDuel {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime deadlineAt;
  final String difficulty; // '1手詰め', '3手詰め', '5手詰め'
  final String playerName;
  final String opponentName;
  final List<TsumeQuestion> questions;
  final int solvedCount;
  final Duration totalSolveTime;
  final DuelStatus status; // pending, inProgress, completed

  AsyncDuel({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.deadlineAt,
    required this.difficulty,
    required this.playerName,
    required this.opponentName,
    required this.questions,
    this.solvedCount = 0,
    this.totalSolveTime = Duration.zero,
    this.status = DuelStatus.pending,
  });

  bool get isExpired => DateTime.now().isAfter(deadlineAt);
  int get remainingMinutes => deadlineAt.difference(DateTime.now()).inMinutes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'deadlineAt': deadlineAt.toIso8601String(),
        'difficulty': difficulty,
        'playerName': playerName,
        'opponentName': opponentName,
        'questions': questions.map((q) => q.toJson()).toList(),
        'solvedCount': solvedCount,
        'totalSolveTime': totalSolveTime.inSeconds,
        'status': status.toString(),
      };

  factory AsyncDuel.fromJson(Map<String, dynamic> json) => AsyncDuel(
        id: json['id'],
        title: json['title'],
        createdAt: DateTime.parse(json['createdAt']),
        deadlineAt: DateTime.parse(json['deadlineAt']),
        difficulty: json['difficulty'],
        playerName: json['playerName'],
        opponentName: json['opponentName'],
        questions: (json['questions'] as List)
            .map((q) => TsumeQuestion.fromJson(q))
            .toList(),
        solvedCount: json['solvedCount'] ?? 0,
        totalSolveTime:
            Duration(seconds: json['totalSolveTime'] ?? 0),
        status: DuelStatus.values.firstWhere(
          (s) => s.toString() == json['status'],
          orElse: () => DuelStatus.pending,
        ),
      );
}

enum DuelStatus { pending, inProgress, completed }

class TsumeQuestion {
  final int id;
  final List<List<Piece?>> board;
  final Map<PieceType, int> p1Hand;
  final Map<PieceType, int> p2Hand;
  final bool p1Turn;
  final List<AMove> solution;
  bool isSolved;
  Duration? solveTime;

  TsumeQuestion({
    required this.id,
    required this.board,
    required this.p1Hand,
    required this.p2Hand,
    required this.p1Turn,
    required this.solution,
    this.isSolved = false,
    this.solveTime,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'isSolved': isSolved,
        'solveTime': solveTime?.inSeconds,
      };

  factory TsumeQuestion.fromJson(Map<String, dynamic> json) => TsumeQuestion(
        id: json['id'],
        board: [],
        p1Hand: {},
        p2Hand: {},
        p1Turn: true,
        solution: [],
        isSolved: json['isSolved'] ?? false,
        solveTime: json['solveTime'] != null
            ? Duration(seconds: json['solveTime'])
            : null,
      );
}

// ===== スクリーン =====

class AsyncTrainingDuelScreen extends StatefulWidget {
  const AsyncTrainingDuelScreen({super.key});

  @override
  State<AsyncTrainingDuelScreen> createState() =>
      _AsyncTrainingDuelScreenState();
}

class _AsyncTrainingDuelScreenState extends State<AsyncTrainingDuelScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<AsyncDuel> _activeDuels = [];
  List<AsyncDuel> _completedDuels = [];
  late SharedPreferences _prefs;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadDuels();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadDuels() async {
    final json = _prefs.getString('async_duels_json');
    if (json == null) {
      _activeDuels = [];
      _completedDuels = [];
      return;
    }

    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final duels = (data['duels'] as List)
          .map((d) => AsyncDuel.fromJson(d))
          .toList();

      _activeDuels =
          duels.where((d) => !d.isExpired && d.status != DuelStatus.completed)
              .toList();
      _completedDuels =
          duels.where((d) => d.status == DuelStatus.completed).toList();
    } catch (e) {
      debugPrint('Error loading duels: $e');
    }
  }

  Future<void> _saveDuels() async {
    final allDuels = [..._activeDuels, ..._completedDuels];
    final json = jsonEncode({'duels': allDuels.map((d) => d.toJson()).toList()});
    await _prefs.setString('async_duels_json', json);
  }

  Future<void> _createDuel({
    required String difficulty,
    required String opponentName,
    required int hours,
  }) async {
    final newDuel = AsyncDuel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '$difficulty 対 $opponentName',
      createdAt: DateTime.now(),
      deadlineAt: DateTime.now().add(Duration(hours: hours)),
      difficulty: difficulty,
      playerName: 'あなた',
      opponentName: opponentName,
      questions: _generateSampleQuestions(difficulty),
      status: DuelStatus.inProgress,
    );

    setState(() {
      _activeDuels.add(newDuel);
    });

    await _saveDuels();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('対戦を開始しました: ${newDuel.title}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  List<TsumeQuestion> _generateSampleQuestions(String difficulty) {
    final questions = <TsumeQuestion>[];
    int moveCount = 1;

    if (difficulty == '3手詰め') moveCount = 3;
    if (difficulty == '5手詰め') moveCount = 5;

    for (int i = 0; i < 5; i++) {
      final board = _createSampleBoard();
      questions.add(
        TsumeQuestion(
          id: i,
          board: board,
          p1Hand: {PieceType.gold: 2},
          p2Hand: {},
          p1Turn: true,
          solution: [
            AMove(fr: 2, fc: 1, tr: 1, tc: 0),
            AMove(fr: 3, fc: 1, tr: 2, tc: 1),
          ],
        ),
      );
    }

    return questions;
  }

  List<List<Piece?>> _createSampleBoard() {
    final board = List.generate(9, (_) => List<Piece?>.filled(9, null));
    board[0][0] = Piece(PieceType.king, false);
    board[8][8] = Piece(PieceType.king, true);
    board[2][1] = Piece(PieceType.gold, true);
    board[0][1] = Piece(PieceType.silver, true);
    board[3][1] = Piece(PieceType.rook, true);
    return board;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16213E),
          title: const Text('非同期トレーニング対戦',
              style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('非同期トレーニング対戦',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.orange,
          tabs: const [
            Tab(text: '対戦作成'),
            Tab(text: '進行中'),
            Tab(text: '結果'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreateTab(),
          _buildActiveDuelsTab(),
          _buildResultsTab(),
        ],
      ),
    );
  }

  Widget _buildCreateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Text(
            '新規対戦を作成',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _buildCreateCard(
            title: '1手詰め 5問',
            description: '基本的な詰将棋',
            difficulty: '1手詰め',
            icon: '🟢',
          ),
          const SizedBox(height: 12),
          _buildCreateCard(
            title: '3手詰め 5問',
            description: '中級レベル',
            difficulty: '3手詰め',
            icon: '🟡',
          ),
          const SizedBox(height: 12),
          _buildCreateCard(
            title: '5手詰め 5問',
            description: '上級レベル',
            difficulty: '5手詰め',
            icon: '🔴',
          ),
          const SizedBox(height: 32),
          const Text(
            '相手を選択',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildOpponentOption('CPU - easy', 'cpu_easy', '🤖'),
          const SizedBox(height: 8),
          _buildOpponentOption('CPU - normal', 'cpu_normal', '🤖🤖'),
          const SizedBox(height: 8),
          _buildOpponentOption('CPU - hard', 'cpu_hard', '🤖🤖🤖'),
          const SizedBox(height: 8),
          _buildOpponentOption('ランダムプレイヤー', 'random', '👥'),
        ],
      ),
    );
  }

  Widget _buildCreateCard({
    required String title,
    required String description,
    required String difficulty,
    required String icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withAlpha(80)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              onPressed: () {
                _showCreateDuelDialog(difficulty);
              },
              child: const Text('対戦を開始',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpponentOption(String name, String id, String emoji) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDuelDialog(String difficulty) {
    int selectedHours = 24;
    String selectedOpponent = 'cpu_normal';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: const Text(
            '対戦を開始',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '制限時間',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                selected: {selectedHours},
                onSelectionChanged: (selected) {
                  setLocalState(() {
                    selectedHours = selected.first;
                  });
                },
                segments: const [
                  ButtonSegment(value: 6, label: Text('6時間')),
                  ButtonSegment(value: 12, label: Text('12時間')),
                  ButtonSegment(value: 24, label: Text('24時間')),
                  ButtonSegment(value: 48, label: Text('48時間')),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '相手を選択',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: selectedOpponent,
                dropdownColor: const Color(0xFF16213E),
                items: const [
                  DropdownMenuItem(
                    value: 'cpu_easy',
                    child: Text('CPU - easy', style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem(
                    value: 'cpu_normal',
                    child: Text('CPU - normal', style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem(
                    value: 'cpu_hard',
                    child: Text('CPU - hard', style: TextStyle(color: Colors.white)),
                  ),
                  DropdownMenuItem(
                    value: 'random',
                    child: Text('ランダムプレイヤー', style: TextStyle(color: Colors.white)),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setLocalState(() {
                      selectedOpponent = value;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(ctx).pop,
              child: const Text('キャンセル', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                Navigator.of(ctx).pop();
                _createDuel(
                  difficulty: difficulty,
                  opponentName: _getOpponentDisplayName(selectedOpponent),
                  hours: selectedHours,
                );
              },
              child: const Text('開始', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  String _getOpponentDisplayName(String opponentId) {
    const map = {
      'cpu_easy': 'CPU - easy',
      'cpu_normal': 'CPU - normal',
      'cpu_hard': 'CPU - hard',
      'random': 'ランダムプレイヤー',
    };
    return map[opponentId] ?? 'CPU';
  }

  Widget _buildActiveDuelsTab() {
    if (_activeDuels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '進行中の対戦はありません',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                _tabController.animateTo(0);
              },
              child: const Text('対戦を作成',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeDuels.length,
      itemBuilder: (context, index) {
        final duel = _activeDuels[index];
        return _buildActiveDuelCard(duel);
      },
    );
  }

  Widget _buildActiveDuelCard(AsyncDuel duel) {
    final progress = duel.solvedCount / duel.questions.length;
    final remainingTime = duel.remainingMinutes;
    final isExpired = duel.isExpired;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpired ? Colors.red.withAlpha(80) : Colors.orange.withAlpha(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        duel.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'あなた vs ${duel.opponentName}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExpired ? Colors.red.withAlpha(30) : Colors.orange.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isExpired ? '期限切れ' : '${remainingTime}分',
                    style: TextStyle(
                      color: isExpired ? Colors.red : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '進捗: ${duel.solvedCount}/${duel.questions.length}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor:
                        AlwaysStoppedAnimation(Colors.orange.withAlpha(200)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                onPressed: isExpired
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _DuelSolveScreen(duel: duel),
                          ),
                        );
                      },
                child: Text(
                  isExpired ? '期限切れ' : '解く',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsTab() {
    if (_completedDuels.isEmpty) {
      return const Center(
        child: Text(
          '完了した対戦はありません',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _completedDuels.length,
      itemBuilder: (context, index) {
        final duel = _completedDuels[index];
        return _buildResultCard(duel);
      },
    );
  }

  Widget _buildResultCard(AsyncDuel duel) {
    final playerScore = duel.solvedCount;
    final opponentScore = duel.solvedCount - (Random().nextInt(3) - 1);
    final playerWon = playerScore > opponentScore;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: playerWon ? Colors.amber.withAlpha(80) : Colors.white12,
        ),
      ),
      child: Column(
        children: [
          if (playerWon)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(30),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🏆 ', style: TextStyle(fontSize: 20)),
                  Text(
                    'あなたが勝利！',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  duel.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            playerWon ? '🥇' : '🥈',
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'あなた',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$playerScore/5',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            duel.totalSolveTime.inMinutes.toString(),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            playerWon ? '🥈' : '🥇',
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            duel.opponentName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$opponentScore/5',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${duel.totalSolveTime.inMinutes + Random().nextInt(5)}分',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===== 対戦問題解く画面 =====

class _DuelSolveScreen extends StatefulWidget {
  final AsyncDuel duel;

  const _DuelSolveScreen({required this.duel});

  @override
  State<_DuelSolveScreen> createState() => _DuelSolveScreenState();
}

class _DuelSolveScreenState extends State<_DuelSolveScreen> {
  late int _currentQuestionIndex = 0;
  late Stopwatch _stopwatch;
  late Timer _timer;
  int _opponentStartedAt = 0;
  bool _opponentStarted = false;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {});
      if (!_opponentStarted && _stopwatch.elapsedMilliseconds > 3000) {
        _triggerOpponentStarted();
      }
    });
  }

  void _triggerOpponentStarted() {
    setState(() {
      _opponentStarted = true;
      _opponentStartedAt = _stopwatch.elapsed.inSeconds;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('相手が解き始めました！'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < widget.duel.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _finishDuel();
    }
  }

  void _finishDuel() {
    _stopwatch.stop();
    _timer.cancel();

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('対戦を完了しました'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.duel.questions[_currentQuestionIndex];
    final timeString = _formatDuration(
        Duration(seconds: _stopwatch.elapsed.inSeconds));

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: Text(
          '問題 ${_currentQuestionIndex + 1}/${widget.duel.questions.length}',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ヘッダー
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '累計時間',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    Text(
                      timeString,
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (_opponentStarted)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        '相手の進捗',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      Text(
                        '${Random().nextInt(5)}/5',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // 盤面
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  MiniBoardWidget(board: question.board),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16213E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '課題: 詰将棋を解く',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '先手が5手で詰ませるルートを見つけてください。\nタイマーは自動で進みます。',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // ボタン
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                onPressed: _nextQuestion,
                child: Text(
                  _currentQuestionIndex == widget.duel.questions.length - 1
                      ? '完了'
                      : '次へ',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
