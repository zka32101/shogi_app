// lib/screens/network_board_widget.dart
// ネットワーク対局用インライン将棋盤 Widget

import 'package:flutter/material.dart';
import '../piece.dart';
import '../logic.dart';
import '../game_screen.dart';
import '../services/board_sync_service.dart';
import '../theme_config.dart';

class NetworkBoardWidget extends StatefulWidget {
  final NetworkBoardState state;
  final bool isPlayer1; // 自分が先手か後手か
  final bool isMyTurn;
  final Function(KifuMove move) onMove; // 指し手コールバック
  final PieceTheme theme;

  const NetworkBoardWidget({
    super.key,
    required this.state,
    required this.isPlayer1,
    required this.isMyTurn,
    required this.onMove,
    this.theme = PieceTheme.standard,
  });

  @override
  State<NetworkBoardWidget> createState() => _NetworkBoardWidgetState();
}

class _NetworkBoardWidgetState extends State<NetworkBoardWidget> {
  late final BoardThemeConfig _themeConfig;
  (int, int)? _selectedCell; // 選択中のマス
  PieceType? _selectedHandPiece; // 持ち駒選択
  List<(int, int)> _legalMoves = []; // 合法手ハイライト

  @override
  void initState() {
    super.initState();
    _themeConfig = boardThemeConfig(widget.theme);
  }

