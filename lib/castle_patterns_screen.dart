// lib/castle_patterns_screen.dart — 囲いパターン説明

import 'package:flutter/material.dart';
import 'piece.dart';
import 'mini_board_widget.dart';
import 'utils/shogi_data_validator.dart';

class CastlePatternsScreen extends StatefulWidget {
  const CastlePatternsScreen({super.key});

  @override
  State<CastlePatternsScreen> createState() => _CastlePatternsScreenState();
}

class _CastlePatternsScreenState extends State<CastlePatternsScreen> {
  String? _selectedDifficulty;

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

  // ── 座標系: board[row][col], row=段-1, col=9-筋
  //   例) 8八 → row=7, col=1  /  3七 → row=6, col=6
  static List<List<Piece?>> _empty() =>
      List.generate(9, (_) => List<Piece?>.filled(9, null, growable: true));

  // 居玉（きょぎょく）— 玉が初期位置のまま
  static List<List<Piece?>> _kyogyoku() {
    final b = _empty();
    b[8][4] = const Piece(PieceType.king, true);   // 5九玉
    b[8][3] = const Piece(PieceType.gold, true);   // 6九金（初期位置）
    b[8][5] = const Piece(PieceType.gold, true);   // 4九金（初期位置）
    b[8][0] = const Piece(PieceType.lance, true);  // 9九香
    b[8][8] = const Piece(PieceType.lance, true);  // 1九香
    b[6][4] = const Piece(PieceType.pawn, true);   // 5七歩
    return b;
  }

  // 矢倉（やぐら）— 8八玉、7八金、7七銀、6七金
  static List<List<Piece?>> _yagura() {
    final b = _empty();
    b[7][1] = const Piece(PieceType.king, true);   // 8八玉
    b[7][2] = const Piece(PieceType.gold, true);   // 7八金
    b[6][2] = const Piece(PieceType.silver, true); // 7七銀
    b[6][3] = const Piece(PieceType.gold, true);   // 6七金
    b[8][0] = const Piece(PieceType.lance, true);  // 9九香
    b[7][4] = const Piece(PieceType.rook, true);   // 5八飛
    b[6][0] = const Piece(PieceType.pawn, true);   // 9七歩
    b[6][1] = const Piece(PieceType.pawn, true);   // 8七歩
    b[5][3] = const Piece(PieceType.pawn, true);   // 6六歩
    b[5][4] = const Piece(PieceType.pawn, true);   // 5六歩
    return b;
  }

  // 美濃囲い（みのがこい）— 2八玉、3八金、3七銀（振り飛車）
  static List<List<Piece?>> _mino() {
    final b = _empty();
    b[7][7] = const Piece(PieceType.king, true);   // 2八玉
    b[7][6] = const Piece(PieceType.gold, true);   // 3八金
    b[6][6] = const Piece(PieceType.silver, true); // 3七銀
    b[8][8] = const Piece(PieceType.lance, true);  // 1九香
    b[7][5] = const Piece(PieceType.rook, true);   // 4八飛（四間飛車）
    b[6][7] = const Piece(PieceType.pawn, true);   // 2七歩
    b[6][8] = const Piece(PieceType.pawn, true);   // 1七歩
    b[5][6] = const Piece(PieceType.pawn, true);   // 3六歩
    return b;
  }

  // 舟囲い（ふねがこい）— 5八玉、4八金、6八金
  static List<List<Piece?>> _funegakoi() {
    final b = _empty();
    b[7][4] = const Piece(PieceType.king, true);   // 5八玉
    b[7][5] = const Piece(PieceType.gold, true);   // 4八金
    b[7][3] = const Piece(PieceType.gold, true);   // 6八金
    b[6][2] = const Piece(PieceType.silver, true); // 7七銀
    b[6][3] = const Piece(PieceType.pawn, true);   // 6七歩
    b[6][4] = const Piece(PieceType.pawn, true);   // 5七歩
    b[6][5] = const Piece(PieceType.pawn, true);   // 4七歩
    return b;
  }

