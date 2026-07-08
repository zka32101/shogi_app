// lib/tesuji_screen.dart — 手筋トレーニング画面
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'piece.dart';
import 'mini_board_widget.dart';
import 'tesuji_problems.dart';
import 'theme/app_theme.dart';

typedef _TesujiProb = TesujiProb;

final List<TesujiProb> _problems = buildTesujiProblems();

const List<String> _categories = ['全て', '飛車取り', '王手金取り', '両取り', '守り', '詰め', '捨て駒', '手筋テクニック'];

// ===== メイン画面 =====
class TesujiScreen extends StatefulWidget {
  const TesujiScreen({super.key});

  @override
  State<TesujiScreen> createState() => _TesujiScreenState();
}

class _TesujiScreenState extends State<TesujiScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Set<String> _cleared = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _loadCleared();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCleared() async {
    final prefs = await SharedPreferences.getInstance();
    final cleared = <String>{};
    for (final p in _problems) {
      if (prefs.getBool('tesuji_cleared_${p.id}') == true) {
        cleared.add(p.id);
      }
    }
    setState(() => _cleared = cleared);
  }

  Future<void> _markCleared(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tesuji_cleared_$id', true);
    setState(() => _cleared = {..._cleared, id});
  }

  List<_TesujiProb> _filtered(String category) => category == '全て'
      ? _problems
      : _problems.where((p) => p.category == category).toList();

  @override
  Widget build(BuildContext context) {
    final clearedCount = _cleared.length;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('手筋トレーニング',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          tabs: _categories
              .map((c) => Tab(text: c))
              .toList(),
        ),
      ),
      body: Column(children: [
        // 進捗バー
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('進捗: $clearedCount / ${_problems.length} 問',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text('${(clearedCount / _problems.length * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: clearedCount / _problems.length,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                minHeight: 6,
              ),
            ),
          ]),
        ),
        // タブコンテンツ
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _categories.map((cat) {
              final probs = _filtered(cat);
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: probs.length,
                itemBuilder: (context, index) {
                  final prob = probs[index];
                  final isCleared = _cleared.contains(prob.id);
                  return _ProblemCard(
                    prob: prob,
                    isCleared: isCleared,
                    onTap: () async {
                      final solved = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _TesujiDetailScreen(prob: prob, isCleared: isCleared),
                        ),
                      );
                      if (solved == true) {
                        await _markCleared(prob.id);
                      }
                    },
                  );
                },
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

// ===== 問題カード =====
class _ProblemCard extends StatelessWidget {
  final _TesujiProb prob;
  final bool isCleared;
  final VoidCallback onTap;
  const _ProblemCard({required this.prob, required this.isCleared, required this.onTap});

  Color get _categoryColor {
    switch (prob.category) {
      case '飛車取り':    return Colors.blue.shade400;
      case '王手金取り':  return Colors.red.shade400;
      case '両取り':      return Colors.purple.shade300;
      case '守り':        return Colors.green.shade400;
      case '詰め':        return Colors.orange.shade400;
      default:            return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCleared ? Colors.green.withAlpha(100) : Colors.white12,
            width: isCleared ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          // クリア状態
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCleared ? Colors.green.withAlpha(40) : Colors.white12,
            ),
            child: Center(
              child: isCleared
                  ? const Icon(Icons.check, color: Colors.green, size: 20)
                  : Text(
                      _problems.indexWhere((p) => p.id == prob.id).toString().padLeft(2, '0'),
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // タイトルとカテゴリ
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(prob.title,
                  style: TextStyle(
                    color: isCleared ? Colors.white70 : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _categoryColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _categoryColor.withAlpha(120), width: 0.8),
                ),
                child: Text(prob.category,
                    style: TextStyle(color: _categoryColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
        ]),
      ),
    );
  }
}

// ===== 問題詳細画面 =====
class _TesujiDetailScreen extends StatefulWidget {
  final _TesujiProb prob;
  final bool isCleared;
  const _TesujiDetailScreen({required this.prob, required this.isCleared});

  @override
  State<_TesujiDetailScreen> createState() => _TesujiDetailScreenState();
}

class _TesujiDetailScreenState extends State<_TesujiDetailScreen> {
  (int, int)? _selectedFrom;
  Set<(int, int)> _moveDots = {};
  bool? _result; // null=未回答, true=正解, false=不正解
  (int, int)? _lastFrom;
  (int, int)? _lastTo;
  PieceType? _selectedDropType; // 選択中の持ち駒（打ち）

  // 盤面のコピー（表示用のみ、実際の合法性チェックは簡易版）
  late List<List<Piece?>> _board;

  @override
  void initState() {
    super.initState();
    _board = widget.prob.board.map((row) => List<Piece?>.from(row)).toList();
  }

