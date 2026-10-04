// lib/tsume_judge.dart — 詰将棋の厳密な判定（純Dart）
//
// 詰将棋のルール: 攻め方（先手）の手は必ず王手。受け方（後手）は全ての合法手を試す。
// アプリの画面と、tool/verify_tsume_deep.dart（問題データの検証）の両方で使う。

import 'logic.dart';
import 'piece.dart';

typedef TsumePos = ({
  List<List<Piece?>> b,
  Map<PieceType, int> p1h,
  Map<PieceType, int> p2h,
});

TsumePos tsumePos(
  List<List<Piece?>> b,
  Map<PieceType, int> p1h,
  Map<PieceType, int> p2h,
) =>
    (b: b, p1h: p1h, p2h: p2h);

TsumePos _apply(TsumePos p, AMove m, bool p1) {
  final n = AI.apply(p.b, p.p1h, p.p2h, m, p1);
  return (b: n.b, p1h: n.p1h, p2h: n.p2h);
}

/// 攻め方(先手)の王手になる合法手
List<AMove> tsumeChecks(TsumePos p) {
  final out = <AMove>[];
  for (final m in AI.allMoves(p.b, true, p.p1h, p.p2h)) {
    if (GL.inCheck(_apply(p, m, true).b, false)) out.add(m);
  }
  return out;
}

bool _defenderHasMove(TsumePos p) => GL.hasLegalMove(p.b, false, p.p2h, p.p1h);

/// 先手番の局面 [p] から、[depth] 手以内（奇数）で詰ませられるか。
bool tsumeMateIn(TsumePos p, int depth) {
  for (final m in tsumeChecks(p)) {
    if (_moveMates(p, m, depth)) return true;
  }
  return false;
}

/// 先手の初手 [m] が、[depth] 手以内の詰み手か（王手でなければ false）。
bool tsumeFirstMoveMates(TsumePos p, AMove m, int depth) {
  if (!GL.inCheck(_apply(p, m, true).b, false)) return false;
  return _moveMates(p, m, depth);
}

bool _moveMates(TsumePos p, AMove m, int depth) {
  final n = _apply(p, m, true);
  if (!_defenderHasMove(n)) return true; // 詰み
  if (depth < 3) return false;
  for (final d in AI.allMoves(n.b, false, n.p1h, n.p2h)) {
    if (!tsumeMateIn(_apply(n, d, false), depth - 2)) return false;
  }
  return true;
}

/// 先手番の局面で、詰みまでの最短手数（[maxDepth] まで探索）。詰まなければ null。
int? tsumeMateDistance(TsumePos p, int maxDepth) {
  for (int d = 1; d <= maxDepth; d += 2) {
    if (tsumeMateIn(p, d)) return d;
  }
  return null;
}

/// 先手が [attackerMove] を指した直後（後手番）の局面 [p] で、
/// 受け方の「最善の粘り」を返す。
///
/// [remaining] = 先手の次の手から数えて、残り何手以内に詰ませる必要があるか（奇数）。
/// - 先手がその手数内に詰ませられない受けがあれば、そのうち最初のものを返す
///   （＝先手の手は詰み手ではなかった、と画面側が判定できる）
/// - 全ての受けが詰みに至るなら、詰みまでが最も長くなる受けを返す
AMove? tsumeBestDefense(TsumePos p, int remaining) {
  final defs = AI.allMoves(p.b, false, p.p1h, p.p2h);
  if (defs.isEmpty) return null;
  AMove? best;
  int bestDist = -1;
  for (final d in defs) {
    final n = _apply(p, d, false);
    final dist = tsumeMateDistance(n, remaining < 1 ? 1 : remaining);
    if (dist == null) return d; // 先手が詰ませられない受け
    if (dist > bestDist) {
      bestDist = dist;
      best = d;
    }
  }
  return best;
}

// ─────────────────────────────────────────────
// 手順の棋譜表記（解答から自動生成 → 常に盤面と一致する）
// ─────────────────────────────────────────────

const _kifuNames = {
  PieceType.king: '玉',
  PieceType.rook: '飛',
  PieceType.bishop: '角',
  PieceType.gold: '金',
  PieceType.silver: '銀',
  PieceType.knight: '桂',
  PieceType.lance: '香',
  PieceType.pawn: '歩',
  PieceType.promotedRook: '龍',
  PieceType.promotedBishop: '馬',
  PieceType.promotedSilver: '成銀',
  PieceType.promotedKnight: '成桂',
  PieceType.promotedLance: '成香',
  PieceType.promotedPawn: 'と',
};

String _kifuSquare(int r, int c) => '${9 - c}${'一二三四五六七八九'[r]}';

/// 解答手順を「▲6二金(73)」形式にする。先手=▲、後手=△。
List<String> tsumeKifu(TsumePos start, List<AMove> solution) {
  final out = <String>[];
  var cur = start;
  bool p1 = true;
  for (final m in solution) {
    final mark = p1 ? '▲' : '△';
    final dest = _kifuSquare(m.tr, m.tc);
    if (m.drop != null) {
      out.add('$mark$dest${_kifuNames[m.drop!] ?? ''}打');
    } else {
      final piece = cur.b[m.fr][m.fc];
      final name = piece == null ? '' : (_kifuNames[piece.type] ?? '');
      final from = '${9 - m.fc}${m.fr + 1}';
      out.add('$mark$dest$name${m.promote ? '成' : ''}($from)');
    }
    cur = _apply(cur, m, p1);
    p1 = !p1;
  }
  return out;
}

/// 「手順: ▲6二金(73) △4一玉(51) ▲3二桂打」
String tsumeKifuText(TsumePos start, List<AMove> solution) =>
    solution.isEmpty ? '' : '手順: ${tsumeKifu(start, solution).join(' ')}';
