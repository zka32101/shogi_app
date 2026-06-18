import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'mini_board_widget.dart';
import 'piece.dart';

class MicroTrainingScreen extends StatefulWidget {
  const MicroTrainingScreen({Key? key}) : super(key: key);

  @override
  State<MicroTrainingScreen> createState() => _MicroTrainingScreenState();
}

class _MicroTrainingScreenState extends State<MicroTrainingScreen>
    with WidgetsBindingObserver {
  // Problem data structure
  late List<MicroTrainingProblem> todayProblems;
  int currentProblemIndex = 0;

  // Timer
  late Timer _timer;
  int _secondsRemaining = 180; // 3 minutes
  bool _timerRunning = false;
  DateTime _sessionStartTime = DateTime.now();

  // Results
  int _correctCount = 0;
  int _skippedCount = 0;
  List<bool> _problemResults = []; // true = correct, false = incorrect/skipped
  bool _sessionCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeTodayProblems();
    _startTimer();
    _scheduleNotification();
  }

  void _initializeTodayProblems() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Generate 3 problems (rotate daily based on date hash)
    todayProblems = _generateDailyProblems(today);
    _problemResults = List.filled(3, false);
  }

  List<MicroTrainingProblem> _generateDailyProblems(String dateStr) {
    // In a real app, fetch from database or API
    // For now, use pseudo-random rotation based on date
    final dateHash = dateStr.hashCode.abs();

    final allProblems = [
      // Tsume (詰め) - mate in X
      MicroTrainingProblem(
        type: 'tsume',
        title: '詰め: 3手詰め',
        boardFen: '8/8/8/8/8/8/8/8 b - - 0 1', // Placeholder FEN
        choices: ['▲3五飛', '▲4五金', '▲5四歩'],
        correctAnswerIndex: 0,
        explanation: '▲3五飛で詰みです。次に▲4五飛で避けられません。',
      ),
      // Tesuji (手筋) - technique
      MicroTrainingProblem(
        type: 'tesuji',
        title: '手筋: 空き家の妙手',
        boardFen: '8/8/8/8/8/8/8/8 b - - 0 1', // Placeholder FEN
        choices: ['▲5四馬', '▲6三金', '▲7二銀'],
        correctAnswerIndex: 1,
        explanation: '▲6三金が好手！飛車の効きが広がります。',
      ),
      // Next move (次の一手)
      MicroTrainingProblem(
        type: 'next_move',
        title: '次の一手: 形勢判断',
        boardFen: '8/8/8/8/8/8/8/8 b - - 0 1', // Placeholder FEN
        choices: ['▲2四歩', '▲1五角', '▲3六銀'],
        correctAnswerIndex: 2,
        explanation: '▲3六銀で堅陣を築きます。守備力が重要です。',
      ),
      // Additional problems for rotation
      MicroTrainingProblem(
        type: 'tsume',
        title: '詰め: 5手詰め',
        boardFen: '8/8/8/8/8/8/8/8 b - - 0 1',
        choices: ['▲4四角', '▲5五金', '▲6六飛'],
        correctAnswerIndex: 0,
        explanation: '▲4四角から始まる詰み筋です。',
      ),
      MicroTrainingProblem(
        type: 'tesuji',
        title: '手筋: 後ろからの攻撃',
        boardFen: '8/8/8/8/8/8/8/8 b - - 0 1',
        choices: ['▲7五飛', '▲8四金', '▲9三銀'],
        correctAnswerIndex: 0,
        explanation: '▲7五飛で背後から攻撃。強烈です。',
      ),
      MicroTrainingProblem(
        type: 'next_move',
        title: '次の一手: 勝利への道',
        boardFen: '8/8/8/8/8/8/8/8 b - - 0 1',
        choices: ['▲4六歩', '▲5五角', '▲6四金'],
        correctAnswerIndex: 1,
        explanation: '▲5五角で主導権を握ります。',
      ),
    ];

    // Rotate based on date hash: pick problems 0,1,2 or 1,2,3, etc.
    final startIndex = (dateHash % (allProblems.length - 2));
    return [
      allProblems[startIndex],
      allProblems[(startIndex + 1) % allProblems.length],
      allProblems[(startIndex + 2) % allProblems.length],
    ];
  }

  void _startTimer() {
    _timerRunning = true;
    _sessionStartTime = DateTime.now();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _completeSession();
          _timer.cancel();
        }
      });
    });
  }

  void _answerProblem(int choiceIndex) {
    final problem = todayProblems[currentProblemIndex];
    final isCorrect = choiceIndex == problem.correctAnswerIndex;

    _problemResults[currentProblemIndex] = isCorrect;
    if (isCorrect) {
      _correctCount++;
      _showFeedback(true, problem.explanation);
    } else {
      _showFeedback(false, problem.explanation);
    }

    Future.delayed(Duration(seconds: 2), () {
      if (!mounted) return;
      _moveToNextProblem();
    });
  }

  void _skipProblem() {
    _skippedCount++;
    _problemResults[currentProblemIndex] = false;
    _moveToNextProblem();
  }

  void _moveToNextProblem() {
    setState(() {
      if (currentProblemIndex < 2) {
        currentProblemIndex++;
      } else {
        _completeSession();
      }
    });
  }

  void _completeSession() {
    _timer.cancel();
    _timerRunning = false;
    _sessionCompleted = true;

    // Save to SharedPreferences
    _saveMicroTrainingResult();

    setState(() {});
  }

  Future<void> _saveMicroTrainingResult() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final key = 'micro_training_today_$today';

    final result = {
      'date': today,
      'timestamp': DateTime.now().toIso8601String(),
      'correct_count': _correctCount,
      'skipped_count': _skippedCount,
      'time_spent_seconds': 180 - _secondsRemaining,
      'problem_results': _problemResults,
    };

    await prefs.setString(key, jsonEncode(result));
  }

  void _showFeedback(bool isCorrect, String explanation) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCorrect ? '✓ 正解！' : '✗ 不正解',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isCorrect ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
            SizedBox(height: 8),
            Text(
              explanation,
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: isCorrect ? Colors.green[800] : Colors.red[800],
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _scheduleNotification() {
    // Mock notification scheduling
    // In a real app, use flutter_local_notifications or firebase_messaging
    debugPrint('📬 朝7時に毎日通知を送信予定です (Mock)');
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _closeScreen() {
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionCompleted) {
      return _buildResultScreen();
    }

    return Scaffold(
      backgroundColor: Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        title: Text(
          '3分筋トレ',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.amber[400],
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white70),
          onPressed: _closeScreen,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header: Problem counter + Timer
            _buildHeaderBar(),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 24),
                    _buildProblemTitle(),
                    SizedBox(height: 32),

                    // Placeholder board visualization
                    _buildBoardArea(),

                    SizedBox(height: 32),

                    // Problem type label
                    _buildProblemTypeLabel(),

                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Answer buttons
            _buildAnswerButtons(),

            // Skip button
            _buildSkipButton(),

            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      color: Color(0xFF1A1A1A),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Problem counter
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${currentProblemIndex + 1}/3',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.amber[400],
              ),
            ),
          ),

          // Timer with icon
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _secondsRemaining < 30
                  ? Color(0xFF4A2222)
                  : Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
              border: _secondsRemaining < 30
                  ? Border.all(color: Colors.red[400]!, width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer,
                  color: _secondsRemaining < 30
                      ? Colors.red[400]
                      : Colors.cyan[400],
                  size: 18,
                ),
                SizedBox(width: 6),
                Text(
                  _formatTime(_secondsRemaining),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _secondsRemaining < 30
                        ? Colors.red[400]
                        : Colors.cyan[400],
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemTitle() {
    final problem = todayProblems[currentProblemIndex];
    return Text(
      problem.title,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildProblemTypeLabel() {
    final problem = todayProblems[currentProblemIndex];
    final typeLabel = _getProblemTypeLabel(problem.type);
    final typeColor = _getProblemTypeColor(problem.type);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: typeColor.withOpacity(0.2),
        border: Border.all(color: typeColor, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        typeLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: typeColor,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  String _getProblemTypeLabel(String type) {
    switch (type) {
      case 'tsume':
        return '詰め問題';
      case 'tesuji':
        return '手筋問題';
      case 'next_move':
        return '次の一手';
      default:
        return '問題';
    }
  }

  Color _getProblemTypeColor(String type) {
    switch (type) {
      case 'tsume':
        return Colors.red[400]!;
      case 'tesuji':
        return Colors.orange[400]!;
      case 'next_move':
        return Colors.blue[400]!;
      default:
        return Colors.grey[400]!;
    }
  }

  // 問題インデックスに応じたサンプル盤面を生成
  List<List<Piece?>> _buildSampleBoard(int problemIndex) {
    final board = List.generate(9, (_) => List<Piece?>.filled(9, null));
    // 共通: 両玉
    board[0][0] = Piece(PieceType.king, false); // 後手玉
    board[8][8] = Piece(PieceType.king, true);  // 先手玉
    switch (problemIndex % 3) {
      case 0: // 詰将棋タイプ
        board[1][0] = Piece(PieceType.gold, true);
        board[2][1] = Piece(PieceType.rook, true);
        board[0][1] = Piece(PieceType.silver, false);
        break;
      case 1: // 手筋タイプ
        board[3][3] = Piece(PieceType.bishop, true);
        board[2][2] = Piece(PieceType.gold, false);
        board[4][4] = Piece(PieceType.pawn, true);
        board[1][1] = Piece(PieceType.pawn, false);
        break;
      case 2: // 次の一手タイプ
        board[4][4] = Piece(PieceType.rook, true);
        board[3][3] = Piece(PieceType.gold, true);
        board[2][5] = Piece(PieceType.silver, false);
        board[3][6] = Piece(PieceType.gold, false);
        break;
    }
    return board;
  }

  Widget _buildBoardArea() {
    final board = _buildSampleBoard(currentProblemIndex);
    return SizedBox(
      width: 280,
      child: MiniBoardWidget(
        board: board,
        showLabels: true,
        size: 280,
      ),
    );
  }

  Widget _buildAnswerButtons() {
    final problem = todayProblems[currentProblemIndex];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (int i = 0; i < problem.choices.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _answerProblem(i),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2A3A4A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: Colors.cyan[700]!,
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Text(
                    problem.choices[i],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.cyan[300],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkipButton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: _skipProblem,
          icon: Icon(Icons.skip_next),
          label: Text('スキップ (-1点)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white54,
            side: BorderSide(color: Colors.white30, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final elapsedSeconds = 180 - _secondsRemaining;
    final totalScore = _correctCount;

    return Scaffold(
      backgroundColor: Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        title: Text(
          '結果',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.amber[400],
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                SizedBox(height: 32),

                // Celebration icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Color(0xFF2A3A4A),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: Colors.amber[400]!,
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '🎯',
                      style: TextStyle(fontSize: 60),
                    ),
                  ),
                ),

                SizedBox(height: 32),

                // Main message
                Text(
                  'おつかれさま！',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: 16),

                // Encouragement
                Text(
                  totalScore == 3
                      ? 'パーフェクト！見事です！'
                      : totalScore == 2
                          ? 'よくできました！'
                          : '頑張ってください！',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.cyan[300],
                    fontStyle: FontStyle.italic,
                  ),
                ),

                SizedBox(height: 48),

                // Results card
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    border: Border.all(
                      color: Colors.amber[700]!,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildResultRow(
                        '正解数',
                        '$_correctCount/3',
                        Colors.greenAccent,
                      ),
                      Divider(
                        color: Colors.white10,
                        height: 24,
                      ),
                      _buildResultRow(
                        '所要時間',
                        _formatTime(elapsedSeconds),
                        Colors.cyan[300]!,
                      ),
                      Divider(
                        color: Colors.white10,
                        height: 24,
                      ),
                      _buildResultRow(
                        'スキップ',
                        '$_skippedCount回',
                        Colors.orange[400]!,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 48),

                // Daily challenge message
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[900]?.withOpacity(0.3),
                    border: Border.all(
                      color: Colors.blue[400]!,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: Colors.blue[400],
                        size: 28,
                      ),
                      SizedBox(height: 12),
                      Text(
                        '📬 朝7時に通知予定',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue[300],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '毎日新しい問題をお届けします',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[200],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 48),

                // Main CTA
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _closeScreen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[700],
                      foregroundColor: Colors.black,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      '明日もチャレンジ！',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 12),

                // Secondary button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _closeScreen,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white30, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'トップに戻る',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: valueColor,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

// Data model for micro training problems
class MicroTrainingProblem {
  final String type; // 'tsume', 'tesuji', 'next_move'
  final String title;
  final String boardFen;
  final List<String> choices;
  final int correctAnswerIndex;
  final String explanation;

  MicroTrainingProblem({
    required this.type,
    required this.title,
    required this.boardFen,
    required this.choices,
    required this.correctAnswerIndex,
    required this.explanation,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'title': title,
    'boardFen': boardFen,
    'choices': choices,
    'correctAnswerIndex': correctAnswerIndex,
    'explanation': explanation,
  };

  factory MicroTrainingProblem.fromJson(Map<String, dynamic> json) =>
      MicroTrainingProblem(
        type: json['type'] as String,
        title: json['title'] as String,
        boardFen: json['boardFen'] as String,
        choices: List<String>.from(json['choices'] as List),
        correctAnswerIndex: json['correctAnswerIndex'] as int,
        explanation: json['explanation'] as String,
      );
}
