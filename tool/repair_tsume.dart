// tool/repair_tsume.dart — 詰将棋データの解答を探索で再計算する補助ツール
//
// 実行: dart run tool/repair_tsume.dart            # 診断のみ（何も書き換えない）
//       dart run tool/repair_tsume.dart --write    # assets/tsume_extra.json を修復して保存
//
// 対象: tool/verify_tsume_deep.dart が「エラー」とした問題のうち、局面が正しく
//       詰みが実在するもの。解答の初手が詰み手でない／受けが非合法 など。
//   - 局面自体が成立しない（行き所のない駒・駒数超過・後手玉が既に王手）問題は
//     修復できないので「除外候補」として一覧にし、--write では JSON から除く。
//   - 詰みが存在しない問題も「除外候補」。
// 内蔵問題（lib/tsume_builtin_problems.dart）は、修復案（解答の AMove 列）を表示するだけ。

import 'dart:convert';
import 'dart:io';

import 'package:shogi_app/logic.dart';
import 'package:shogi_app/piece.dart';
import 'package:shogi_app/tsume_builtin_problems.dart';
import 'package:shogi_app/tsume_judge.dart';

const _toCsa = {
  PieceType.king: 'OU',
  PieceType.rook: 'HI',
  PieceType.bishop: 'KA',
  PieceType.gold: 'KI',
  PieceType.silver: 'GI',
  PieceType.knight: 'KE',
  PieceType.lance: 'KY',
  PieceType.pawn: 'FU',
  PieceType.promotedRook: 'RY',
  PieceType.promotedBishop: 'UM',
  PieceType.promotedSilver: 'NG',
  PieceType.promotedKnight: 'NK',
  PieceType.promotedLance: 'NY',
  PieceType.promotedPawn: 'TO',
};
final _fromCsa = {for (final e in _toCsa.entries) e.value: e.key};

const _limit = {
  PieceType.pawn: 18,
  PieceType.lance: 4,
  PieceType.knight: 4,
  PieceType.silver: 4,
  PieceType.gold: 4,
  PieceType.bishop: 2,
  PieceType.rook: 2,
};

bool same(AMove a, AMove b) =>
    a.fr == b.fr &&
    a.fc == b.fc &&
    a.tr == b.tr &&
    a.tc == b.tc &&
    a.drop == b.drop &&
    a.promote == b.promote;

String sq(int r, int c) => '${9 - c}${'一二三四五六七八九'[r]}';
String mvStr(AMove m) => m.drop != null
    ? '${sq(m.tr, m.tc)}${m.drop!.name}打'
    : '${sq(m.fr, m.fc)}→${sq(m.tr, m.tc)}${m.promote ? '成' : ''}';

/// 局面が成立しているか。問題があれば理由を返す。
String? positionProblem(List<List<Piece?>> b, Map<PieceType, int> p1h, Map<PieceType, int> p2h) {
  final counts = <PieceType, int>{};
  int k2 = 0;
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 9; c++) {
      final x = b[r][c];
      if (x == null) continue;
      if (x.type == PieceType.king && !x.isPlayer1) k2++;
      counts[x.baseType] = (counts[x.baseType] ?? 0) + 1;
      if ((x.type == PieceType.pawn || x.type == PieceType.lance) &&
          ((x.isPlayer1 && r == 0) || (!x.isPlayer1 && r == 8))) {
        return '行き所のない${x.type.name} ${sq(r, c)}';
      }
      if (x.type == PieceType.knight &&
          ((x.isPlayer1 && r <= 1) || (!x.isPlayer1 && r >= 7))) {
        return '行き所のない桂 ${sq(r, c)}';
      }
    }
  }
  for (final h in [p1h, p2h]) {
    h.forEach((t, n) => counts[t] = (counts[t] ?? 0) + n);
  }
  for (final e in counts.entries) {
    final lim = _limit[e.key];
    if (lim != null && e.value > lim) return '駒数超過 ${e.key.name} ${e.value}枚';
  }
  if (k2 != 1) return '後手玉が$k2枚';
  for (final isP1 in [true, false]) {
    for (int c = 0; c < 9; c++) {
      int n = 0;
      for (int r = 0; r < 9; r++) {
        final x = b[r][c];
        if (x != null && x.type == PieceType.pawn && x.isPlayer1 == isP1) n++;
      }
      if (n > 1) return '二歩 ${9 - c}筋';
    }
  }
  if (GL.inCheck(b, false)) return '開始局面で後手玉が王手';
  return null;
}

/// 解答が検証を通るか（合法・攻め方は王手・手数一致・最後が詰み・初手が N手以内の詰み手）
bool solutionOk(TsumePos start, int moves, List<AMove> sol) {
  if (sol.length != moves || sol.isEmpty) return false;
  var cur = start;
  bool mover = true;
  for (final mv in sol) {
    if (!AI.allMoves(cur.b, mover, cur.p1h, cur.p2h).any((x) => same(x, mv))) return false;
    final n = AI.apply(cur.b, cur.p1h, cur.p2h, mv, mover);
    cur = tsumePos(n.b, n.p1h, n.p2h);
    if (mover && !GL.inCheck(cur.b, false)) return false;
    mover = !mover;
  }
  if (GL.hasLegalMove(cur.b, false, cur.p2h, cur.p1h)) return false;
  return tsumeFirstMoveMates(start, sol.first, moves);
}

