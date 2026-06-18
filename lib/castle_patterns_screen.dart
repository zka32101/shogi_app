// lib/castle_patterns_screen.dart — 囲い（城）パターン説明

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'piece.dart';
import 'mini_board_widget.dart';

class CastlePatternsScreen extends StatefulWidget {
  const CastlePatternsScreen({super.key});

  @override
  State<CastlePatternsScreen> createState() => _CastlePatternsScreenState();
}

class _CastlePatternsScreenState extends State<CastlePatternsScreen> {
  String? _selectedDifficulty; // null = all, '初級', '中級', '上級'
  String? _selectedSource; // null = all, sources

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'フィルター',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '難度',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['初級', '中級', '上級'].map((difficulty) {
                      final isSelected = _selectedDifficulty == difficulty;
                      return FilterChip(
                        label: Text(difficulty),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedDifficulty = selected ? difficulty : null;
                          });
                          this.setState(() {});
                        },
                        backgroundColor: const Color(0xFF0F3460),
                        selectedColor: Colors.amber.shade600,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '出典',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['将棋講座.com', '将棋研究'].map((source) {
                      final isSelected = _selectedSource == source;
                      return FilterChip(
                        label: Text(source),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedSource = selected ? source : null;
                          });
                          this.setState(() {});
                        },
                        backgroundColor: const Color(0xFF0F3460),
                        selectedColor: Colors.amber.shade600,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade600,
                      minimumSize: const Size.fromHeight(40),
                    ),
                    child: const Text(
                      '閉じる',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Helper to make empty 9x9 board
  static List<List<Piece?>> _empty() =>
      List.generate(9, (_) => List<Piece?>.filled(9, null, growable: true));

  // 居玉（きょぎょく）
  static List<List<Piece?>> _kyogyoku() {
    final b = _empty();
    b[8][4] = const Piece(PieceType.king, true);
    return b;
  }

  // 渡辺システム
  static List<List<Piece?>> _watanabeSystem() {
    final b = _empty();
    b[8][4] = const Piece(PieceType.king, true);
    b[8][3] = const Piece(PieceType.gold, true);
    b[8][5] = const Piece(PieceType.gold, true);
    b[7][4] = const Piece(PieceType.silver, true);
    b[7][3] = const Piece(PieceType.gold, true);
    b[7][5] = const Piece(PieceType.silver, true);
    b[6][2] = const Piece(PieceType.pawn, true);
    b[6][3] = const Piece(PieceType.pawn, true);
    b[6][4] = const Piece(PieceType.pawn, true);
    b[6][5] = const Piece(PieceType.pawn, true);
    b[6][6] = const Piece(PieceType.pawn, true);
    return b;
  }

  // 矢倉角換わり
  static List<List<Piece?>> _yaguraKakuKawari() {
    final b = _empty();
    b[7][1] = const Piece(PieceType.king, true);
    b[7][2] = const Piece(PieceType.gold, true);
    b[6][1] = const Piece(PieceType.silver, true);
    b[6][2] = const Piece(PieceType.gold, true);
    b[5][0] = const Piece(PieceType.pawn, true);
    b[5][1] = const Piece(PieceType.pawn, true);
    b[5][2] = const Piece(PieceType.pawn, true);
    b[8][8] = const Piece(PieceType.bishop, true);
    return b;
  }

  // 中田功システム
  static List<List<Piece?>> _nakadaKouSystem() {
    final b = _empty();
    b[8][0] = const Piece(PieceType.king, true);
    b[8][1] = const Piece(PieceType.gold, true);
    b[7][0] = const Piece(PieceType.silver, true);
    b[7][1] = const Piece(PieceType.gold, true);
    b[7][2] = const Piece(PieceType.silver, true);
    b[6][0] = const Piece(PieceType.pawn, true);
    b[6][1] = const Piece(PieceType.pawn, true);
    b[6][2] = const Piece(PieceType.pawn, true);
    b[8][3] = const Piece(PieceType.rook, true);
    return b;
  }

  // 矢倉
  static List<List<Piece?>> _yagura() {
    final b = _empty();
    b[7][1] = const Piece(PieceType.king, true);
    b[7][2] = const Piece(PieceType.gold, true);
    b[6][2] = const Piece(PieceType.silver, true);  // 7七銀
    b[6][3] = const Piece(PieceType.gold, true);    // 6七金
    for (int c = 0; c <= 4; c++) {
      b[5][c] = const Piece(PieceType.pawn, true);
    }
    return b;
  }

  // 美濃
  static List<List<Piece?>> _mino() {
    final b = _empty();
    b[7][7] = const Piece(PieceType.king, true);   // 2八玉（振り飛車・右玉）
    b[7][6] = const Piece(PieceType.gold, true);   // 3八金
    b[6][6] = const Piece(PieceType.silver, true); // 3七銀
    for (int c = 6; c <= 8; c++) {
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
    b[7][1] = const Piece(PieceType.silver, true); // 8八銀（玉頭）← 銀冠の特徴
    b[8][1] = const Piece(PieceType.gold, true);
    b[7][0] = const Piece(PieceType.gold, true);   // 9八金
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
    b[7][3] = const Piece(PieceType.king, true);   // 6八玉（居飛車）
    b[7][4] = const Piece(PieceType.gold, true);   // 5八金
    b[6][3] = const Piece(PieceType.gold, true);   // 6七金
    b[6][2] = const Piece(PieceType.silver, true); // 7七銀
    b[6][4] = const Piece(PieceType.silver, true); // 5七銀
    b[5][3] = const Piece(PieceType.pawn, true);
    b[5][4] = const Piece(PieceType.pawn, true);
    b[5][5] = const Piece(PieceType.pawn, true);
    b[5][6] = const Piece(PieceType.pawn, true);
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
    final allCastles = [
      // 初級
      _CastleData(
        name: '居玉（きょぎょく）',
        description: '王が玉の初期位置のままの形。最も簡易的な形で、初心者向け学習用。',
        board: _kyogyoku(),
        highlights: const {(8, 4)},
        difficulty: '初級',
        source: '将棋講座.com',
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/joseki/',
        sourceTitle: '将棋講座.com',
      ),
      _CastleData(
        name: '矢倉（やぐら）',
        description: '金と銀を重ねて玉を守る、居飛車の代表的な囲い。堅固で初心者にも覚えやすい。',
        board: _yagura(),
        highlights: const {(7, 1), (7, 2), (6, 2), (6, 3)},
        difficulty: '初級',
        source: '将棋講座.com',
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/joseki/',
        sourceTitle: '将棋講座.com',
      ),
      _CastleData(
        name: '美濃囲い（みのがこい）',
        description: '振飛車党御用達の囲い。金銀でコンパクトに玉を守り、素早く組める。',
        board: _mino(),
        highlights: const {(7, 7), (7, 6), (6, 6)},
        difficulty: '初級',
        source: '将棋講座.com',
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/joseki/',
        sourceTitle: '将棋講座.com',
      ),
      _CastleData(
        name: '舟囲い（ふねがこい）',
        description: '最低限の手数で組める簡易囲い。急戦に対応しつつ玉を安全にする。',
        board: _funegakoi(),
        highlights: const {(7, 4), (8, 3), (8, 5), (7, 3)},
        difficulty: '初級',
        source: '将棋講座.com',
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/joseki/',
        sourceTitle: '将棋講座.com',
      ),
      // 中級
      _CastleData(
        name: '金無双（きんむそう）',
        description: '2枚の金将で玉を左右から守る。素早く組めるが横からの攻めに注意。',
        board: _kinmusou(),
        highlights: const {(8, 1), (7, 0), (7, 2)},
        difficulty: '中級',
        source: '将棋研究',
        sourceUrl: 'https://www.shougi.jp/learn/castle/',
        sourceTitle: 'SHOGUN',
      ),
      _CastleData(
        name: '銀冠（ぎんかん）',
        description: '玉頭に銀を置いて守る形。金2枚+銀で上部を厚く守り、現代将棋で人気の高い囲い。',
        board: _ginkan(),
        highlights: const {(8, 0), (7, 1), (8, 1), (7, 0)},
        difficulty: '中級',
        source: '将棋講座.com',
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/joseki/',
        sourceTitle: '将棋講座.com',
      ),
      _CastleData(
        name: '左美濃（ひだりみの）',
        description: '居飛車側が右側に玉を囲う形。美濃囲いを左右反転させたような陣形で、対抗形で活躍する。',
        board: _hidarimino(),
        highlights: const {(8, 8), (8, 7), (7, 7), (7, 6)},
        difficulty: '中級',
        source: '将棋講座.com',
        sourceUrl: 'https://xn--pet04dr1n5x9a.com/joseki/',
        sourceTitle: '将棋講座.com',
      ),
      _CastleData(
        name: '雁木（がんぎ）',
        description: '金2枚・銀2枚を高く構える囲い。攻守のバランスが良く、矢倉への対策としても有力。',
        board: _gangi(),
        highlights: const {(7, 3), (7, 4), (6, 3), (6, 2), (6, 4)},
        difficulty: '中級',
        source: '将棋研究',
        sourceUrl: 'https://www.shougi.jp/learn/castle/',
        sourceTitle: 'SHOGUN',
      ),
      _CastleData(
        name: 'カニ囲い（かにがこい）',
        description: '玉を中央に置き金2枚で挟む形。カニのハサミに似た見た目。急戦時に素早く組める実戦的な囲い。',
        board: _kanigakoi(),
        highlights: const {(8, 4), (8, 3), (8, 5), (7, 4)},
        difficulty: '中級',
        source: '',
        sourceTitle: '',
      ),
      _CastleData(
        name: '渡辺システム',
        description: 'プロ将棋で注目される現代的な囲い。複雑な構成で、高度なテクニックを要する。',
        board: _watanabeSystem(),
        highlights: const {(8, 4), (8, 3), (8, 5), (7, 4), (7, 3), (7, 5)},
        difficulty: '中級',
        source: '将棋研究',
        sourceUrl: 'https://www.shougi.jp/learn/castle/',
        sourceTitle: 'SHOGUN',
      ),
      // 上級
      _CastleData(
        name: '穴熊（あなぐま）',
        description: '玉を盤の隅に深く潜らせる最強クラスの囲い。組むのに手数がかかる。',
        board: _anaguma(),
        highlights: const {(8, 0), (8, 1), (7, 0), (7, 1), (7, 2)},
        difficulty: '上級',
        source: '将棋研究',
        sourceUrl: 'https://www.shougi.jp/learn/castle/',
        sourceTitle: 'SHOGUN',
      ),
      _CastleData(
        name: '矢倉角換わり',
        description: '矢倉から角を交換した形。変化型として学習価値が高く、複雑な戦いが展開される。',
        board: _yaguraKakuKawari(),
        highlights: const {(7, 1), (7, 2), (6, 1), (6, 2), (8, 8)},
        difficulty: '上級',
        source: '',
        sourceTitle: '',
      ),
      _CastleData(
        name: '中田功システム',
        description: '振飛車対策の精密な囲い。高度なテクニックを要し、プロでも活用される最先端の形。',
        board: _nakadaKouSystem(),
        highlights: const {(8, 0), (8, 1), (7, 0), (7, 1), (7, 2), (8, 3)},
        difficulty: '上級',
        source: '将棋研究',
        sourceUrl: 'https://www.shougi.jp/learn/castle/',
        sourceTitle: 'SHOGUN',
      ),
    ];

    // Apply filters
    final filteredCastles = allCastles.where((castle) {
      if (_selectedDifficulty != null && castle.difficulty != _selectedDifficulty) {
        return false;
      }
      if (_selectedSource != null && castle.source != _selectedSource) {
        return false;
      }
      return true;
    }).toList();

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
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.amber),
            tooltip: 'フィルター',
            onPressed: _showFilterMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedDifficulty != null || _selectedSource != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    '絞込: ',
                    style: TextStyle(color: Colors.amber.shade400, fontSize: 12),
                  ),
                  if (_selectedDifficulty != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(_selectedDifficulty!),
                        backgroundColor: Colors.amber.shade600,
                        labelStyle: const TextStyle(color: Colors.black, fontSize: 11),
                      ),
                    ),
                  if (_selectedSource != null)
                    Chip(
                      label: Text(_selectedSource!),
                      backgroundColor: Colors.amber.shade600,
                      labelStyle: const TextStyle(color: Colors.black, fontSize: 11),
                    ),
                ],
              ),
            ),
          Expanded(
            child: filteredCastles.isEmpty
                ? Center(
                    child: Text(
                      'マッチする囲いがありません',
                      style: TextStyle(color: Colors.white.withAlpha(150)),
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredCastles.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 16),
                    itemBuilder: (context, i) => _CastleCard(data: filteredCastles[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CastleData {
  final String name;
  final String description;
  final List<List<Piece?>> board;
  final Set<(int, int)> highlights;
  final String? sourceUrl;
  final String? sourceTitle;
  final String difficulty; // '初級', '中級', '上級'
  final String source; // '将棋講座.com', '将棋研究'

  const _CastleData({
    required this.name,
    required this.description,
    required this.board,
    required this.highlights,
    this.sourceUrl,
    this.sourceTitle,
    required this.difficulty,
    required this.source,
  });
}

class _CastleCard extends StatelessWidget {
  final _CastleData data;
  const _CastleCard({required this.data});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case '初級':
        return Colors.green.shade400;
      case '中級':
        return Colors.orange.shade400;
      case '上級':
        return Colors.red.shade400;
      default:
        return Colors.grey;
    }
  }

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  data.name,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getDifficultyColor(data.difficulty),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  data.difficulty,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
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
          const SizedBox(height: 12),
          if (data.sourceUrl != null)
            GestureDetector(
              onTap: () => _launchUrl(data.sourceUrl!),
              child: Text(
                '出典: ${data.sourceTitle ?? data.source}',
                style: TextStyle(
                  color: Colors.blue.shade300,
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                ),
              ),
            )
          else
            Text(
              '出典: ${data.source}',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}
