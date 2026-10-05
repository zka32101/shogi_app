// lib/tsume_verify.dart — 詰将棋データの厳密検証（純Dart）
//
// tool/verify_tsume_deep.dart（CLI）と test/tsume_data_test.dart（CI）から使う。
// 問題を追加・編集したら必ず `dart run tool/verify_tsume_deep.dart` を実行すること。
//
// 検査: A.局面の妥当性 B.解答手順 C.短手数詰め D.解答初手 E.余詰(警告)

import 'dart:convert';

import 'logic.dart';
import 'piece.dart';
import 'tsume_builtin_problems.dart';
import 'tsume_judge.dart';
import 'tsume_rules.dart';

const _limit = {
  PieceType.pawn: 18,
  PieceType.lance: 4,
  PieceType.knight: 4,
  PieceType.silver: 4,
  PieceType.gold: 4,
  PieceType.bishop: 2,
  PieceType.rook: 2,
};

const _csa = {
  'OU': PieceType.king,
  'HI': PieceType.rook,
  'KA': PieceType.bishop,
  'KI': PieceType.gold,
  'GI': PieceType.silver,
  'KE': PieceType.knight,
  'KY': PieceType.lance,
  'FU': PieceType.pawn,
  'RY': PieceType.promotedRook,
  'UM': PieceType.promotedBishop,
  'NG': PieceType.promotedSilver,
  'NK': PieceType.promotedKnight,
  'NY': PieceType.promotedLance,
  'TO': PieceType.promotedPawn,
};

class Prob {
  final String title;
  final int moves;
  final List<List<Piece?>> board;
  final Map<PieceType, int> p1Hand, p2Hand;
  final List<AMove> solution;
  Prob(this.title, this.moves, this.board, this.p1Hand, this.p2Hand, this.solution);
}

String sq(int r, int c) => '${9 - c}${'一二三四五六七八九'[r]}';
String mvStr(AMove m) => m.drop != null
    ? '${sq(m.tr, m.tc)}${m.drop!.name}打'
    : '${sq(m.fr, m.fc)}→${sq(m.tr, m.tc)}${m.promote ? '成' : ''}';
bool sameMove(AMove a, AMove b) =>
    a.fr == b.fr &&
    a.fc == b.fc &&
    a.tr == b.tr &&
    a.tc == b.tc &&
    a.drop == b.drop &&
    a.promote == b.promote;

/// assets/tsume_extra.json の内容（JSON文字列）を読み込む
List<Prob> loadTsumeJson(String jsonText) {
  final list = jsonDecode(jsonText) as List<dynamic>;
  final out = <Prob>[];
  for (final j in list.cast<Map<String, dynamic>>()) {
    if (j['board'] == null) continue; // 先頭の説明用エントリ
    final raw = (j['board'] as List<dynamic>).cast<String>();
    final b = List.generate(9, (_) => List<Piece?>.filled(9, null));
    for (int i = 0; i < 81; i++) {
      final s = raw[i];
      if (s.isEmpty) continue;
      final t = _csa[s.substring(1)];
      if (t != null) b[i ~/ 9][i % 9] = Piece(t, s[0] == '+');
    }
    Map<PieceType, int> hand(Map<String, dynamic>? m) => {
          if (m != null)
            for (final e in m.entries)
              if (_csa[e.key] != null) _csa[e.key]!: e.value as int
        };
    final sol = (j['solution'] as List<dynamic>).map((e) {
      final m = e as Map<String, dynamic>;
      return AMove(
        fr: m['fr'] as int? ?? -1,
        fc: m['fc'] as int? ?? -1,
        tr: m['tr'] as int,
        tc: m['tc'] as int,
        drop: m['drop'] != null ? _csa[m['drop'] as String] : null,
        promote: m['promote'] as bool? ?? false,
      );
    }).toList();
    // 詰将棋ルール: 攻め方の玉は取り除き、残り駒を受け方の持ち駒にする
    final p1h = hand(j['p1Hand'] as Map<String, dynamic>?);
    final nb = tsumeWithoutAttackerKing(b);
    out.add(Prob(j['title'] as String, j['moves'] as int, nb, p1h,
        tsumeDefenderHand(nb, p1h), sol));
  }
  return out;
}


class TsumeReport {
  final List<String> errors;
  final List<String> warnings;
  TsumeReport(this.errors, this.warnings);
}

