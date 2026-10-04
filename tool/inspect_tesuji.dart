// tool/inspect_tesuji.dart — 手筋問題を個別に確認する（盤面・正解手・相手の最善応手・AI上位手）
// 実行: dart run tool/inspect_tesuji.dart ryo_2 book_4 ...
import 'dart:io';
import 'package:shogi_app/logic.dart';
import 'package:shogi_app/piece.dart';
import 'package:shogi_app/tesuji_problems.dart';

const _ch = {
  PieceType.king: '玉', PieceType.rook: '飛', PieceType.bishop: '角', PieceType.gold: '金',
  PieceType.silver: '銀', PieceType.knight: '桂', PieceType.lance: '香', PieceType.pawn: '歩',
  PieceType.promotedRook: '龍', PieceType.promotedBishop: '馬', PieceType.promotedSilver: '全',
  PieceType.promotedKnight: '圭', PieceType.promotedLance: '杏', PieceType.promotedPawn: 'と',
};
const _val = {
  PieceType.pawn: 1, PieceType.lance: 3, PieceType.knight: 3, PieceType.silver: 5, PieceType.gold: 6,
  PieceType.bishop: 8, PieceType.rook: 10, PieceType.promotedPawn: 4, PieceType.promotedLance: 5,
  PieceType.promotedKnight: 5, PieceType.promotedSilver: 6, PieceType.promotedBishop: 10,
  PieceType.promotedRook: 12, PieceType.king: 0,
};
String sq(int r, int c) => '${9 - c}${'一二三四五六七八九'[r]}';
String mv(AMove m) => m.drop != null ? '${sq(m.tr, m.tc)}${_ch[m.drop]}打' : '${sq(m.fr, m.fc)}→${sq(m.tr, m.tc)}${m.promote ? '成' : ''}';
int mat(List<List<Piece?>> b, Map<PieceType, int> a, Map<PieceType, int> d) {
  int s = 0;
  for (final r in b) { for (final x in r) { if (x != null) s += x.isPlayer1 ? (_val[x.type] ?? 0) : -(_val[x.type] ?? 0); } }
  a.forEach((t, n) => s += (_val[t] ?? 0) * n);
  d.forEach((t, n) => s -= (_val[t] ?? 0) * n);
  return s;
}

void main(List<String> ids) {
  final all = buildTesujiProblems();
  for (final id in ids) {
    final p = all.firstWhere((e) => e.id == id);
    stdout.writeln('\n=== ${p.id} ${p.category}/${p.title}  手番=${p.p1Turn ? '先手' : '後手'}');
    stdout.writeln('    9 8 7 6 5 4 3 2 1');
    for (int r = 0; r < 9; r++) {
      final row = StringBuffer('${'一二三四五六七八九'[r]}  ');
      for (int c = 0; c < 9; c++) {
        final x = p.board[r][c];
        row.write(x == null ? '・ ' : '${x.isPlayer1 ? '' : 'v'}${_ch[x.type]}'.padRight(2, ' '));
      }
      stdout.writeln(row);
    }
    stdout.writeln('先手持駒: ${p.p1Hand.map((k, v) => MapEntry(_ch[k], v))}  後手持駒: ${p.p2Hand.map((k, v) => MapEntry(_ch[k], v))}');
    stdout.writeln('正解: ${mv(p.answer)}   解説: ${p.explanation}');
    final me = p.p1Turn;
    final base = (mat(p.board, p.p1Hand, p.p2Hand)) * (me ? 1 : -1);
    final a1 = AI.apply(p.board, Map.of(p.p1Hand), Map.of(p.p2Hand), p.answer, me);
    final after = mat(a1.b, a1.p1h, a1.p2h) * (me ? 1 : -1);
    stdout.writeln('正解手の直後の損得: ${after - base}');
    // 相手の応手ごとに、こちらの最善の取り返しまで
    final replies = AI.allMoves(a1.b, !me, a1.p1h, a1.p2h);
    String worstDesc = ''; int worst = 1 << 30;
    for (final d in replies) {
      final a2 = AI.apply(a1.b, a1.p1h, a1.p2h, d, !me);
      int best = mat(a2.b, a2.p1h, a2.p2h) * (me ? 1 : -1); String bm = '-';
      for (final n in AI.allMoves(a2.b, me, a2.p1h, a2.p2h)) {
        if (n.drop == null && a2.b[n.tr][n.tc] == null) continue;
        final a3 = AI.apply(a2.b, a2.p1h, a2.p2h, n, me);
        final v = mat(a3.b, a3.p1h, a3.p2h) * (me ? 1 : -1);
        if (v > best) { best = v; bm = mv(n); }
      }
      if (best < worst) { worst = best; worstDesc = '${mv(d)} → ${bm}'; }
    }
    stdout.writeln('相手の最善応手(3手読み): $worstDesc  → 最終損得 ${worst - base}');
    final top = AI.topMoves(p.board, Map.of(p.p1Hand), Map.of(p.p2Hand), me, 4, n: 4);
    stdout.writeln('AI(深さ4)上位: ${top.map((e) => '${mv(e.$1)}(${e.$2})').join(' / ')}');
  }
}
