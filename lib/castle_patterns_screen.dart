// lib/castle_patterns_screen.dart — 囲い（城）パターン説明

import 'package:flutter/material.dart';
import 'piece.dart';
import 'mini_board_widget.dart';

class CastlePatternsScreen extends StatelessWidget {
  const CastlePatternsScreen({super.key});

  // Helper to make empty 9x9 board
  static List<List<Piece?>> _empty() =>
      List.generate(9, (_) => List<Piece?>.filled(9, null, growable: true));

  // 矢倉
  static List<List<Piece?>> _yagura() {
    final b = _empty();
    b[7][1] = const Piece(PieceType.king, true);
    b[7][2] = const Piece(PieceType.gold, true);
    b[6][1] = const Piece(PieceType.silver, true);
    b[6][2] = const Piece(PieceType.gold, true);
    for (int c = 0; c <= 4; c++) {
      b[5][c] = const Piece(PieceType.pawn, true);
    }
    return b;
  }

  // 美濃
  static List<List<Piece?>> _mino() {
    final b = _empty();
    b[7][1] = const Piece(PieceType.king, true);
    b[7][2] = const Piece(PieceType.gold, true);
    b[6][2] = const Piece(PieceType.silver, true);
    for (int c = 0; c <= 2; c++) {
      b[5][c] = const Piece(PieceType.pawn, true);
    }
    return b;
  }

  // 穴熊
  static List<List<Piece?>> _anaguma() {
    final b = _empty();
    b[8][0] = const Piece(PieceType.king, true);
    b[8][1] = const Piece(PieceType.gold, true);
    b[7][0] = const Piece(PieceType.silver, true);
    b[7][1] = const Piece(PieceType.gold, true);
    b[7][2] = const Piece(PieceType.silver, true);
    return b;
  }

  // 金無双
  static List<List<Piece?>> _kinmusou() {
    final b = _empty();
    b[8][1] = const Piece(PieceType.king, true);
    b[7][0] = const Piece(PieceType.gold, true);
    b[7][2] = const Piece(PieceType.gold, true);
    b[8][2] = const Piece(PieceType.silver, true);
    return b;
  }

  // 舟囲い
  static List<List<Piece?>> _funegakoi() {
    final b = _empty();
    b[7][4] = const Piece(PieceType.king, true);
    b[8][3] = const Piece(PieceType.gold, true);
    b[8][5] = const Piece(PieceType.gold, true);
    b[7][3] = const Piece(PieceType.silver, true);
    return b;
  }

  // 銀冠
  static List<List<Piece?>> _ginkan() {
    final b = _empty();
    b[8][0] = const Piece(PieceType.king, true);
    b[7][0] = const Piece(PieceType.silver, true);
    b[8][1] = const Piece(PieceType.gold, true);
    b[7][1] = const Piece(PieceType.gold, true);
    b[6][0] = const Piece(PieceType.pawn, true);
    b[6][1] = const Piece(PieceType.pawn, true);
    b[6][2] = const Piece(PieceType.pawn, true);
    return b;
  }

  // 左美濃
  static List<List<Piece?>> _hidarimino() {
    final b = _empty();
    b[8][8] = const Piece(PieceType.king, true);
    b[8][7] = const Piece(PieceType.gold, true);
    b[7][7] = const Piece(PieceType.silver, true);
    b[7][6] = const Piece(PieceType.gold, true);
    b[6][6] = const Piece(PieceType.pawn, true);
    b[6][7] = const Piece(PieceType.pawn, true);
    b[6][8] = const Piece(PieceType.pawn, true);
    return b;
  }

  // 雁木
  static List<List<Piece?>> _gangi() {
    final b = _empty();
    b[8][6] = const Piece(PieceType.king, true);
    b[7][5] = const Piece(PieceType.silver, true);
    b[7][7] = const Piece(PieceType.silver, true);
    b[8][5] = const Piece(PieceType.gold, true);
    b[8][7] = const Piece(PieceType.gold, true);
    b[6][3] = const Piece(PieceType.pawn, true);
    b[6][4] = const Piece(PieceType.pawn, true);
    b[6][5] = const Piece(PieceType.pawn, true);
    b[6][6] = const Piece(PieceType.pawn, true);
    return b;
  }