  // 金無双（きんむそう）— 8八玉、7八金、6八金、7七銀（相振り飛車の囲い）
  static List<List<Piece?>> _kinmusou() {
    final b = _empty();
    b[7][1] = const Piece(PieceType.king, true);   // 8八玉
    b[7][2] = const Piece(PieceType.gold, true);   // 7八金
    b[7][3] = const Piece(PieceType.gold, true);   // 6八金
    b[6][2] = const Piece(PieceType.silver, true); // 7七銀
    b[6][0] = const Piece(PieceType.pawn, true);   // 9七歩
    b[6][1] = const Piece(PieceType.pawn, true);   // 8七歩
    b[8][0] = const Piece(PieceType.lance, true);  // 9九香
    return b;
  }

  // 銀冠（ぎんかん）— 8八玉、7八金、6七金、8七銀（銀が玉の真上で冠の形）
  static List<List<Piece?>> _ginkan() {
    final b = _empty();
    b[7][1] = const Piece(PieceType.king, true);   // 8八玉
    b[7][2] = const Piece(PieceType.gold, true);   // 7八金
    b[6][3] = const Piece(PieceType.gold, true);   // 6七金
    b[6][1] = const Piece(PieceType.silver, true); // 8七銀（冠＝玉の真上）
    b[8][0] = const Piece(PieceType.lance, true);  // 9九香
    b[5][0] = const Piece(PieceType.pawn, true);   // 9六歩
    b[5][1] = const Piece(PieceType.pawn, true);   // 8六歩
    b[5][2] = const Piece(PieceType.pawn, true);   // 7六歩
    return b;
  }

  // 左美濃（ひだりみの）— 2八玉、3八金、2七銀（居飛車）
  static List<List<Piece?>> _hidarimino() {
    final b = _empty();
    b[7][7] = const Piece(PieceType.king, true);   // 2八玉
    b[7][6] = const Piece(PieceType.gold, true);   // 3八金
    b[6][7] = const Piece(PieceType.silver, true); // 2七銀
    b[7][8] = const Piece(PieceType.gold, true);   // 1八金
    b[8][8] = const Piece(PieceType.lance, true);  // 1九香
    b[6][6] = const Piece(PieceType.pawn, true);   // 3七歩
    b[6][8] = const Piece(PieceType.pawn, true);   // 1七歩
    return b;
  }

  // 雁木（がんぎ）— 6八玉、5八金、6七金、7七銀、5七銀
  static List<List<Piece?>> _gangi() {
    final b = _empty();
    b[7][3] = const Piece(PieceType.king, true);   // 6八玉
    b[7][4] = const Piece(PieceType.gold, true);   // 5八金
    b[6][3] = const Piece(PieceType.gold, true);   // 6七金
    b[6][2] = const Piece(PieceType.silver, true); // 7七銀
    b[6][4] = const Piece(PieceType.silver, true); // 5七銀
    b[5][5] = const Piece(PieceType.pawn, true);   // 4六歩
    b[5][6] = const Piece(PieceType.pawn, true);   // 3六歩
    b[6][1] = const Piece(PieceType.pawn, true);   // 8七歩
    return b;
  }

  // カニ囲い（かにがこい）— 5九玉、6九金、4九金、5八銀
  static List<List<Piece?>> _kanigakoi() {
    final b = _empty();
    b[8][4] = const Piece(PieceType.king, true);   // 5九玉
    b[8][3] = const Piece(PieceType.gold, true);   // 6九金
    b[8][5] = const Piece(PieceType.gold, true);   // 4九金
    b[7][4] = const Piece(PieceType.silver, true); // 5八銀
    b[6][3] = const Piece(PieceType.pawn, true);   // 6七歩
    b[6][4] = const Piece(PieceType.pawn, true);   // 5七歩
    b[6][5] = const Piece(PieceType.pawn, true);   // 4七歩
    return b;
  }

  // 高美濃（たかみの）— 美濃の左金が4七に上がった形
  static List<List<Piece?>> _takamiino() {
    final b = _empty();
    b[7][7] = const Piece(PieceType.king, true);   // 2八玉
    b[7][6] = const Piece(PieceType.gold, true);   // 3八金
    b[6][6] = const Piece(PieceType.silver, true); // 3七銀（美濃のまま）
    b[6][5] = const Piece(PieceType.gold, true);   // 4七金（高美濃の特徴）
    b[8][8] = const Piece(PieceType.lance, true);  // 1九香
    b[7][5] = const Piece(PieceType.rook, true);   // 4八飛（振り飛車）
    b[6][7] = const Piece(PieceType.pawn, true);   // 2七歩
    b[6][8] = const Piece(PieceType.pawn, true);   // 1七歩
    return b;
  }

