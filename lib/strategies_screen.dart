// lib/strategies_screen.dart — 戦法（開き方）説明

import 'package:flutter/material.dart';
import 'piece.dart';
import 'mini_board_widget.dart';

class StrategiesScreen extends StatelessWidget {
  const StrategiesScreen({super.key});

  // ---- Board position helpers ----

  static List<List<Piece?>> _baseBoard({bool includeBishops = true}) {
    final b = List.generate(9, (_) => List<Piece?>.filled(9, null));
    // 後手（上）初期配置
    b[0][0] = const Piece(PieceType.lance, false);
    b[0][1] = const Piece(PieceType.knight, false);
    b[0][2] = const Piece(PieceType.silver, false);
    b[0][3] = const Piece(PieceType.gold, false);
    b[0][4] = const Piece(PieceType.king, false);
    b[0][5] = const Piece(PieceType.gold, false);
    b[0][6] = const Piece(PieceType.silver, false);
    b[0][7] = const Piece(PieceType.knight, false);
    b[0][8] = const Piece(PieceType.lance, false);
    b[1][1] = const Piece(PieceType.rook, false);   // 後手飛車 8二
    if (includeBishops) b[1][7] = const Piece(PieceType.bishop, false);  // 後手角 2二
    for (int c = 0; c < 9; c++) { b[2][c] = const Piece(PieceType.pawn, false); }
    // 先手（下）初期配置
    b[8][0] = const Piece(PieceType.lance, true);
    b[8][1] = const Piece(PieceType.knight, true);
    b[8][2] = const Piece(PieceType.silver, true);
    b[8][3] = const Piece(PieceType.gold, true);
    b[8][4] = const Piece(PieceType.king, true);
    b[8][5] = const Piece(PieceType.gold, true);
    b[8][6] = const Piece(PieceType.silver, true);
    b[8][7] = const Piece(PieceType.knight, true);
    b[8][8] = const Piece(PieceType.lance, true);
    b[7][7] = const Piece(PieceType.rook, true);    // 先手飛車 2八
    if (includeBishops) b[7][1] = const Piece(PieceType.bishop, true);  // 先手角 8八
    for (int c = 0; c < 9; c++) { b[6][c] = const Piece(PieceType.pawn, true); }
    return b;
  }

  static List<List<Piece?>> _kakugawariBoard() {
    // 角換わり: 両角が交換済み（持ち駒）— 角のマスは空
    // _baseBoard(false)で飛車は既に正しい位置に置かれる
    return _baseBoard(includeBishops: false);
  }

  static List<List<Piece?>> _aiakariBoard() {
    // 相掛かり: 飛車は初期位置のまま、歩を少し動かした形
    return _baseBoard();
  }

  static List<List<Piece?>> _yokofuBoard() {
    // 横歩取り: 後手の3四歩を先手飛車が取りに行く
    final b = _baseBoard();
    b[6][2] = null; // 先手3六歩を突く
    b[3][2] = null; // 後手3四歩
    return b;
  }

  static List<List<Piece?>> _shikenbishaLeftBoard() {
    // 左四間飛車: 後手から見た四間飛車（後手が6二へ）
    final b = _baseBoard();
    b[1][1] = null; // 後手飛車を移動
    b[1][3] = const Piece(PieceType.rook, false); // 後手6二へ
    return b;
  }

  static List<List<Piece?>> _sankenbishaLeftBoard() {
    // 左三間飛車: 後手が7二へ
    final b = _baseBoard();
    b[1][1] = null;
    b[1][2] = const Piece(PieceType.rook, false); // 後手7二へ
    return b;
  }

  static List<List<Piece?>> _shikenbishaBoard() {
    // 四間飛車: 先手飛車を4八 (row=7, col=5) に移動
    final b = _baseBoard();
    b[7][7] = null;                                    // 2八から飛車を除去
    b[7][5] = const Piece(PieceType.rook, true);       // 4八に飛車
    return b;
  }