  @override
  void didUpdateWidget(NetworkBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme != widget.theme) {
      _themeConfig = boardThemeConfig(widget.theme);
    }
  }

  // 自分の持ち駒
  Map<PieceType, int> get myHand =>
      widget.isPlayer1 ? widget.state.p1Hand : widget.state.p2Hand;
  // 相手の持ち駒
  Map<PieceType, int> get oppHand =>
      widget.isPlayer1 ? widget.state.p2Hand : widget.state.p1Hand;

  // 後手視点では盤を 180° 回転して表示
  int _r(int r) => widget.isPlayer1 ? r : 8 - r;
  int _c(int c) => widget.isPlayer1 ? c : 8 - c;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 相手の持ち駒（上）
        _buildHandRow(oppHand, isMyHand: false),
        const SizedBox(height: 4),
        // 盤面
        Expanded(child: _buildBoard()),
        const SizedBox(height: 4),
        // 自分の持ち駒（下）
        _buildHandRow(myHand, isMyHand: true),
      ],
    );
  }

  // ── 盤面 ────────────────────────────────────────────────────

  Widget _buildBoard() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: _themeConfig.cell,
          border: Border.all(color: _themeConfig.boardBorder, width: 2),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 9,
          ),
          itemCount: 81,
          itemBuilder: (_, index) {
            final dispRow = index ~/ 9;
            final dispCol = index % 9;
            // 実際の行列（視点に応じて変換）
            final row = _r(dispRow);
            final col = _c(dispCol);
            return _buildCell(row, col, dispRow, dispCol);
          },
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col, int dispRow, int dispCol) {
    final piece = widget.state.board[row][col];
    final isSelected = _selectedCell == (row, col);
    final isLegal = _legalMoves.contains((row, col));
    final isLastMove = widget.state.moves.isNotEmpty &&
        widget.state.moves.last.tr == row &&
        widget.state.moves.last.tc == col;

    Color bg = _themeConfig.cell;
    if (isSelected) bg = Colors.blue.shade200;
    else if (isLegal) bg = Colors.green.shade200;
    else if (isLastMove) bg = Colors.yellow.shade200;

    return GestureDetector(
      onTap: () => _onTapCell(row, col),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: _themeConfig.cellBorder, width: 0.5),
        ),
        child: piece != null ? _buildPiece(piece) : null,
      ),
    );
  }

  Widget _buildPiece(Piece piece) {
    final isEnemy = piece.isPlayer1 != widget.isPlayer1;
    return Center(
      child: RotatedBox(
        quarterTurns: isEnemy ? 2 : 0,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Text(
              piece.label,
              style: TextStyle(
                color: piece.isPromoted ? Colors.red.shade800 : _themeConfig.pieceNormal,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 持ち駒行 ────────────────────────────────────────────────

  Widget _buildHandRow(Map<PieceType, int> hand, {required bool isMyHand}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.brown.shade900.withAlpha(80),
      child: Row(
        children: [
          Text(
            isMyHand ? '持駒 ▼' : '持駒 ▲',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: hand.entries
                    .where((e) => e.value > 0)
                    .map((e) => GestureDetector(
                          onTap: isMyHand && widget.isMyTurn
                              ? () => _onTapHandPiece(e.key)
                              : null,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: _selectedHandPiece == e.key
                                  ? Colors.blue.shade700
                                  : Colors.brown.shade700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${pieceLabel(e.key)}×${e.value}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── タップ処理 ──────────────────────────────────────────────

  void _onTapHandPiece(PieceType type) {
    if (!widget.isMyTurn) return;
    setState(() {
      if (_selectedHandPiece == type) {
        _selectedHandPiece = null;
        _selectedCell = null;
        _legalMoves = [];
      } else {
        _selectedHandPiece = type;
        _selectedCell = null;
        // 打てるマスをハイライト
        _legalMoves = GL.dropSquares(
          widget.state.board,
          type,
          widget.isPlayer1,
          myHand,
          oppHand,
        );
      }
    });
  }

  void _onTapCell(int row, int col) {
    if (!widget.isMyTurn) return;

    // 持ち駒から打つ
    if (_selectedHandPiece != null) {
      if (_legalMoves.contains((row, col))) {
        _commitDrop(_selectedHandPiece!, row, col);
      } else {
        setState(() {
          _selectedHandPiece = null;
          _legalMoves = [];
        });
      }
      return;
    }

    final piece = widget.state.board[row][col];

    // 移動先を選択中
    if (_selectedCell != null) {
      if (_legalMoves.contains((row, col))) {
        _commitMove(_selectedCell!, row, col);
        return;
      }
      // 自駒を再選択
      if (piece != null && piece.isPlayer1 == widget.isPlayer1) {
        _selectCell(row, col);
        return;
      }
      // 選択解除
      setState(() {
        _selectedCell = null;
        _legalMoves = [];
      });
      return;
    }

    // 自駒を選択
    if (piece != null && piece.isPlayer1 == widget.isPlayer1) {
      _selectCell(row, col);
    }
  }

  void _selectCell(int row, int col) {
    final moves = GL.legal(widget.state.board, row, col);
    setState(() {
      _selectedCell = (row, col);
      _selectedHandPiece = null;
      _legalMoves = moves;
    });
  }

  // ── 指し手決定 ──────────────────────────────────────────────

  Future<void> _commitMove(
      (int, int) from, int toRow, int toCol) async {
    final piece = widget.state.board[from.$1][from.$2]!;
    bool promote = false;

    // 成れる場合、確認ダイアログ
    if (piece.canPromote && !piece.isPromoted) {
      final inZone = widget.isPlayer1
          ? (toRow <= 2 || from.$1 <= 2)
          : (toRow >= 6 || from.$1 >= 6);
      if (inZone && !piece.mustPromote(toRow)) {
        promote = await _showPromoteDialog(piece) ?? false;
      } else if (piece.mustPromote(toRow)) {
        promote = true;
      }
    }

    final moveCount = widget.state.moveCount + 1;
    final note = _buildMoveNote(piece, from, toRow, toCol, promote);

    final move = KifuMove(
      moveCount,
      widget.isPlayer1,
      note,
      fr: from.$1,
      fc: from.$2,
      tr: toRow,
      tc: toCol,
      promote: promote,
    );

    setState(() {
      _selectedCell = null;
      _legalMoves = [];
    });

    widget.onMove(move);
  }

  Future<void> _commitDrop(PieceType type, int row, int col) async {
    final moveCount = widget.state.moveCount + 1;
    final note = '${pieceLabel(type)}打';
    final move = KifuMove(
      moveCount,
      widget.isPlayer1,
      note,
      fr: -1,
      fc: -1,
      tr: row,
      tc: col,
      drop: type,
    );

    setState(() {
      _selectedHandPiece = null;
      _legalMoves = [];
    });

    widget.onMove(move);
  }

  Future<bool?> _showPromoteDialog(Piece piece) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('成りますか？'),
        content: Text(
            '${piece.label} を ${pieceLabel(piece.promotedType)} に成りますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('成らない'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('成る'),
          ),
        ],
      ),
    );
  }

  String _buildMoveNote(
      Piece piece, (int, int) from, int toRow, int toCol, bool promote) {
    final col = widget.isPlayer1 ? 9 - toCol : toCol + 1;
    final row = widget.isPlayer1 ? toRow + 1 : 9 - toRow;
    final suffix = promote ? '成' : '';
    return '$col${_rowKanji(row)}${piece.label}$suffix';
  }

  String _rowKanji(int r) {
    const kanji = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
    return r >= 1 && r <= 9 ? kanji[r - 1] : r.toString();
  }
}