  // 穴熊（あなぐま）— 9九玉、8九金、7九金、9八銀、8八銀
  static List<List<Piece?>> _anaguma() {
    final b = _empty();
    b[8][0] = const Piece(PieceType.king, true);   // 9九玉
    b[8][1] = const Piece(PieceType.gold, true);   // 8九金
    b[8][2] = const Piece(PieceType.gold, true);   // 7九金
    b[7][0] = const Piece(PieceType.silver, true); // 9八銀
    b[7][1] = const Piece(PieceType.silver, true); // 8八銀（二枚銀が穴熊の特徴）
    b[6][0] = const Piece(PieceType.pawn, true);   // 9七歩
    b[6][1] = const Piece(PieceType.pawn, true);   // 8七歩
    b[6][2] = const Piece(PieceType.pawn, true);   // 7七歩
    return b;
  }

  // 矢倉角換わり — 矢倉形から角を交換した局面
  static List<List<Piece?>> _yaguraKakuKawari() {
    final b = _empty();
    b[7][1] = const Piece(PieceType.king, true);   // 8八玉
    b[7][2] = const Piece(PieceType.gold, true);   // 7八金
    b[6][2] = const Piece(PieceType.silver, true); // 7七銀
    b[6][3] = const Piece(PieceType.gold, true);   // 6七金
    b[8][0] = const Piece(PieceType.lance, true);  // 9九香
    b[7][4] = const Piece(PieceType.rook, true);   // 5八飛
    b[6][0] = const Piece(PieceType.pawn, true);   // 9七歩
    b[6][1] = const Piece(PieceType.pawn, true);   // 8七歩
    b[5][3] = const Piece(PieceType.pawn, true);   // 6六歩
    // 角なし（交換済み）
    return b;
  }

  // ビッグ4 — 9九玉＋金2枚・銀2枚で固める四枚穴熊の最強形
  static List<List<Piece?>> _bigFour() {
    final b = _empty();
    b[8][0] = const Piece(PieceType.king, true);   // 9九玉
    b[8][1] = const Piece(PieceType.gold, true);   // 8九金
    b[8][2] = const Piece(PieceType.gold, true);   // 7九金
    b[7][1] = const Piece(PieceType.silver, true); // 8八銀
    b[7][2] = const Piece(PieceType.silver, true); // 7八銀
    b[6][0] = const Piece(PieceType.pawn, true);   // 9七歩
    b[6][1] = const Piece(PieceType.pawn, true);   // 8七歩
    b[6][2] = const Piece(PieceType.pawn, true);   // 7七歩
    return b;
  }

  // 中住まい（なかずまい）— 玉を中央5八に置き、左右の金銀で守る
  static List<List<Piece?>> _nakazumai() {
    final b = _empty();
    b[7][4] = const Piece(PieceType.king, true);   // 5八玉
    b[7][3] = const Piece(PieceType.gold, true);   // 6八金
    b[7][5] = const Piece(PieceType.gold, true);   // 4八金
    b[7][2] = const Piece(PieceType.silver, true); // 7八銀
    b[7][6] = const Piece(PieceType.silver, true); // 3八銀
    b[6][3] = const Piece(PieceType.pawn, true);   // 6七歩
    b[6][4] = const Piece(PieceType.pawn, true);   // 5七歩
    b[6][5] = const Piece(PieceType.pawn, true);   // 4七歩
    return b;
  }

  // 木村美濃（きむらみの）— 美濃の右銀を4七へ上がった発展形
  static List<List<Piece?>> _kimuraMino() {
    final b = _empty();
    b[7][7] = const Piece(PieceType.king, true);   // 2八玉
    b[7][6] = const Piece(PieceType.gold, true);   // 3八金
    b[7][4] = const Piece(PieceType.gold, true);   // 5八金
    b[6][5] = const Piece(PieceType.silver, true); // 4七銀（木村美濃の特徴）
    b[8][8] = const Piece(PieceType.lance, true);  // 1九香
    b[5][5] = const Piece(PieceType.pawn, true);   // 4六歩
    b[6][7] = const Piece(PieceType.pawn, true);   // 2七歩
    b[6][8] = const Piece(PieceType.pawn, true);   // 1七歩
    return b;
  }