  static List<List<Piece?>> _sankenbishaBoard() {
    // 三間飛車: 先手飛車を3八 (row=7, col=6) に移動
    final b = _baseBoard();
    b[7][7] = null;                                    // 2八から飛車を除去
    b[7][6] = const Piece(PieceType.rook, true);       // 3八に飛車
    return b;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('戦法（開き方）'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: '戻る',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle('戦法とは'),
          _StrategyItem(
            '戦法の基本',
            'ゲームの序盤に、特定の手順で駒を動かし、優位な立場を作る作戦のことを「戦法」と呼びます。相手の対抗手段を読みながら戦いを進めます。',
          ),
          const SizedBox(height: 20),
          _SectionTitle('居飛車系戦法'),
          _DetailedStrategy(
            '角換わり',
            'お互いの角を交換する戦法。中盤の戦いが複雑になる傾向があります。',
            'この戦法は高度なテクニックが必要で、プロの将棋でもよく使われます。',
            _kakugawariBoard(),
            highlights: const {(1, 7), (7, 1)},  // 角が交換されたマス（空）
          ),
          _DetailedStrategy(
            '相掛かり',
            'お互いが同じ方向に飛車を置く戦法。力強い攻撃になりやすいです。',
            'シンプルながら奥が深く、初心者から上級者まで愛用される戦法です。',
            _aiakariBoard(),
            highlights: const {(1, 1), (7, 7)},  // 双方の飛車位置（8二と2八）
          ),
          const SizedBox(height: 20),
          _SectionTitle('振飛車系戦法'),
          _DetailedStrategy(
            '四間飛車（先手）',
            '先手が飛車を4筋（4八）に移動させる振飛車。バランスが良い基本の戦法。',
            '攻守バランスが良く、多くの対局で見られる振飛車の代表格です。',
            _shikenbishaBoard(),
            highlights: const {(7, 5)},  // 4八の飛車
          ),
          _DetailedStrategy(
            '四間飛車（後手）',
            '後手が飛車を6二に振る四間飛車。先手と左右が逆になります。',
            '後手番での振飛車は居飛車穴熊対策として有力です。',
            _shikenbishaLeftBoard(),
            highlights: const {(1, 3)},  // 後手6二の飛車
          ),
          _DetailedStrategy(
            '三間飛車（先手）',
            '飛車を3筋（3八）に移動させる戦法。攻撃的なスタイルが特徴。',
            '急戦もできる攻撃的な振飛車です。',
            _sankenbishaBoard(),
            highlights: const {(7, 6)},  // 3八の飛車
          ),
          _DetailedStrategy(
            '三間飛車（後手）',
            '後手が飛車を7二に振る三間飛車。石田流など多彩な変化があります。',
            '石田流三間飛車は積極的な攻めが持ち味です。',
            _sankenbishaLeftBoard(),
            highlights: const {(1, 2)},  // 後手7二の飛車
          ),
          const SizedBox(height: 20),
          _SectionTitle('戦法選びのコツ'),
          _TipItem(
            '自分のスタイルに合わせる',
            '攻撃的なのか防御的なのか、得意なスタイルで戦法を選びましょう。',
          ),
          _TipItem(
            '相手の動きを読む',
            '相手がどの戦法を選んでくるか予測することが重要です。',
          ),
          _TipItem(
            '練習を重ねる',
            '同じ戦法を何度も練習することで、その戦法の強さを引き出せます。',
          ),
          _TipItem(
            'バリエーションを学ぶ',
            '戦法には様々な応手があります。複数のバリエーションを学びましょう。',
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _StrategyItem extends StatelessWidget {
  final String title;
  final String description;
  const _StrategyItem(this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.brown.shade600,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Text(
                '⚔️',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailedStrategy extends StatelessWidget {
  final String name;
  final String description;
  final String memo;
  final List<List<Piece?>> board;
  final Set<(int, int)> highlights;

  const _DetailedStrategy(this.name, this.description, this.memo, this.board, {
    this.highlights = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          border: const Border(left: BorderSide(color: Colors.cyan, width: 4)),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                color: Colors.cyan,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: MiniBoardWidget(
                board: board,
                highlightSquares: highlights,
                size: 220,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0D3C66),
                borderRadius: BorderRadius.circular(3),
              ),
              padding: const EdgeInsets.all(8),
              child: Text(
                '💡 $memo',
                style: const TextStyle(
                  color: Colors.lightBlue,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final String title;
  final String description;
  const _TipItem(this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              color: Colors.cyan.shade600,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text(
                '✓',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
