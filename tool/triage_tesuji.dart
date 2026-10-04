// tool/triage_tesuji.dart — 手筋102問を「正解手の3手読み損得」で仕分けする
// 実行: dart run tool/triage_tesuji.dart
//   OK    : 正解手が3手読みで最善（同率可）、または駒得>0
//   WEAK  : 正解手より明らかに良い手がある（差>=2）
//   BAD   : 正解手が3手読みで駒損（<0）
import 'dart:io';
import 'package:shogi_app/logic.dart';
import 'package:shogi_app/piece.dart';
import 'package:shogi_app/tesuji_problems.dart';
import 'package:shogi_app/tsume_judge.dart';

const _val = {
  PieceType.pawn: 1, PieceType.lance: 3, PieceType.knight: 3, PieceType.silver: 5, PieceType.gold: 6,
  PieceType.bishop: 8, PieceType.rook: 10, PieceType.promotedPawn: 4, PieceType.promotedLance: 5,
  PieceType.promotedKnight: 5, PieceType.promotedSilver: 6, PieceType.promotedBishop: 10,
  PieceType.promotedRook: 12, PieceType.king: 0,
};
int mat(List<List<Piece?>> b, Map<PieceType, int> a, Map<PieceType, int> d) {
  int s = 0;
  for (final r in b) { for (final x in r) { if (x != null) s += x.isPlayer1 ? (_val[x.type] ?? 0) : -(_val[x.type] ?? 0); } }
  a.forEach((t, n) => s += (_val[t] ?? 0) * n);
  d.forEach((t, n) => s -= (_val[t] ?? 0) * n);
  return s;
}
typedef P = ({List<List<Piece?>> b, Map<PieceType, int> p1h, Map<PieceType, int> p2h});
P ap(P p, AMove m, bool p1) { final n = AI.apply(p.b, p.p1h, p.p2h, m, p1); return (b: n.b, p1h: n.p1h, p2h: n.p2h); }
int d(P p, bool me) => me ? mat(p.b, p.p1h, p.p2h) : -mat(p.b, p.p1h, p.p2h);
int valueOf(P s, AMove m, bool me) {
  final a = ap(s, m, me);
  if (GL.inCheck(a.b, !me) && !GL.hasLegalMove(a.b, !me, me ? a.p2h : a.p1h, me ? a.p1h : a.p2h)) return 9999;
  final rs = AI.allMoves(a.b, !me, a.p1h, a.p2h);
  if (rs.isEmpty) return d(a, me);
  int worst = 1 << 30;
  for (final r in rs) {
    final p2 = ap(a, r, !me);
    int best = d(p2, me);
    for (final n in AI.allMoves(p2.b, me, p2.p1h, p2.p2h)) {
      if (n.drop == null && p2.b[n.tr][n.tc] == null) continue;
      final v = d(ap(p2, n, me), me);
      if (v > best) best = v;
    }
    if (best < worst) worst = best;
  }
  return worst;
}
bool same(AMove a, AMove b) => a.fr == b.fr && a.fc == b.fc && a.tr == b.tr && a.tc == b.tc && a.drop == b.drop && a.promote == b.promote;

void main() {
  int ok = 0, weak = 0, bad = 0;
  for (final p in buildTesujiProblems()) {
    if (p.category == '詰め') { ok++; continue; }
    final me = p.p1Turn;
    final s = (b: p.board, p1h: Map.of(p.p1Hand), p2h: Map.of(p.p2Hand));
    final base = d(s, me);
    final av = valueOf(s, p.answer, me) - base;
    int bestV = av; AMove? bestM;
    for (final m in AI.allMoves(p.board, me, s.p1h, s.p2h)) {
      if (same(m, p.answer)) continue;
      final v = valueOf(s, m, me) - base;
      if (v > bestV) { bestV = v; bestM = m; }
    }
    final tag = av < 0 ? 'BAD ' : (bestV - av >= 2 ? 'WEAK' : 'OK  ');
    if (tag == 'BAD ') bad++; else if (tag == 'WEAK') weak++; else ok++;
    if (tag != 'OK  ') stdout.writeln('$tag ${p.id} [${p.category}] 正解の損得=$av 最善=$bestV');
  }
  stdout.writeln('OK $ok / WEAK $weak / BAD $bad');
}