  // 居飛車穴熊（いびしゃあなぐま）— 居飛車側が9九へ玉を潜らせる対振り最堅陣
  static List<List<Piece?>> _ibishaAnaguma() {
    final b = _empty();
    b[8][0] = const Piece(PieceType.king, true);   // 9九玉
    b[7][0] = const Piece(PieceType.lance, true);  // 9八香
    b[7][1] = const Piece(PieceType.silver, true); // 8八銀
    b[7][2] = const Piece(PieceType.gold, true);   // 7八金
    b[7][3] = const Piece(PieceType.gold, true);   // 6八金
    b[8][1] = const Piece(PieceType.knight, true); // 8九桂
    b[6][0] = const Piece(PieceType.pawn, true);   // 9七歩
    b[6][1] = const Piece(PieceType.pawn, true);   // 8七歩
    b[6][2] = const Piece(PieceType.pawn, true);   // 7七歩
    return b;
  }

  @override
  Widget build(BuildContext context) {
    final allCastles = [
      // 初級
      _CastleData(
        name: '居玉（きょぎょく）',
        description: '玉が初期位置のまま動かない形。手数をかけずに対局できるが守りが薄い。囲いの比較学習に最適。',
        board: _kyogyoku(),
        highlights: const {(8, 4)},
        difficulty: '初級',
      ),
      _CastleData(
        name: '矢倉（やぐら）',
        description: '8八玉・7八金・7七銀・6七金で組む居飛車の代表的な囲い。上部が厚く、縦の攻めに強い。',
        board: _yagura(),
        highlights: const {(7, 1), (7, 2), (6, 2), (6, 3)},
        difficulty: '初級',
      ),
      _CastleData(
        name: '美濃囲い（みのがこい）',
        description: '2八玉・3八金・3七銀の3枚で組む振り飛車の定番囲い。少ない手数で完成し、横からの攻めに強い。',
        board: _mino(),
        highlights: const {(7, 7), (7, 6), (6, 6)},
        difficulty: '初級',
      ),
      _CastleData(
        name: '舟囲い（ふねがこい）',
        description: '5八玉・4八金・6八金の最短形。急戦にすぐ対応でき、玉を最低限安全にする実戦的な構え。',
        board: _funegakoi(),
        highlights: const {(7, 4), (7, 5), (7, 3)},
        difficulty: '初級',
      ),
      // 中級
      _CastleData(
        name: '金無双（きんむそう）',
        description: '8八玉・7八金・6八金・7七銀でまとめる囲い。相振り飛車でよく使われ、素早く組めるが横からの攻めに注意。',
        board: _kinmusou(),
        highlights: const {(7, 1), (7, 2), (7, 3), (6, 2)},
        difficulty: '中級',
      ),
      _CastleData(
        name: '銀冠（ぎんかん）',
        description: '8八玉・7八金・6七金・8七銀の形。銀を玉の真上（8七）に冠のように乗せ、上部の攻めに手厚い囲い。',
        board: _ginkan(),
        highlights: const {(7, 1), (7, 2), (6, 1), (6, 3)},
        difficulty: '中級',
      ),
      _CastleData(
        name: '左美濃（ひだりみの）',
        description: '居飛車側が2八玉・3八金・2七銀と組む形。美濃を左右反転させた構造で対抗形（居飛車vs振り飛車）で多用。',
        board: _hidarimino(),
        highlights: const {(7, 7), (7, 6), (6, 7), (7, 8)},
        difficulty: '中級',
      ),
      _CastleData(
        name: '雁木（がんぎ）',
        description: '6七金・7七銀・5七銀の2銀2金を高く構える形。攻守のバランスが良く対矢倉・対居飛車で有力。',
        board: _gangi(),
        highlights: const {(7, 3), (7, 4), (6, 3), (6, 2), (6, 4)},
        difficulty: '中級',
      ),
      _CastleData(
        name: 'カニ囲い（かにがこい）',
        description: '5九玉・6九金・4九金・5八銀の形。カニのハサミのような見た目。急戦志向で素早く攻撃に転じられる。',
        board: _kanigakoi(),
        highlights: const {(8, 4), (8, 3), (8, 5), (7, 4)},
        difficulty: '中級',
      ),
      _CastleData(
        name: '高美濃（たかみの）',
        description: '美濃囲いの左金を4七へ上がった発展形。玉頭が厚くなり美濃より上部に強い。振り飛車の定番進化形。',
        board: _takamiino(),
        highlights: const {(7, 7), (7, 6), (6, 6), (6, 5)},
        difficulty: '中級',
      ),
      // 上級
      _CastleData(
        name: '穴熊（あなぐま）',
        description: '9九玉・8九金・7九金・9八銀・8八銀の形。玉を隅深く潜らせる最強クラスの囲い。組むのに手数がかかる。',
        board: _anaguma(),
        highlights: const {(8, 0), (8, 1), (8, 2), (7, 0), (7, 1)},
        difficulty: '上級',
      ),
      _CastleData(
        name: '矢倉角換わり',
        description: '矢倉形を維持しつつ角を交換した局面。高度な読みが必要で、角打ちの隙を常に意識する必要がある。',
        board: _yaguraKakuKawari(),
        highlights: const {(7, 1), (7, 2), (6, 2), (6, 3)},
        difficulty: '上級',
      ),
      _CastleData(
        name: 'ビッグ4（びっぐふぉー）',
        description: '9九玉・8九金・7九金・8八銀・7八銀の四枚穴熊。金銀4枚で玉を完全に囲う最強クラスの堅陣。組むのに手数がかかる。',
        board: _bigFour(),
        highlights: const {(8, 0), (8, 1), (8, 2), (7, 1), (7, 2)},
        difficulty: '上級',
      ),
      _CastleData(
        name: '中住まい（なかずまい）',
        description: '5八玉・6八金・4八金・7八銀・3八銀。玉を中央に置き左右の金銀で守る形。横からの攻めに強く、相居飛車の急戦で使われます。',
        board: _nakazumai(),
        highlights: const {(7, 4), (7, 3), (7, 5), (7, 2), (7, 6)},
        difficulty: '中級',
      ),
      _CastleData(
        name: '木村美濃（きむらみの）',
        description: '2八玉・3八金・5八金・4七銀。美濃の右銀を4七へ上がり、玉頭の守りと反撃力を高めた発展形。振り飛車で多用されます。',
        board: _kimuraMino(),
        highlights: const {(7, 7), (7, 6), (7, 4), (6, 5)},
        difficulty: '中級',
      ),
      _CastleData(
        name: '居飛車穴熊（いびしゃあなぐま）',
        description: '9九玉・9八香・8八銀・7八金・6八金。居飛車側が玉を隅へ潜らせる対振り飛車の最堅陣。遠さと固さで終盤に絶大な威力を発揮します。',
        board: _ibishaAnaguma(),
        highlights: const {(8, 0), (7, 1), (7, 2), (7, 3)},
        difficulty: '上級',
      ),
    ];

    final filtered = _selectedDifficulty == null
        ? allCastles
        : allCastles.where((c) => c.difficulty == _selectedDifficulty).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('囲いパターン', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
          if (_selectedDifficulty != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text('絞込: ', style: TextStyle(color: Colors.amber.shade400, fontSize: 12)),
                  Chip(
                    label: Text(_selectedDifficulty!),
                    backgroundColor: Colors.amber.shade600,
                    labelStyle: const TextStyle(color: Colors.black, fontSize: 11),
                  ),
                ],
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('マッチする囲いがありません',
                        style: TextStyle(color: Colors.white.withAlpha(150))))
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => _CastleCard(data: filtered[i]),
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
  final String difficulty;

  const _CastleData({
    required this.name,
    required this.description,
    required this.board,
    required this.highlights,
    required this.difficulty,
  });
}

class _CastleCard extends StatelessWidget {
  final _CastleData data;
  const _CastleCard({required this.data});

  Color _difficultyColor() {
    switch (data.difficulty) {
      case '初級': return Colors.green.shade400;
      case '中級': return Colors.orange.shade400;
      case '上級': return Colors.red.shade400;
      default:    return Colors.grey;
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
          BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 6, offset: const Offset(0, 3)),
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
                  color: _difficultyColor(),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  data.difficulty,
                  style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            data.description,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
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