  void _onCellTap(int r, int c) {
    if (_result != null) return; // 回答済みなら操作しない

    final piece = _board[r][c];

    if (_selectedFrom == null) {
      // 先手の駒を選択（持ち駒打ち以外）
      if (piece != null && piece.isPlayer1 == widget.prob.p1Turn) {
        setState(() {
          _selectedFrom = (r, c);
          // 選択した駒の動ける方向を簡易的にドット表示（実際の合法手は省略）
          _moveDots = _calcSimpleDots(r, c, piece);
        });
      }
    } else {
      final (fr, fc) = _selectedFrom!;
      // 選択解除
      if (fr == r && fc == c) {
        setState(() {
          _selectedFrom = null;
          _moveDots = {};
        });
        return;
      }
      // 移動先を決定
      _checkAnswer(fr, fc, r, c, null);
    }
  }

  void _onHandPieceTap(PieceType type) {
    if (_result != null) return;
    // 持ち駒を選択: 打ち先を探す（同じ駒を再タップで選択解除）
    setState(() {
      if (_selectedDropType == type) {
        _selectedFrom = null;
        _selectedDropType = null;
        _moveDots = {};
      } else {
        _selectedFrom = (-1, -1); // drop marker
        _selectedDropType = type;
        _moveDots = _calcDropDots(type);
      }
    });
  }

  void _onDropTarget(int r, int c, PieceType type) {
    if (_result != null) return;
    if (_board[r][c] != null) return; // 駒のあるマスには打てない
    _checkAnswer(-1, -1, r, c, type);
  }

  void _checkAnswer(int fr, int fc, int tr, int tc, PieceType? drop) {
    final ans = widget.prob.answer;
    final correct = ans.fr == fr &&
        ans.fc == fc &&
        ans.tr == tr &&
        ans.tc == tc &&
        ans.drop == drop;

    // 盤面に駒の動きを反映
    if (drop != null) {
      _board[tr][tc] = Piece(drop, widget.prob.p1Turn);
      // ※ p1Hand は const なので setState 内で更新しない（表示のみ）
    } else if (fr >= 0 && fc >= 0) {
      final piece = _board[fr][fc];
      if (piece != null) {
        _board[tr][tc] = piece;
        _board[fr][fc] = null;
      }
    }

    setState(() {
      _result = correct;
      _selectedFrom = null;
      _selectedDropType = null;
      _moveDots = {};
      _lastFrom = fr >= 0 ? (fr, fc) : null;
      _lastTo = (tr, tc);
    });
  }

  // 簡易的なドット計算（移動可能マスの目安表示）
  Set<(int, int)> _calcSimpleDots(int r, int c, Piece piece) {
    final dots = <(int, int)>{};
    final fwd = piece.isPlayer1 ? -1 : 1;
    void add(int nr, int nc) {
      if (nr >= 0 && nr < 9 && nc >= 0 && nc < 9) {
        final target = _board[nr][nc];
        if (target == null || target.isPlayer1 != piece.isPlayer1) {
          dots.add((nr, nc));
        }
      }
    }
    void slide(int dr, int dc) {
      int nr = r + dr, nc = c + dc;
      while (nr >= 0 && nr < 9 && nc >= 0 && nc < 9) {
        final target = _board[nr][nc];
        if (target != null) {
          if (target.isPlayer1 != piece.isPlayer1) dots.add((nr, nc));
          break;
        }
        dots.add((nr, nc));
        nr += dr;
        nc += dc;
      }
    }

    switch (piece.type) {
      case PieceType.king:
        for (int dr = -1; dr <= 1; dr++) for (int dc = -1; dc <= 1; dc++) {
          if (dr != 0 || dc != 0) add(r + dr, c + dc);
        }
        break;
      case PieceType.rook:
      case PieceType.promotedRook:
        slide(-1, 0); slide(1, 0); slide(0, -1); slide(0, 1);
        if (piece.type == PieceType.promotedRook) {
          add(r - 1, c - 1); add(r - 1, c + 1); add(r + 1, c - 1); add(r + 1, c + 1);
        }
        break;
      case PieceType.bishop:
      case PieceType.promotedBishop:
        slide(-1, -1); slide(-1, 1); slide(1, -1); slide(1, 1);
        if (piece.type == PieceType.promotedBishop) {
          add(r - 1, c); add(r + 1, c); add(r, c - 1); add(r, c + 1);
        }
        break;
      case PieceType.gold:
      case PieceType.promotedSilver:
      case PieceType.promotedKnight:
      case PieceType.promotedLance:
      case PieceType.promotedPawn:
        add(r + fwd, c); add(r + fwd, c - 1); add(r + fwd, c + 1);
        add(r, c - 1); add(r, c + 1); add(r - fwd, c);
        break;
      case PieceType.silver:
        add(r + fwd, c); add(r + fwd, c - 1); add(r + fwd, c + 1);
        add(r - fwd, c - 1); add(r - fwd, c + 1);
        break;
      case PieceType.knight:
        add(r + fwd * 2, c - 1); add(r + fwd * 2, c + 1);
        break;
      case PieceType.lance:
        slide(fwd, 0);
        break;
      case PieceType.pawn:
        add(r + fwd, c);
        break;
    }
    return dots;
  }

