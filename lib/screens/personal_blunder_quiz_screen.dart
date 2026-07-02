import 'package:flutter/material.dart';
import '../models/game_analysis.dart';

class PersonalBlunderQuizScreen extends StatefulWidget {
  final List<BlunderInfo> blunders;
  final List<BlunderInfo> historicalBlunders;

  const PersonalBlunderQuizScreen({
    required this.blunders,
    required this.historicalBlunders,
  });

  @override
  State<PersonalBlunderQuizScreen> createState() =>
      _PersonalBlunderQuizScreenState();
}

class _PersonalBlunderQuizScreenState extends State<PersonalBlunderQuizScreen> {
  late PageController _pageController;
  late List<BlunderQuestion> _questions;
  int _currentIndex = 0;
  int _correctCount = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _generateQuestions();
  }

  void _generateQuestions() {
    _questions = <BlunderQuestion>[];
    for (int i = 0; i < widget.blunders.length; i++) {
      final blunder = widget.blunders[i];
      final historicalCount = widget.historicalBlunders
          .where((h) =>
              h.toSquare == blunder.toSquare &&
              h.pieceMoved == blunder.pieceMoved)
          .length;

      _questions.add(BlunderQuestion(
        index: i,
        blunder: blunder,
        historicalCount: historicalCount,
        moveNum: blunder.moveNum,
        toSquare: blunder.toSquare,
        pieceMoved: blunder.pieceMoved,
        evalDelta: blunder.evalDelta,
      ));
    }
  }

  void _onAnswered(bool isCorrect) {
    if (isCorrect) {
      _correctCount++;
    }
    if (_currentIndex < _questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _showResultsDialog();
    }
  }

  void _showResultsDialog() {
    final accuracy = (_correctCount / _questions.length * 100).toInt();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '復習完了！',
          style: TextStyle(color: Colors.amber, fontSize: 24),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '$_correctCount / ${_questions.length}',
                    style: const TextStyle(
                      color: Colors.cyan,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '正答率 $accuracy%',
                    style: TextStyle(
                      color: accuracy >= 70
                          ? Colors.green.shade400
                          : Colors.orange.shade400,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_correctCount >= _questions.length)
              const Text(
                '完璧です！悪手のパターンをマスターしました 🎉',
                style: TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              )
            else if (accuracy >= 70)
              const Text(
                'もう一度チャレンジして完璧を目指しましょう',
                style: TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              )
            else
              const Text(
                'この悪手パターンを何度も練習して、改善を目指しましょう',
                style: TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text(
              '対局に戻る',
              style: TextStyle(color: Colors.cyan),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('悪手の復習'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.orange.shade700,
              ),
            ),
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemCount: _questions.length,
        itemBuilder: (context, index) => _buildQuizPage(
          _questions[index],
          index,
        ),
      ),
    );
  }

  Widget _buildQuizPage(BlunderQuestion question, int index) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // クイズ情報
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '問題 ${index + 1} / ${_questions.length}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'あなたは「${question.toSquare}${question.pieceMoved}」と指きました',
                  style: const TextStyle(color: Colors.white70),
                ),
                if (question.historicalCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '⚠️ このパターンは過去${question.historicalCount}回失敗しています',
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '評価値: ${question.evalDelta > 0 ? '+' : ''}${question.evalDelta} (悪手)',
                  style: TextStyle(color: Colors.red.shade300, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // クイズテキスト
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'この局面でのより良い手は？',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '（ヒント：評価値が大きく上がる手を探してください）',
                  style: TextStyle(
                    color: Colors.cyan,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 選択肢
          ..._buildOptions(question),

          const SizedBox(height: 20),
          if (index < _questions.length - 1)
            Center(
              child: TextButton(
                onPressed: () => _onAnswered(false),
                child: const Text(
                  'スキップ',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildOptions(BlunderQuestion question) {
    final options = [
      OptionCard(
        label: question.pieceMoved + 'を引く',
        isCorrect: false,
        onTap: () => _onAnswered(false),
      ),
      OptionCard(
        label: question.pieceMoved + 'を別の筋に',
        isCorrect: false,
        onTap: () => _onAnswered(false),
      ),
      OptionCard(
        label: '相手の攻め駒をはがす',
        isCorrect: true,
        onTap: () => _onAnswered(true),
      ),
    ];

    return [
      const SizedBox(height: 12),
      ...options
          .asMap()
          .entries
          .map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: e.value,
              ))
          .toList(),
    ];
  }
}

class BlunderQuestion {
  final int index;
  final BlunderInfo blunder;
  final int historicalCount;
  final int moveNum;
  final String toSquare;
  final String pieceMoved;
  final int evalDelta;

  BlunderQuestion({
    required this.index,
    required this.blunder,
    required this.historicalCount,
    required this.moveNum,
    required this.toSquare,
    required this.pieceMoved,
    required this.evalDelta,
  });
}

class OptionCard extends StatefulWidget {
  final String label;
  final bool isCorrect;
  final VoidCallback onTap;

  const OptionCard({
    required this.label,
    required this.isCorrect,
    required this.onTap,
  });

  @override
  State<OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<OptionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isPressed = false;
  bool _isAnswered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  void _handleTap() {
    if (_isAnswered) return;
    setState(() => _isAnswered = true);
    _animController.forward();
    widget.onTap();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCorrect = _isAnswered && widget.isCorrect;
    final isWrong = _isAnswered && !widget.isCorrect;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isCorrect
              ? Colors.green.withAlpha(60)
              : isWrong
                  ? Colors.red.withAlpha(60)
                  : Colors.white.withAlpha(10),
          border: Border.all(
            color: isCorrect
                ? Colors.green.shade400
                : isWrong
                    ? Colors.red.shade400
                    : Colors.white24,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (isCorrect)
              const Icon(Icons.check_circle, color: Colors.green, size: 20)
            else if (isWrong)
              const Icon(Icons.cancel, color: Colors.red, size: 20)
            else
              const Icon(Icons.radio_button_unchecked,
                  color: Colors.white54, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  color: isCorrect
                      ? Colors.green.shade300
                      : isWrong
                          ? Colors.red.shade300
                          : Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isCorrect)
              Text(
                '正解！',
                style: TextStyle(
                  color: Colors.green.shade400,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              )
            else if (isWrong)
              Text(
                'はずれ',
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
