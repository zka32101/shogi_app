// lib/next_move_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'piece.dart';
import 'mini_board_widget.dart';

class NextMoveScreen extends StatefulWidget {
  const NextMoveScreen({Key? key}) : super(key: key);

  @override
  State<NextMoveScreen> createState() => _NextMoveScreenState();
}

class _NMProb {
  final String title;
  final String difficulty;
  final String description;
  final List<List<Piece?>> board;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const _NMProb({
    required this.title,
    required this.difficulty,
    required this.description,
    required this.board,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

List<List<Piece?>> _empty() {
  return List.generate(9, (_) => List.filled(9, null));
}

List<List<Piece?>> _prob1Board() {
  final b = _empty();
  b[8][4] = Piece(PieceType.king, true);
  b[8][7] = Piece(PieceType.rook, true);
  b[7][1] = Piece(PieceType.bishop, true);
  b[8][6] = Piece(PieceType.gold, true);
  b[8][3] = Piece(PieceType.gold, true);
  b[8][5] = Piece(PieceType.silver, true);
  b[8][2] = Piece(PieceType.silver, true);
  b[6][0] = Piece(PieceType.pawn, true);
  b[6][1] = Piece(PieceType.pawn, true);
  b[6][2] = Piece(PieceType.pawn, true);
  b[6][3] = Piece(PieceType.pawn, true);
  b[6][5] = Piece(PieceType.pawn, true);
  b[6][6] = Piece(PieceType.pawn, true);
  b[6][7] = Piece(PieceType.pawn, true);
  b[6][8] = Piece(PieceType.pawn, true);
  b[0][4] = Piece(PieceType.king, false);
  b[1][7] = Piece(PieceType.rook, false);
  b[2][7] = Piece(PieceType.bishop, false);
  return b;
}

List<List<Piece?>> _prob2Board() {
  final b = _empty();
  b[8][4] = Piece(PieceType.king, true);
  b[8][7] = Piece(PieceType.rook, true);
  b[7][1] = Piece(PieceType.bishop, true);
  b[8][6] = Piece(PieceType.gold, true);
  b[8][3] = Piece(PieceType.gold, true);
  b[6][7] = Piece(PieceType.pawn, true);
  b[6][2] = Piece(PieceType.pawn, true);
  b[6][3] = Piece(PieceType.pawn, true);
  b[0][4] = Piece(PieceType.king, false);
  b[1][1] = Piece(PieceType.rook, false);
  b[2][7] = Piece(PieceType.bishop, false);
  b[3][7] = Piece(PieceType.pawn, false);
  return b;
}

List<List<Piece?>> _prob3Board() {
  final b = _empty();
  b[8][4] = Piece(PieceType.king, true);
  b[8][7] = Piece(PieceType.rook, true);
  b[7][1] = Piece(PieceType.bishop, true);
  b[8][5] = Piece(PieceType.gold, true);
  b[8][3] = Piece(PieceType.gold, true);
  b[8][6] = Piece(PieceType.silver, true);
  b[8][2] = Piece(PieceType.silver, true);
  b[0][4] = Piece(PieceType.king, false);
  b[1][7] = Piece(PieceType.rook, false);
  b[2][1] = Piece(PieceType.bishop, false);
  return b;
}

List<List<Piece?>> _prob4Board() {
  final b = _empty();
  b[8][4] = Piece(PieceType.king, true);
  b[8][2] = Piece(PieceType.rook, true);
  b[8][5] = Piece(PieceType.gold, true);
  b[8][3] = Piece(PieceType.gold, true);
  b[8][6] = Piece(PieceType.silver, true);
  b[6][2] = Piece(PieceType.pawn, true);
  b[6][4] = Piece(PieceType.pawn, true);
  b[0][4] = Piece(PieceType.king, false);
  b[1][6] = Piece(PieceType.rook, false);
  b[3][2] = Piece(PieceType.pawn, false);
  return b;
}

List<List<Piece?>> _prob5Board() {
  final b = _empty();
  b[8][4] = Piece(PieceType.king, true);
  b[8][7] = Piece(PieceType.rook, true);
  b[7][1] = Piece(PieceType.bishop, true);
  b[8][6] = Piece(PieceType.gold, true);
  b[8][3] = Piece(PieceType.gold, true);
  b[7][7] = Piece(PieceType.silver, true);
  b[6][8] = Piece(PieceType.pawn, true);
  b[0][4] = Piece(PieceType.king, false);
  b[1][6] = Piece(PieceType.rook, false);
  b[2][7] = Piece(PieceType.silver, false);
  b[3][7] = Piece(PieceType.pawn, false);
  return b;
}

List<List<Piece?>> _prob6Board() {
  final b = _empty();
  b[8][4] = Piece(PieceType.king, true);
  b[8][7] = Piece(PieceType.rook, true);
  b[5][3] = Piece(PieceType.pawn, true);
  b[8][5] = Piece(PieceType.gold, true);
  b[8][3] = Piece(PieceType.gold, true);
  b[7][3] = Piece(PieceType.silver, true);
  b[0][3] = Piece(PieceType.king, false);
  b[1][6] = Piece(PieceType.rook, false);
  b[3][3] = Piece(PieceType.gold, false);
  b[4][3] = Piece(PieceType.pawn, false);
  return b;
}

List<List<Piece?>> _prob7Board() {
  final b = _empty();
  b[8][4] = Piece(PieceType.king, true);
  b[8][7] = Piece(PieceType.rook, true);
  b[8][2] = Piece(PieceType.knight, true);
  b[6][2] = Piece(PieceType.pawn, true);
  b[8][5] = Piece(PieceType.gold, true);
  b[8][3] = Piece(PieceType.gold, true);
  b[0][4] = Piece(PieceType.king, false);
  b[2][3] = Piece(PieceType.silver, false);
  b[3][2] = Piece(PieceType.pawn, false);
  return b;
}

List<List<Piece?>> _prob8Board() {
  final b = _empty();
  b[8][4] = Piece(PieceType.king, true);
  b[5][7] = Piece(PieceType.rook, true);
  b[7][1] = Piece(PieceType.bishop, true);
  b[8][5] = Piece(PieceType.gold, true);
  b[8][3] = Piece(PieceType.gold, true);
  b[0][3] = Piece(PieceType.king, false);
  b[1][6] = Piece(PieceType.rook, false);
  b[3][7] = Piece(PieceType.pawn, false);
  b[2][5] = Piece(PieceType.silver, false);
  return b;
}

List<List<Piece?>> _prob9Board() {
  final b = _empty();
  b[8][4] = Piece(PieceType.king, true);
  b[8][7] = Piece(PieceType.rook, true);
  b[8][5] = Piece(PieceType.gold, true);
  b[8][3] = Piece(PieceType.gold, true);
  b[6][6] = Piece(PieceType.pawn, true);
  b[0][3] = Piece(PieceType.king, false);
  b[2][6] = Piece(PieceType.rook, false);
  b[2][3] = Piece(PieceType.gold, false);
  b[3][5] = Piece(PieceType.pawn, false);
  return b;
}

List<List<Piece?>> _prob10Board() {
  final b = _empty();
  b[8][4] = Piece(PieceType.king, true);
  b[8][7] = Piece(PieceType.rook, true);
  b[6][5] = Piece(PieceType.silver, true);
  b[8][3] = Piece(PieceType.gold, true);
  b[8][5] = Piece(PieceType.gold, true);
  b[0][3] = Piece(PieceType.king, false);
  b[1][7] = Piece(PieceType.rook, false);
  b[3][5] = Piece(PieceType.pawn, false);
  b[3][4] = Piece(PieceType.silver, false);
  return b;
}

List<List<Piece?>> _prob11Board() {
  final b = _empty();
  b[8][8] = Piece(PieceType.king, false);
  b[6][7] = Piece(PieceType.gold, true);
  b[7][6] = Piece(PieceType.rook, true);
  b[5][8] = Piece(PieceType.silver, true);
  b[3][5] = Piece(PieceType.king, true);
  b[7][8] = Piece(PieceType.gold, false);
  return b;
}

List<List<Piece?>> _prob12Board() {
  final b = _empty();
  b[0][8] = Piece(PieceType.king, false);
  b[1][7] = Piece(PieceType.gold, false);
  b[2][6] = Piece(PieceType.rook, true);
  b[1][8] = Piece(PieceType.silver, true);
  b[5][4] = Piece(PieceType.king, true);
  return b;
}

List<List<Piece?>> _prob13Board() {
  final b = _empty();
  b[0][4] = Piece(PieceType.king, false);
  b[0][5] = Piece(PieceType.gold, false);
  b[0][3] = Piece(PieceType.gold, false);
  b[1][4] = Piece(PieceType.silver, false);
  b[2][7] = Piece(PieceType.rook, true);
  b[5][4] = Piece(PieceType.king, true);
  b[3][6] = Piece(PieceType.gold, true);
  return b;
}

List<List<Piece?>> _prob14Board() {
  final b = _empty();
  b[0][8] = Piece(PieceType.king, false);
  b[1][8] = Piece(PieceType.gold, false);
  b[1][7] = Piece(PieceType.silver, false);
  b[2][7] = Piece(PieceType.rook, true);
  b[1][6] = Piece(PieceType.gold, true);
  b[5][4] = Piece(PieceType.king, true);
  b[3][8] = Piece(PieceType.lance, true);
  return b;
}

List<List<Piece?>> _prob15Board() {
  final b = _empty();
  b[0][4] = Piece(PieceType.king, false);
  b[0][3] = Piece(PieceType.gold, false);
  b[0][5] = Piece(PieceType.gold, false);
  b[1][4] = Piece(PieceType.silver, false);
  b[1][3] = Piece(PieceType.pawn, false);
  b[1][5] = Piece(PieceType.pawn, false);
  b[4][7] = Piece(PieceType.bishop, true);
  b[5][4] = Piece(PieceType.king, true);
  b[3][6] = Piece(PieceType.rook, true);
  return b;
}

final List<_NMProb> _problems = [
  _NMProb(
    title: '角道を開ける',
    difficulty: '初級',
    description: '先手番。序盤の定跡として、角道を開けるために最善の一手を選んでください。',
    board: _prob1Board(),
    options: ['▲8六歩', '▲7六歩', '▲9六歩', '▲5六歩'],
    correctIndex: 1,
    explanation: '▲7六歩が正解。角道を開ける最も基本的な初手です。角が8八から使えるようになります。',
  ),
  _NMProb(
    title: '飛車先の歩を突く',
    difficulty: '初級',
    description: '先手番。居飛車戦法で飛車先を伸ばし、将来の攻めの形を作りましょう。',
    board: _prob2Board(),
    options: ['▲2六歩', '▲3六歩', '▲1六歩', '▲4六歩'],
    correctIndex: 0,
    explanation: '▲2六歩が正解。飛車先（2筋）の歩を突いて、飛車の働きを活発にします。',
  ),
  _NMProb(
    title: '玉の囲い方向',
    difficulty: '初級',
    description: '先手番。居飛車で玉を安全に囲うため、まず玉をどちらに動かすべきですか？',
    board: _prob3Board(),
    options: ['▲6八玉', '▲5九玉', '▲4八玉', '▲6九玉'],
    correctIndex: 2,
    explanation: '▲4八玉が正解。居飛車の場合、玉は左側（4八→3八→2八）に囲うのが基本です。',
  ),
  _NMProb(
    title: '中飛車への振り方',
    difficulty: '初級',
    description: '先手番（振り飛車）。中飛車の形を作るため、飛車をどこに振りますか？',
    board: _prob4Board(),
    options: ['▲5八飛', '▲3八飛', '▲4八飛', '▲6八飛'],
    correctIndex: 0,
    explanation: '▲5八飛が正解。中飛車は5筋に飛車を置き、中央から攻める戦法です。',
  ),
  _NMProb(
    title: '棒銀の進出',
    difficulty: '初級',
    description: '先手番。棒銀戦法で銀を前進させ、後手の飛車先を攻めるための一手は？',
    board: _prob5Board(),
    options: ['▲2六銀', '▲3七銀', '▲2八銀', '▲1六歩'],
    correctIndex: 0,
    explanation: '▲2六銀が正解。棒銀は銀を2六まで進出させ、後手の守りを突破する戦法です。',
  ),
  _NMProb(
    title: '歩の垂れ',
    difficulty: '中級',
    description: '先手番。相手の守りに歩を「垂れ」て、後で成り込む手筋を使いましょう。',
    board: _prob6Board(),
    options: ['▲6四歩', '▲6五歩', '▲5五歩', '▲7五歩'],
    correctIndex: 0,
    explanation: '▲6四歩が正解。敵陣に歩を垂らして、次に▲6三歩成りを狙う手筋です。',
  ),
  _NMProb(
    title: '桂馬の活用',
    difficulty: '中級',
    description: '先手番。桂馬を活用して後手の銀に圧力をかける最善手を選んでください。',
    board: _prob7Board(),
    options: ['▲7五桂', '▲6四桂', '▲8五桂', '▲5五桂'],
    correctIndex: 0,
    explanation: '▲7五桂が正解。桂は「二段跳び」で相手の守り駒に当たる位置に跳ねるのが基本です。',
  ),
  _NMProb(
    title: '飛車の活用',
    difficulty: '中級',
    description: '先手番。浮き飛車の形から相手の歩に当てるための最善手は何ですか？',
    board: _prob8Board(),
    options: ['▲2四飛', '▲2二飛成', '▲5五飛', '▲2八飛'],
    correctIndex: 0,
    explanation: '▲2四飛が正解。相手の歩に飛車を当てて取り込み、飛車先を突破する手筋です。',
  ),
  _NMProb(
    title: '角の打ち込み',
    difficulty: '中級',
    description: '先手番（角を持ち駒として持っています）。角を打って飛車・金取りの両取りを狙う手は？',
    board: _prob9Board(),
    options: ['▲4五角', '▲3三角', '▲7七角', '▲2二角'],
    correctIndex: 0,
    explanation: '▲4五角が正解。角を打ち込んで後手の飛車と金に「両取り」をかける手筋です。',
  ),
  _NMProb(
    title: '銀の攻め方',
    difficulty: '中級',
    description: '先手番。銀を使って後手の守りに迫る最善手を選んでください。',
    board: _prob10Board(),
    options: ['▲4六銀', '▲5六銀', '▲3六銀', '▲4八銀'],
    correctIndex: 0,
    explanation: '▲4六銀が正解。銀を斜め前に進めて、後手の銀に当てながら攻勢を強める手です。',
  ),
  _NMProb(
    title: '詰めろをかける',
    difficulty: '上級',
    description: '先手番。後手玉に「詰めろ」（次に詰める形）をかける最善手を選んでください。',
    board: _prob11Board(),
    options: ['▲1六金', '▲2八金', '▲1七金', '▲3七飛'],
    correctIndex: 2,
    explanation: '▲1七金が正解。玉の逃げ道を塞ぎながら詰めろをかける手です。後手は受けが難しくなります。',
  ),
  _NMProb(
    title: '一手詰め',
    difficulty: '上級',
    description: '先手番。後手玉を「一手詰め」にする手を選んでください。',
    board: _prob12Board(),
    options: ['▲1八金', '▲2八飛', '▲1九銀成', '▲1八飛'],
    correctIndex: 0,
    explanation: '▲1八金が正解。後手玉は1九に追い詰められており、1八に金を打てば詰みです。',
  ),
  _NMProb(
    title: '飛車の成り込み',
    difficulty: '上級',
    description: '先手番。飛車を敵陣に成り込んで後手玉に迫る最善手を選んでください。',
    board: _prob13Board(),
    options: ['▲2一飛成', '▲2二飛成', '▲5二飛成', '▲2四飛'],
    correctIndex: 1,
    explanation: '▲2二飛成が正解。飛車を成り込んで竜を作り、後手玉の近くに強力な駒を配置します。',
  ),
  _NMProb(
    title: '必死の形',
    difficulty: '上級',
    description: '先手番。後手玉に「必死」（どうやっても詰みを逃れられない）をかける手は？',
    board: _prob14Board(),
    options: ['▲1九香', '▲2九飛', '▲1八金打', '▲2八飛'],
    correctIndex: 2,
    explanation: '▲1八金打が正解。玉の逃げ道を金で全て封じる「必死」の手です。後手は受ける手がありません。',
  ),
  _NMProb(
    title: '角で決める',
    difficulty: '上級',
    description: '先手番。角を使って後手玉に王手をかけ、かつ強力な竜を作る最善手は？',
    board: _prob15Board(),
    options: ['▲7三角成', '▲5二角成', '▲6三角成', '▲3二角成'],
    correctIndex: 1,
    explanation: '▲5二角成が正解。角が5二に成ることで後手玉に王手がかかり、竜として強力な攻め駒になります。',
  ),
];

class _NextMoveScreenState extends State<NextMoveScreen> {
  int _current = 0;
  int? _selectedIdx;
  late List<bool> _cleared;
  int _score = 0;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _cleared = List.filled(_problems.length, false);
    _loadCleared();
  }

  Future<void> _loadCleared() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (int i = 0; i < _problems.length; i++) {
        _cleared[i] = prefs.getBool('next_move_cleared_$i') ?? false;
      }
    });
  }

  Future<void> _saveCleared(int idx) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('next_move_cleared_$idx', true);
  }

  void _selectOption(int idx) {
    if (_selectedIdx != null) return;
    final prob = _problems[_current];
    setState(() {
      _selectedIdx = idx;
      if (idx == prob.correctIndex) {
        _score++;
        _cleared[_current] = true;
        _saveCleared(_current);
      }
    });
  }

  void _nextProblem() {
    if (_current < _problems.length - 1) {
      setState(() {
        _current++;
        _selectedIdx = null;
      });
    } else {
      setState(() {
        _showResult = true;
      });
    }
  }

  void _restart() {
    setState(() {
      _current = 0;
      _selectedIdx = null;
      _score = 0;
      _showResult = false;
    });
  }

  Color _difficultyColor(String diff) {
    switch (diff) {
      case '初級':
        return Colors.green;
      case '中級':
        return Colors.amber;
      case '上級':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildResultScreen() {
    final pct = (_score / _problems.length * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF0F3460), width: 2),
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Text(
                    '結果',
                    style: TextStyle(
                      color: Color(0xDEFFFFFF),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '$_score / ${_problems.length}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '正解率 $pct%',
                    style: const TextStyle(
                      color: Color(0xDEFFFFFF),
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    pct >= 80
                        ? '素晴らしい！'
                        : pct >= 60
                            ? 'よく頑張りました！'
                            : 'もっと練習しましょう！',
                    style: TextStyle(
                      color: pct >= 80
                          ? Colors.green
                          : pct >= 60
                              ? Colors.amber
                              : Colors.red,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _restart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3460),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'もう一度',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProblemScreen() {
    final prob = _problems[_current];
    final answered = _selectedIdx != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '問 ${_current + 1} / ${_problems.length}',
                      style: const TextStyle(
                        color: Color(0xDEFFFFFF),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '正解: $_score',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _current / _problems.length,
                    backgroundColor: const Color(0xFF0F3460),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.amber),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0F3460), width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        prob.title,
                        style: const TextStyle(
                          color: Color(0xDEFFFFFF),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _difficultyColor(prob.difficulty)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _difficultyColor(prob.difficulty),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        prob.difficulty,
                        style: TextStyle(
                          color: _difficultyColor(prob.difficulty),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  prob.description,
                  style: const TextStyle(
                    color: Color(0xDEFFFFFF),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: MiniBoardWidget(
                    board: prob.board,
                    showLabels: true,
                    size: 280,
                  ),
                ),
                const SizedBox(height: 20),
                Column(
                  children: List.generate(prob.options.length, (i) {
                    Color btnColor = const Color(0xFF0F3460);
                    Color textColor = const Color(0xDEFFFFFF);
                    IconData? icon;

                    if (answered) {
                      if (i == prob.correctIndex) {
                        btnColor = Colors.green.shade800;
                        textColor = Colors.white;
                        icon = Icons.check_circle_outline;
                      } else if (i == _selectedIdx) {
                        btnColor = Colors.red.shade800;
                        textColor = Colors.white;
                        icon = Icons.cancel_outlined;
                      } else {
                        btnColor = const Color(0xFF0A2744);
                        textColor = Colors.grey;
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: answered ? null : () => _selectOption(i),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: btnColor,
                            foregroundColor: textColor,
                            disabledBackgroundColor: btnColor,
                            disabledForegroundColor: textColor,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.centerLeft,
                          ),
                          child: Row(
                            children: [
                              if (icon != null) ...[
                                Icon(icon, size: 20, color: textColor),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  '${String.fromCharCode(65 + i)}. ${prob.options[i]}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textColor,
                                    fontWeight:
                                        i == prob.correctIndex && answered
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                if (answered) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1628),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedIdx == prob.correctIndex
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _selectedIdx == prob.correctIndex
                                  ? Icons.lightbulb_outline
                                  : Icons.info_outline,
                              color: _selectedIdx == prob.correctIndex
                                  ? Colors.green
                                  : Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _selectedIdx == prob.correctIndex
                                  ? '正解！'
                                  : '不正解',
                              style: TextStyle(
                                color: _selectedIdx == prob.correctIndex
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          prob.explanation,
                          style: const TextStyle(
                            color: Color(0xDEFFFFFF),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextProblem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _current < _problems.length - 1
                            ? '次の問題　→'
                            : '結果を見る　→',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        title: const Text(
          '次の一手',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _showResult ? _buildResultScreen() : _buildProblemScreen(),
    );
  }
}