  Set<(int, int)> _calcDropDots(PieceType type) {
    final dots = <(int, int)>{};
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_board[r][c] == null) dots.add((r, c));
      }
    }
    return dots;
  }

  void _reset() {
    setState(() {
      _board = widget.prob.board.map((row) => List<Piece?>.from(row)).toList();
      _selectedFrom = null;
      _selectedDropType = null;
      _moveDots = {};
      _result = null;
      _lastFrom = null;
      _lastTo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prob = widget.prob;
    final isDrop = _selectedFrom == (-1, -1);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(prob.title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: _reset,
            tooltip: 'リセット',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // カテゴリバッジ
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withAlpha(120)),
                ),
                child: Text(prob.category,
                    style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),

            // 持ち駒（後手）
            if (prob.p2Hand.isNotEmpty)
              _HandDisplay(hand: prob.p2Hand, isPlayer1: false, label: '後手の持ち駒'),

            const SizedBox(height: 8),

            // 盤面
            LayoutBuilder(builder: (context, constraints) {
              final size = constraints.maxWidth < 400 ? constraints.maxWidth : 380.0;
              return Center(
                child: GestureDetector(
                  onTapDown: (details) {
                    // セル座標を計算
                    final labelSize = size * 0.05;
                    final boardSize = size - labelSize;
                    final cellSize = boardSize / 9;
                    final localX = details.localPosition.dx - labelSize;
                    final localY = details.localPosition.dy - labelSize * 1.2;
                    final c = (localX / cellSize).floor();
                    final r = (localY / cellSize).floor();
                    if (r >= 0 && r < 9 && c >= 0 && c < 9) {
                      if (isDrop) {
                        if (_selectedDropType != null) {
                          _onDropTarget(r, c, _selectedDropType!);
                        }
                      } else {
                        _onCellTap(r, c);
                      }
                    }
                  },
                  child: MiniBoardWidget(
                    board: _board,
                    moveDots: _moveDots,
                    lastMoveFrom: _result != null ? _lastFrom
                        : (_selectedFrom != null && !isDrop ? _selectedFrom : null),
                    lastMoveTo: _result != null ? _lastTo : null,
                    size: size,
                  ),
                ),
              );
            }),

            const SizedBox(height: 8),

            // 持ち駒（先手）
            if (prob.p1Hand.isNotEmpty)
              _HandDisplay(
                hand: prob.p1Hand,
                isPlayer1: true,
                label: '先手の持ち駒',
                onPieceTap: (_selectedFrom == null || isDrop) ? _onHandPieceTap : null,
                selectedDrop: isDrop ? _selectedDropType : null,
              ),

            const SizedBox(height: 12),

            // 指示テキスト
            if (_result == null)
              Center(
                child: Text(
                  '${prob.p1Turn ? "先手" : "後手"}の最善手を選んでください',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),

            const SizedBox(height: 12),

            // 結果表示
            if (_result != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (_result! ? Colors.green : Colors.red).withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_result! ? Colors.green : Colors.red).withAlpha(120),
                  ),
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(
                      _result! ? Icons.check_circle : Icons.cancel,
                      color: _result! ? Colors.green : Colors.red,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _result! ? '正解！' : '不正解',
                      style: TextStyle(
                        color: _result! ? Colors.green : Colors.red,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]),
                  if (_result!) ...[
                    const SizedBox(height: 12),
                    Text(prob.explanation,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center),
                  ],
                ]),
              ),
              const SizedBox(height: 12),

              if (_result!)
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('次の問題へ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh, color: Colors.amber),
                  label: const Text('もう一度', style: TextStyle(color: Colors.amber)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.amber),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ===== 持ち駒表示 =====
class _HandDisplay extends StatelessWidget {
  final Map<PieceType, int> hand;
  final bool isPlayer1;
  final String label;
  final void Function(PieceType)? onPieceTap;
  final PieceType? selectedDrop;

  const _HandDisplay({
    required this.hand,
    required this.isPlayer1,
    required this.label,
    this.onPieceTap,
    this.selectedDrop,
  });

  @override
  Widget build(BuildContext context) {
    if (hand.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(width: 8),
        Wrap(
          spacing: 6,
          children: hand.entries.map((e) {
            final isSelected = selectedDrop == e.key;
            return GestureDetector(
              onTap: onPieceTap != null ? () => onPieceTap!(e.key) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.amber.withAlpha(60)
                      : const Color(0xFFE8C87A).withAlpha(200),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? Colors.amber : const Color(0xFF7A4E2B),
                    width: isSelected ? 2 : 0.8,
                  ),
                ),
                child: Text(
                  '${pieceLabel(e.key)}${e.value > 1 ? "×${e.value}" : ""}',
                  style: TextStyle(
                    color: isSelected ? Colors.amber.shade900 : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}



