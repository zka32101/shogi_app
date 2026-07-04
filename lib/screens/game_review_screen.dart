import 'package:flutter/material.dart';
import '../models/game_analysis.dart';

class GameReviewScreen extends StatefulWidget {
  final GameAnalysis gameAnalysis;

  const GameReviewScreen({
    required this.gameAnalysis,
    super.key,
  });

  @override
  State<GameReviewScreen> createState() => _GameReviewScreenState();
}

class _GameReviewScreenState extends State<GameReviewScreen> {
  int _currentMoveIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('棋譜解説'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 進捗表示
          _buildProgressBar(),
          const SizedBox(height: 16),
          // メインコンテンツ
          Expanded(
            child: _buildReviewContent(),
          ),
          // ナビゲーションボタン
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = widget.gameAnalysis.moveNotations.isEmpty
        ? 0.0
        : (_currentMoveIndex + 1) / widget.gameAnalysis.moveNotations.length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currentMoveIndex + 1}/${widget.gameAnalysis.moveNotations.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getMoveQualityLabel(_currentMoveIndex),
                style: TextStyle(
                  color: _getMoveQualityColor(_currentMoveIndex),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyan),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewContent() {
    if (widget.gameAnalysis.moveNotations.isEmpty) {
      return const Center(
        child: Text(
          '対局データがありません',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    final move = widget.gameAnalysis.moveNotations[_currentMoveIndex];
    final eval = _currentMoveIndex < widget.gameAnalysis.evalHistory.length
        ? widget.gameAnalysis.evalHistory[_currentMoveIndex]
        : null;
    final nextEval = (_currentMoveIndex + 1) <
            widget.gameAnalysis.evalHistory.length
        ? widget.gameAnalysis.evalHistory[_currentMoveIndex + 1]
        : null;

    // 良手・悪手の判定
    final blunder = widget.gameAnalysis.blunders
        .firstWhereOrNull((b) => b.moveNum == _currentMoveIndex + 1);
    final goodMove = widget.gameAnalysis.goodMoves
        .firstWhereOrNull((g) => g.moveNum == _currentMoveIndex + 1);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 現在の手
          _buildMoveCard(move, eval),
          const SizedBox(height: 16),

          // コーチング情報
          if (blunder != null)
            _buildBlunderCard(blunder)
          else if (goodMove != null)
            _buildGoodMoveCard(goodMove)
          else
            _buildNeutralMoveCard(),

          const SizedBox(height: 16),

          // 評価値変化
          if (eval != null && nextEval != null)
            _buildEvalChangeCard(eval, nextEval),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMoveCard(String move, int? eval) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        border: Border.all(color: Colors.cyan.withAlpha(60)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '現在の手',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                move,
                style: const TextStyle(
                  color: Colors.cyan,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Courier',
                ),
              ),
              if (eval != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '評価値',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      eval.toString(),
                      style: TextStyle(
                        color: eval > 0 ? Colors.green : Colors.orange,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlunderCard(BlunderInfo blunder) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(30),
        border: Border.all(color: Colors.red.withAlpha(100)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              const Text(
                '悪手（ブラッシャー）',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '評価値がΔ${blunder.evalDelta}低下しました',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🤖 AI解説',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _getBlunderExplanation(blunder.evalDelta),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoodMoveCard(GoodMoveInfo goodMove) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(30),
        border: Border.all(color: Colors.green.withAlpha(100)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text(
                '好手',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '評価値がΔ${goodMove.evalDelta}向上しました',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✨ 実力が発揮できた一手です',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeutralMoveCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.cyan, size: 20),
              SizedBox(width: 8),
              Text(
                '通常の手',
                style: TextStyle(
                  color: Colors.cyan,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '適切な判断ができています',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvalChangeCard(int eval, int nextEval) {
    final delta = nextEval - eval;
    final improved = delta > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '評価値推移',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$eval → $nextEval',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                improved ? Icons.trending_up : Icons.trending_down,
                color: improved ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                '${improved ? '+' : ''}$delta',
                style: TextStyle(
                  color: improved ? Colors.green : Colors.orange,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF16213E),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _currentMoveIndex > 0
                  ? () => setState(() => _currentMoveIndex--)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white12,
                disabledBackgroundColor: Colors.white.withAlpha(5),
              ),
              child: const Text('前の手'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentMoveIndex <
                      widget.gameAnalysis.moveNotations.length - 1
                  ? () => setState(() => _currentMoveIndex++)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan.withAlpha(100),
                disabledBackgroundColor: Colors.white.withAlpha(5),
              ),
              child: const Text('次の手'),
            ),
          ),
        ],
      ),
    );
  }

  String _getMoveQualityLabel(int moveIndex) {
    final blunder =
        widget.gameAnalysis.blunders.firstWhereOrNull((b) => b.moveNum == moveIndex + 1);
    final goodMove =
        widget.gameAnalysis.goodMoves.firstWhereOrNull((g) => g.moveNum == moveIndex + 1);

    if (blunder != null) return '悪手';
    if (goodMove != null) return '好手';
    return '通常';
  }

  Color _getMoveQualityColor(int moveIndex) {
    final label = _getMoveQualityLabel(moveIndex);
    switch (label) {
      case '悪手':
        return Colors.red;
      case '好手':
        return Colors.green;
      default:
        return Colors.white54;
    }
  }

  String _getBlunderExplanation(int delta) {
    if (delta <= -200) {
      return '大きなミスです。この局面では別の手を選ぶべきでした。';
    } else if (delta <= -100) {
      return 'この手は損になっています。より良い選択肢を探しましょう。';
    }
    return '判断の甘さが出ました。局面をもっと詳しく分析してください。';
  }
}

extension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
