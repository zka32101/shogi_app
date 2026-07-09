// lib/castle_guide_service.dart — 囲いガイドサービス

import 'piece.dart';

/// 先手（P1）視点の囲い目標配置
/// 座標系: board[row][col], row 0=一段(上/後手側), row 8=九段(下/先手側)
/// col 0=9筋, col 8=1筋
/// 例: 2八玉 → row=7, col=7  /  8八玉 → row=7, col=1
class CastleGuideService {
  static const Map<String, List<(PieceType, int, int)>> _castleTargets = {
    // 矢倉: 8八玉・7八金・7七銀・6七金
    'yagura': [
      (PieceType.king,   7, 1), // 8八玉
      (PieceType.gold,   7, 2), // 7八金
      (PieceType.silver, 6, 2), // 7七銀
      (PieceType.gold,   6, 3), // 6七金
    ],
    // 美濃（振り飛車）: 2八玉・3八金・3七銀
    'mino': [
      (PieceType.king,   7, 7), // 2八玉
      (PieceType.gold,   7, 6), // 3八金
      (PieceType.silver, 6, 6), // 3七銀
    ],
    // 穴熊: 9九玉・9八金・8八銀（左穴熊）
    'anaguma': [
      (PieceType.king,   8, 0), // 9九玉
      (PieceType.gold,   8, 1), // 8九金
      (PieceType.gold,   8, 2), // 7九金
      (PieceType.silver, 7, 0), // 9八銀
      (PieceType.silver, 7, 1), // 8八銀
    ],
    // 金無双: 8八玉・7八金・6八金・7七銀
    'kinmusou': [
      (PieceType.king,   7, 1), // 8八玉
      (PieceType.gold,   7, 2), // 7八金
      (PieceType.gold,   7, 3), // 6八金
      (PieceType.silver, 6, 2), // 7七銀
    ],
    // 銀冠: 8八玉・7八金・8七銀・6七金
    'ginkan': [
      (PieceType.king,   7, 1), // 8八玉
      (PieceType.gold,   7, 2), // 7八金
      (PieceType.silver, 6, 1), // 8七銀（冠＝玉の真上）
      (PieceType.gold,   6, 3), // 6七金
    ],
    // 左美濃（居飛車）: 2八玉・3八金・2七銀・1八金
    'hidarimino': [
      (PieceType.king,   7, 7), // 2八玉
      (PieceType.gold,   7, 6), // 3八金
      (PieceType.silver, 6, 7), // 2七銀（左美濃の特徴）
      (PieceType.gold,   7, 8), // 1八金
    ],
    // 雁木: 6八玉・5八金・6七金・7七銀
    'gangi': [
      (PieceType.king,   7, 3), // 6八玉
      (PieceType.gold,   7, 4), // 5八金
      (PieceType.gold,   6, 3), // 6七金
      (PieceType.silver, 6, 2), // 7七銀
    ],
    // 居飛車穴熊: 9九玉・9八香・8八銀・7八金
    'matsuoanaguma': [
      (PieceType.king,   8, 0), // 9九玉
      (PieceType.lance,  7, 0), // 9八香
      (PieceType.silver, 7, 1), // 8八銀
      (PieceType.gold,   7, 2), // 7八金
    ],
    // elmo囲い: 6八玉・5八金・7七銀
    'elmo': [
      (PieceType.king,   7, 3), // 6八玉
      (PieceType.gold,   7, 4), // 5八金
      (PieceType.silver, 6, 2), // 7七銀
    ],
  };

  static String castleName(String key) => const {
    'yagura':         '矢倉',
    'mino':           '美濃',
    'anaguma':        '穴熊',
    'kinmusou':       '金無双',
    'ginkan':         '銀冠',
    'hidarimino':     '左美濃',
    'gangi':          '雁木',
    'matsuoanaguma':  '居飛車穴熊',
    'elmo':           'elmo囲い',
  }[key] ?? '美濃';

  /// 現在の盤面で未完成の目標マスへの矢印リストを返す
  /// P1（先手）: 目標座標をそのまま使用
  /// P2（後手）: 行・列を反転（row→8-row, col→8-col）
  static List<(int, int, int, int)> getGuideArrows(
    List<List<Piece?>> board,
    String castleKey,
    bool isP1,
  ) {
    final targets = _castleTargets[castleKey];
    if (targets == null) return [];

    final arrows = <(int, int, int, int)>[];
    final usedFrom = <(int, int)>{};

    for (final (pieceType, targetR, targetC) in targets) {
      final tr = isP1 ? targetR : (8 - targetR);
      final tc = isP1 ? targetC : (8 - targetC);

      // 目標マスに既に正しい駒があれば完了
      final atTarget = board[tr][tc];
      if (atTarget != null && atTarget.type == pieceType && atTarget.isPlayer1 == isP1) {
        continue;
      }

      // 盤上からその駒を探す（未使用優先）
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
