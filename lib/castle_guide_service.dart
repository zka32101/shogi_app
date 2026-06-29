// lib/castle_guide_service.dart — 囲いガイドサービス

import 'piece.dart';

/// 先手（P1）視点の囲い目標配置（row 8 = 先手側最下段）
/// 座標系: row 0 = 上段（後手側）、row 8 = 下段（先手側）
/// 矢倉:   王(7,1) 金(7,2)(6,2) 銀(6,1)   — 7八玉、8七銀、7七銀、8八金 等
/// 美濃:   王(7,1) 金(7,2) 銀(6,2)         — 7八玉、8七金、7七銀
/// 穴熊:   王(8,0) 金(7,0) 銀(7,1)         — 9一玉、9二金、8二銀（左穴熊）
/// 金無双: 王(8,1) 金(7,1) 金(7,2)         — 8一玉、8二金、7二金
class CastleGuideService {
  static const Map<String, List<(PieceType, int, int)>> _castleTargets = {
    'yagura': [
      (PieceType.king,   7, 1),
      (PieceType.gold,   7, 2),
      (PieceType.silver, 6, 1),
    ],
    'mino': [
      (PieceType.king,   7, 1),
      (PieceType.gold,   7, 2),
      (PieceType.silver, 6, 2),
    ],
    // 左穴熊: 9一玉・9二金・8二銀（col 0 = 9筋, row 8 = 1段目）
    'anaguma': [
      (PieceType.king,   8, 0),
      (PieceType.gold,   7, 0),
      (PieceType.silver, 7, 1),
    ],
    // 金無双: 8一玉・8二金・7二金（玉の直上と斜め上に金2枚）
    'kinmusou': [
      (PieceType.king,   8, 1),
      (PieceType.gold,   7, 1),
      (PieceType.gold,   7, 2),
    ],
    // 銀冠: 7七玉・8七金・6七銀（玉を7七に上がる現代囲い）
    'ginkan': [
      (PieceType.king,   6, 2),
      (PieceType.gold,   6, 1),
      (PieceType.silver, 6, 3),
    ],
    // 左美濃: 2八玉・3八金・3七銀（振り飛車の左側囲い）
    'hidarimino': [
      (PieceType.king,   7, 7),
      (PieceType.gold,   7, 6),
      (PieceType.silver, 6, 6),
    ],
    // 雁木: 6八玉・7七銀・6七銀（歩を突かずに銀で組む）
    'gangi': [
      (PieceType.king,   7, 3),
      (PieceType.silver, 6, 2),
      (PieceType.silver, 6, 3),
      (PieceType.gold,   7, 2),
    ],
    // 松尾流穴熊: 9九玉・9八香・8八銀（左穴熊の発展形）
    'matsuoanaguma': [
      (PieceType.king,   8, 0),
      (PieceType.lance,  8, 1),
      (PieceType.silver, 7, 1),
      (PieceType.gold,   7, 0),
    ],
    // elmo囲い: 6八玉・5八金・7七銀（コンピュータ将棋由来）
    'elmo': [
      (PieceType.king,   7, 3),
      (PieceType.gold,   7, 4),
      (PieceType.silver, 6, 2),
    ],
  };

  static String castleName(String key) => const {
    'yagura': '矢倉',
    'mino': '美濃',
    'anaguma': '穴熊',
    'kinmusou': '金無双',
    'ginkan': '銀冠',
    'hidarimino': '左美濃',
    'gangi': '雁木',
    'matsuoanaguma': '松尾流穴熊',
    'elmo': 'elmo囲い',
  }[key] ?? '美濃';

  /// 現在の盤面で未完成の目標マスを返す（優先度順）
  /// 返り値: List<(fromRow, fromCol, toRow, toCol)> = 推奨手の矢印リスト
  /// P1（先手）: row 8 = 自陣下段（目標座標をそのまま使用）
  /// P2（後手）: row 0 = 自陣上段（目標座標を反転して使用）
  static List<(int, int, int, int)> getGuideArrows(
    List<List<Piece?>> board,
    String castleKey,
    bool isP1,
  ) {
    final targets = _castleTargets[castleKey];
    if (targets == null) return [];

    final arrows = <(int, int, int, int)>[];
    // 既に処理したfromマスを記録（同じ駒を2回マッチしないよう）
    final usedFrom = <(int, int)>{};

    for (final (pieceType, targetR, targetC) in targets) {
      // P1（先手）: 目標座標をそのまま使用（row 8 = 先手側下段）
      // P2（後手）: 行を反転（row 8 → 0, row 7 → 1, ...）
      final tr = isP1 ? targetR : (8 - targetR);
      final tc = isP1 ? targetC : (8 - targetC);

      // 目標マスに既に正しい駒があるか？
      final atTarget = board[tr][tc];
      if (atTarget != null && atTarget.type == pieceType && atTarget.isPlayer1 == isP1) {
        continue; // 完了
      }

      // その駒がどこにあるか探す（未使用のものを優先）
      (int, int)? found;
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (usedFrom.contains((r, c))) continue;
          final p = board[r][c];
          if (p != null && p.type == pieceType && p.isPlayer1 == isP1) {
            if (r != tr || c != tc) {
              found = (r, c);
              break;
            }
          }
        }
        if (found != null) break;
      }

      if (found != null) {
        usedFrom.add(found);
        arrows.add((found.$1, found.$2, tr, tc));
      }
    }

    return arrows;
  }
}
