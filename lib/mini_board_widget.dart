// lib/mini_board_widget.dart
import 'package:flutter/material.dart';
import 'piece.dart';

class MiniBoardWidget extends StatelessWidget {
  final List<List<Piece?>> board;
  final Set<(int, int)> moveDots;        // Green dots for legal moves
  final (int, int)? lastMoveFrom;        // Amber tint (last move source)
  final (int, int)? lastMoveTo;          // Amber border (last move dest)
  final (int, int)? hintFrom;            // Cyan (best move source)
  final (int, int)? hintTo;              // Cyan (best move dest)
  final Set<(int, int)> highlightSquares;// Light blue highlight squares
  final bool showLabels;                  // Show rank/file labels
  final double? size;                     // Board size override
  final bool? currentIsP1;               // null=none, true=p1 is current turn, false=p2 is current turn
  final bool boardFlipped; // ボード反転時の駒向き調整

  const MiniBoardWidget({
    super.key,
    required this.board,
    this.moveDots = const {},
    this.lastMoveFrom,
    this.lastMoveTo,
    this.hintFrom,
    this.hintTo,
    this.highlightSquares = const {},
    this.showLabels = true,
    this.size,
    this.currentIsP1,
    this.boardFlipped = false,
  });

  // Colors matching game_screen.dart
  static const _cellColor = Color(0xFFE8C87A);
  static const _cellBorder = Color(0xFF7A4E2B);

  Color _pieceColor(Piece p) {
    final effectiveP1 = boardFlipped ? !p.isPlayer1 : p.isPlayer1;
    if (effectiveP1) {
      return p.isPromoted ? const Color(0xFF1565C0) : Colors.black;
    } else {
      return p.isPromoted ? Colors.red.shade700 : Colors.red.shade900;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final totalSize = size ?? constraints.maxWidth;
      final labelSize = showLabels ? totalSize * 0.05 : 0.0;
      final boardSize = totalSize - labelSize;
      final cellSize = boardSize / 9;

      Widget boardGrid = Container(
        width: boardSize,
        height: boardSize,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF4A2E0A), width: 2),
          color: _cellColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(80),
              blurRadius: 8,
              offset: const Offset(1, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(9, (r) =>
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(9, (c) {
                final piece = board[r][c];
                final isDot = moveDots.contains((r, c));
                final isHL = highlightSquares.contains((r, c));
                final isLastTo = lastMoveTo == (r, c);
                final isLastFr = lastMoveFrom == (r, c);
                final isHintFr = hintFrom == (r, c);
                final isHintTo = hintTo == (r, c);

                Color bg = _cellColor;
                // 現在手番の駒に薄いハイライト
                if (currentIsP1 != null && piece != null) {
                  if (piece.isPlayer1 == currentIsP1) {
                    bg = Color.lerp(bg, Colors.blue.shade200, 0.18)!;
                  } else {
                    bg = Color.lerp(bg, Colors.red.shade200, 0.12)!;
                  }
                }
                if (isLastFr) bg = Color.lerp(_cellColor, Colors.amber.shade200, 0.35)!;
                if (isLastTo) bg = Color.lerp(_cellColor, Colors.amber.shade300, 0.55)!;
                if (isHintFr) bg = Colors.cyan.shade200;
                if (isHintTo) bg = Colors.cyan.shade100;
                if (isHL) bg = Colors.lightBlue.shade100;

                return Container(
                  width: cellSize,
                  height: cellSize,
                  decoration: BoxDecoration(
                    color: bg,
                    border: isLastTo && hintTo == null
                        ? Border.all(color: Colors.amber.shade600, width: 1.5)
                        : isHintTo
                        ? Border.all(color: Colors.cyan.shade700, width: 1.5)
                        : Border.all(color: _cellBorder, width: 0.6),
                  ),
                  child: Stack(children: [
                    if (piece != null)
                      Center(
                        child: RotatedBox(
                          quarterTurns: (boardFlipped ? !piece.isPlayer1 : piece.isPlayer1) ? 0 : 2,
                          child: Text(
                            piece.label,
                            style: TextStyle(
                              fontSize: cellSize * 0.62,
                              fontWeight: FontWeight.bold,
                              color: _pieceColor(piece),
                              height: 1.0,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withAlpha(50),
                                  blurRadius: 2,
                                  offset: const Offset(0.5, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (isDot)
                      Center(
                        child: Container(
                          width: cellSize * 0.35,
                          height: cellSize * 0.35,
                          decoration: BoxDecoration(
                            color: Colors.green.shade500.withAlpha(170),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ]),
                );
              }),
            ),
          ),
        ),
      );

      if (!showLabels) return boardGrid;

      const rankKanji = ['一','二','三','四','五','六','七','八','九'];
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            SizedBox(width: labelSize),
            ...List.generate(9, (i) => SizedBox(
              width: cellSize,
              child: Text('${9 - i}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: labelSize * 0.7)),
            )),
          ]),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(children: List.generate(9, (i) => SizedBox(
                width: labelSize,
                height: cellSize,
                child: Center(child: Text(rankKanji[i],
                  style: TextStyle(color: Colors.white54, fontSize: labelSize * 0.7))),
              ))),
              boardGrid,
            ],
          ),
        ],
      );
    });
  }
}