/// 詰み手順を探索で作る。[preferred] の初手が詰み手ならそれを優先する。
List<AMove>? buildSolution(TsumePos start, int moves, AMove? preferred) {
  final sol = <AMove>[];
  var cur = start;
  int remaining = moves;
  while (true) {
    final cands = tsumeChecks(cur).where((m) => tsumeFirstMoveMates(cur, m, remaining)).toList();
    if (cands.isEmpty) return null;
    AMove pick = cands.first;
    if (sol.isEmpty && preferred != null) {
      final exact = cands.where((m) => same(m, preferred));
      final loose = cands.where((m) =>
          m.fr == preferred.fr && m.fc == preferred.fc && m.tr == preferred.tr && m.tc == preferred.tc && m.drop == preferred.drop);
      if (exact.isNotEmpty) {
        pick = exact.first;
      } else if (loose.isNotEmpty) {
        pick = loose.first;
      }
    }
    sol.add(pick);
    final n = AI.apply(cur.b, cur.p1h, cur.p2h, pick, true);
    final after = tsumePos(n.b, n.p1h, n.p2h);
    if (!GL.hasLegalMove(after.b, false, after.p2h, after.p1h)) return sol;
    remaining -= 2;
    final d = tsumeBestDefense(after, remaining);
    if (d == null) return sol;
    sol.add(d);
    final n2 = AI.apply(after.b, after.p1h, after.p2h, d, false);
    cur = tsumePos(n2.b, n2.p1h, n2.p2h);
  }
}

Map<String, dynamic> moveJson(AMove m) => {
      'fr': m.fr,
      'fc': m.fc,
      'tr': m.tr,
      'tc': m.tc,
      if (m.drop != null) 'drop': _toCsa[m.drop],
      if (m.promote) 'promote': true,
    };

void main(List<String> args) {
  final write = args.contains('--write');
  var repaired = 0, dropped = 0, ok = 0;

  // ── JSON ──
  final f = File('assets/tsume_extra.json');
  final list = jsonDecode(f.readAsStringSync()) as List<dynamic>;
  final out = <dynamic>[];
  for (final e in list) {
    final j = e as Map<String, dynamic>;
    if (j['board'] == null) {
      out.add(j);
      continue;
    }
    final raw = (j['board'] as List<dynamic>).cast<String>();
    final b = List.generate(9, (_) => List<Piece?>.filled(9, null));
    for (int i = 0; i < 81; i++) {
      final s = raw[i];
      if (s.isEmpty) continue;
      final t = _fromCsa[s.substring(1)];
      if (t != null) b[i ~/ 9][i % 9] = Piece(t, s[0] == '+');
    }
    Map<PieceType, int> hand(Map<String, dynamic>? m) => {
          if (m != null)
            for (final x in m.entries)
              if (_fromCsa[x.key] != null) _fromCsa[x.key]!: x.value as int
        };
    final p1h = hand(j['p1Hand'] as Map<String, dynamic>?);
    final p2h = hand(j['p2Hand'] as Map<String, dynamic>?);
    final moves = j['moves'] as int;
    final title = '${j['title']}(${j['id']})';
    final sol = (j['solution'] as List<dynamic>).map((x) {
      final m = x as Map<String, dynamic>;
      return AMove(
        fr: m['fr'] as int? ?? -1,
        fc: m['fc'] as int? ?? -1,
        tr: m['tr'] as int,
        tc: m['tc'] as int,
        drop: m['drop'] != null ? _fromCsa[m['drop'] as String] : null,
        promote: m['promote'] as bool? ?? false,
      );
    }).toList();
    final start = tsumePos(b, p1h, p2h);
    final pp = positionProblem(b, p1h, p2h);
    if (pp != null) {
      stdout.writeln('DROP   $title: 局面不成立（$pp）');
      dropped++;
      continue; // 除外
    }
    if (solutionOk(start, moves, sol)) {
      ok++;
      out.add(j);
      continue;
    }
    final fixed = buildSolution(start, moves, sol.isEmpty ? null : sol.first);
    if (fixed == null) {
      stdout.writeln('DROP   $title: $moves手以内の詰みが存在しない');
      dropped++;
      continue;
    }
    stdout.writeln('REPAIR $title: ${sol.map(mvStr).join(' ')}  →  ${fixed.map(mvStr).join(' ')}');
    j['solution'] = fixed.map(moveJson).toList();
    out.add(j);
    repaired++;
  }
  stdout.writeln('JSON: 正常 $ok / 修復 $repaired / 除外 $dropped');
  if (write) {
    f.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(out)}\n');
    stdout.writeln('assets/tsume_extra.json を更新しました');
  }

  // ── 内蔵（表示のみ）──
  for (final p in buildTsumeProblems(skipStartPositionFilter: true)) {
    final start = tsumePos(p.board, Map.of(p.p1Hand), Map.of(p.p2Hand));
    final pp = positionProblem(p.board, p.p1Hand, p.p2Hand);
    if (pp != null) {
      stdout.writeln('BUILTIN DROP   [${p.title}]: 局面不成立（$pp）');
      continue;
    }
    if (solutionOk(start, p.moves, p.solution)) continue;
    final fixed = buildSolution(start, p.moves, p.solution.isEmpty ? null : p.solution.first);
    if (fixed == null) {
      stdout.writeln('BUILTIN DROP   [${p.title}]: ${p.moves}手以内の詰みが存在しない');
    } else {
      stdout.writeln('BUILTIN REPAIR [${p.title}]: ${p.solution.map(mvStr).join(' ')}  →  ${fixed.map(mvStr).join(' ')}');
      stdout.writeln('   solution: [${fixed.map((m) => 'AMove(fr: ${m.fr}, fc: ${m.fc}, tr: ${m.tr}, tc: ${m.tc}${m.drop != null ? ', drop: PieceType.${m.drop!.name}' : ''}${m.promote ? ', promote: true' : ''})').join(', ')}]');
    }
  }
}