  // カニ囲い
  static List<List<Piece?>> _kanigakoi() {
    final b = _empty();
    b[8][4] = const Piece(PieceType.king, true);
    b[8][3] = const Piece(PieceType.gold, true);
    b[8][5] = const Piece(PieceType.gold, true);
    b[7][4] = const Piece(PieceType.silver, true);
    b[6][3] = const Piece(PieceType.pawn, true);
    b[6][4] = const Piece(PieceType.pawn, true);
    b[6][5] = const Piece(PieceType.pawn, true);
    return b;
  }

  @override
  Widget build(BuildContext context) {
    final castles = [
      _CastleData(
        name: '矢倉（やぐら）',
        description: '金と銀を重ねて玉を守る、居飛車の代表的な囲い。堅固で初心者にも覚えやすい。',
        board: _yagura(),
        highlights: const {(7, 1), (7, 2), (6, 1), (6, 2)},
      ),
      _CastleData(
        name: '美濃囲い（みのがこい）',
        description: '振飛車党御用達の囲い。金銀でコンパクトに玉を守り、素早く組める。',
        board: _mino(),
        highlights: const {(7, 1), (7, 2), (6, 2)},
      ),
      _CastleData(
        name: '穴熊（あなぐま）',
        description: '玉を盤の隅に深く潜らせる最強クラスの囲い。組むのに手数がかかる。',
        board: _anaguma(),
        highlights: const {(8, 0), (8, 1), (7, 0), (7, 1), (7, 2)},
      ),
      _CastleData(
        name: '金無双（きんむそう）',
        description: '2枚の金将で玉を左右から守る。素早く組めるが横からの攻めに注意。',
        board: _kinmusou(),
        highlights: const {(8, 1), (7, 0), (7, 2)},
      ),
      _CastleData(
        name: '舟囲い（ふねがこい）',
        description: '最低限の手数で組める簡易囲い。急戦に対応しつつ玉を安全にする。',
        board: _funegakoi(),
        highlights: const {(7, 4), (8, 3), (8, 5), (7, 3)},
      ),
      _CastleData(
        name: '銀冠（ぎんかん）',
        description: '玉頭に銀を置いて守る形。金2枚+銀で上部を厚く守り、現代将棋で人気の高い囲い。',
        board: _ginkan(),
        highlights: const {(8, 0), (7, 0), (8, 1), (7, 1)},
      ),
      _CastleData(
        name: '左美濃（ひだりみの）',
        description: '居飛車側が右側に玉を囲う形。美濃囲いを左右反転させたような陣形で、対抗形で活躍する。',
        board: _hidarimino(),
        highlights: const {(8, 8), (8, 7), (7, 7), (7, 6)},
      ),
      _CastleData(
        name: '雁木（がんぎ）',
        description: '金2枚・銀2枚を高く構える囲い。攻守のバランスが良く、矢倉への対策としても有力。',
        board: _gangi(),
        highlights: const {(8, 6), (7, 5), (7, 7), (8, 5), (8, 7)},
      ),
      _CastleData(
        name: 'カニ囲い（かにがこい）',
        description: '玉を中央に置き金2枚で挟む形。カニのハサミに似た見た目。急戦時に素早く組める実戦的な囲い。',
        board: _kanigakoi(),
        highlights: const {(8, 4), (8, 3), (8, 5), (7, 4)},
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('囲い（城）パターン'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: '戻る',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: castles.length,
        separatorBuilder: (context, i) => const SizedBox(height: 16),
        itemBuilder: (context, i) => _CastleCard(data: castles[i]),
      ),
    );
  }
}

class _CastleData {
  final String name;
  final String description;
  final List<List<Piece?>> board;
  final Set<(int, int)> highlights;
  const _CastleData({
    required this.name,
    required this.description,
    required this.board,
    required this.highlights,
  });
}

class _CastleCard extends StatelessWidget {
  final _CastleData data;
  const _CastleCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        border: Border.all(color: Colors.amber.shade800.withAlpha(100), width: 1),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.name,
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: MiniBoardWidget(
              board: data.board,
              highlightSquares: data.highlights,
              size: 220,
            ),
          ),
        ],
      ),
    );
  }
}
