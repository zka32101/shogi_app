// lib/tsume_rules.dart — 詰将棋の初期局面ルール（純Dart）
//
// 詰将棋のルール:
//  1. 攻め方の玉は盤上に置かない（問題図に攻め方の玉は存在しない）
//  2. 盤上と攻め方の持ち駒に出ていない駒は、すべて受け方の持ち駒（合駒に使える）
//  3. 攻め方の手は全て王手 / 受け方は最善の応手 / 打ち歩詰め禁止
// 問題データは 1 を満たす形で持ち、2 は読み込み時にここで導く。

import 'piece.dart';

const tsumeTotalPieces = <PieceType, int>{
  PieceType.pawn: 18,
  PieceType.lance: 4,
  PieceType.knight: 4,
  PieceType.silver: 4,
  PieceType.gold: 4,
  PieceType.bishop: 2,
  PieceType.rook: 2,
};

/// 盤上から攻め方(先手)の玉を取り除いた新しい盤を返す。
List<List<Piece?>> tsumeWithoutAttackerKing(List<List<Piece?>> board) => [
      for (final row in board)
        [
          for (final p in row)
            (p != null && p.type == PieceType.king && p.isPlayer1) ? null : p
        ]
    ];

/// 盤上(両者)と攻め方の持ち駒を除いた「残り駒」＝受け方の持ち駒。
Map<PieceType, int> tsumeDefenderHand(
    List<List<Piece?>> board, Map<PieceType, int> attackerHand) {
  final used = <PieceType, int>{};
  for (final row in board) {
    for (final p in row) {
      if (p == null || p.type == PieceType.king) continue;
      used[p.baseType] = (used[p.baseType] ?? 0) + 1;
    }
  }
  attackerHand.forEach((t, n) => used[t] = (used[t] ?? 0) + n);
  final out = <PieceType, int>{};
  tsumeTotalPieces.forEach((t, total) {
    final left = total - (used[t] ?? 0);
    if (left > 0) out[t] = left;
  });
  return out;
}

bool tsumeHasAttackerKing(List<List<Piece?>> board) => board.any(
    (row) => row.any((p) => p != null && p.type == PieceType.king && p.isPlayer1));