/// [problems] を検証して結果を返す。
TsumeReport verifyTsumeProblems(List<Prob> problems) {
  final errors = <String>[];
  final warns = <String>[];
  for (final p in problems) {
    final tag = '[${p.title} (${p.moves}手)]';
    void err(String s) => errors.add('$tag $s');

    // A. 局面の妥当性
    int kingsP2 = 0, kingsP1 = 0;
    final counts = <PieceType, int>{};
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final x = p.board[r][c];
        if (x == null) continue;
        if (x.type == PieceType.king) x.isPlayer1 ? kingsP1++ : kingsP2++;
        counts[x.baseType] = (counts[x.baseType] ?? 0) + 1;
        if ((x.type == PieceType.pawn || x.type == PieceType.lance) &&
            ((x.isPlayer1 && r == 0) || (!x.isPlayer1 && r == 8))) {
          err('行き所のない駒: ${x.type.name} ${sq(r, c)}');
        }
        if (x.type == PieceType.knight &&
            ((x.isPlayer1 && r <= 1) || (!x.isPlayer1 && r >= 7))) {
          err('行き所のない桂: ${sq(r, c)}');
        }
      }
    }
    for (final h in [p.p1Hand, p.p2Hand]) {
      h.forEach((t, n) => counts[t] = (counts[t] ?? 0) + n);
    }
    counts.forEach((t, n) {
      final lim = _limit[t];
      if (lim != null && n > lim) err('駒数超過: ${t.name} $n枚（上限$lim）');
    });
    if (kingsP2 != 1) err('後手玉が$kingsP2枚');
    if (kingsP1 > 0) err('攻め方（先手）の玉が盤上にある（詰将棋では置かない）');
    for (final isP1 in [true, false]) {
      for (int c = 0; c < 9; c++) {
        int n = 0;
        for (int r = 0; r < 9; r++) {
          final x = p.board[r][c];
          if (x != null && x.type == PieceType.pawn && x.isPlayer1 == isP1) n++;
        }
        if (n > 1) err('二歩: ${isP1 ? '先手' : '後手'} ${9 - c}筋');
      }
    }
    if (GL.inCheck(p.board, false)) err('開始局面で後手玉が既に王手されている');

    final start = tsumePos(p.board, Map.of(p.p1Hand), Map.of(p.p2Hand));

    // B. 解答手順
    TsumePos cur = start;
    bool mover = true, pathOk = true;
    for (int i = 0; i < p.solution.length; i++) {
      final mv = p.solution[i];
      final legal = AI.allMoves(cur.b, mover, cur.p1h, cur.p2h).any((x) => sameMove(x, mv));
      if (!legal) {
        err('解答${i + 1}手目 ${mvStr(mv)} が非合法');
        pathOk = false;
        break;
      }
      final n = AI.apply(cur.b, cur.p1h, cur.p2h, mv, mover);
      cur = tsumePos(n.b, n.p1h, n.p2h);
      if (mover && !GL.inCheck(cur.b, false)) {
        err('解答${i + 1}手目 ${mvStr(mv)} が王手でない');
      }
      mover = !mover;
    }
    if (pathOk) {
      if (p.solution.length != p.moves) {
        err('解答の手数 ${p.solution.length} が表示手数 ${p.moves} と不一致');
      }
      if (GL.hasLegalMove(cur.b, false, cur.p2h, cur.p1h)) {
        err('解答の最終局面で後手玉が詰んでいない');
      }
    }

    // C. より短い手数で詰むか
    for (int d = 1; d < p.moves; d += 2) {
      if (tsumeMateIn(start, d)) {
        err('$d手で詰む（表示は${p.moves}手）= 短手数詰め');
        break;
      }
    }

    // D/E. 解答初手の確認と余詰
    if (p.solution.isNotEmpty) {
      final first = p.solution.first;
      if (!tsumeFirstMoveMates(start, first, p.moves)) {
        err('解答初手 ${mvStr(first)} は ${p.moves}手以内の詰み手ではない');
      }
      final alts = <String>[];
      for (final m in tsumeChecks(start)) {
        if (sameMove(m, first)) continue;
        if (tsumeFirstMoveMates(start, m, p.moves)) alts.add(mvStr(m));
      }
      if (alts.isNotEmpty) warns.add('$tag 余詰（別解の初手）: ${alts.join(', ')}');
    }
  }

  return TsumeReport(errors, warns);
}
