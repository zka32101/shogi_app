// tool/densify_tesuji.dart — 手筋問題を「全駒配置」にする（再現可能・純Dart）
//
// 方針: 素の問題（applyFill:false）に、玉の囲い・歩の列・香桂・金銀・飛角を足していく。
//   * 既存の駒は動かさない。二歩・行き所のない駒・総数超過・新たな王手は作らない。
//   * 1枚足すごとに「正解手の3手読み駒得が素の問題以上」を確認する（詰めは最後に詰み確認）。
//   * 最後に厳密検査: 正解より明確に強い別手が新たに生まれていないか／AI(深さ4)の上位6手に入るか。
//   * 失敗したら乱数シードを変えて別配置を試す。駒数が多い成功配置を採用する。
//
// 実行:
//   dart run tool/densify_tesuji.dart --out tool/out/fill_0.txt [--part 0/4] [--ids a,b] [--tries 6]
//   dart run tool/densify_tesuji.dart --merge tool/out/fill_*.txt   # lib/tesuji_fill.dart を生成
// 出力は 1行1問: id<TAB>ok|ng<TAB>駒数<TAB>fill文字列/理由
import 'dart:io';
import 'dart:math';

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
const _total = {
  PieceType.pawn: 18, PieceType.lance: 4, PieceType.knight: 4, PieceType.silver: 4,
  PieceType.gold: 4, PieceType.bishop: 2, PieceType.rook: 2,
};
const _ch = {
  PieceType.king: 'K', PieceType.rook: 'R', PieceType.bishop: 'B', PieceType.gold: 'G',
  PieceType.silver: 'S', PieceType.knight: 'N', PieceType.lance: 'L', PieceType.pawn: 'P',
};

typedef Pos = ({List<List<Piece?>> b, Map<PieceType, int> p1h, Map<PieceType, int> p2h});

int mat(Pos p) {
  int s = 0;
  for (final r in p.b) {
    for (final x in r) {
      if (x != null) s += x.isPlayer1 ? (_val[x.type] ?? 0) : -(_val[x.type] ?? 0);
    }
  }
  p.p1h.forEach((t, n) => s += (_val[t] ?? 0) * n);
  p.p2h.forEach((t, n) => s -= (_val[t] ?? 0) * n);
  return s;
}

Pos ap(Pos p, AMove m, bool p1) {
  final n = AI.apply(p.b, p.p1h, p.p2h, m, p1);
  return (b: n.b, p1h: n.p1h, p2h: n.p2h);
}

int d(Pos p, bool me) => me ? mat(p) : -mat(p);

int valueOf(Pos s, AMove m, bool me) {
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

bool same(AMove a, AMove b) =>
    a.fr == b.fr && a.fc == b.fc && a.tr == b.tr && a.tc == b.tc && a.drop == b.drop && a.promote == b.promote;
String key(AMove m) => '${m.fr},${m.fc},${m.tr},${m.tc},${m.drop?.index ?? -1},${m.promote}';

PieceType base(PieceType t) => switch (t) {
      PieceType.promotedRook => PieceType.rook,
      PieceType.promotedBishop => PieceType.bishop,
      PieceType.promotedSilver => PieceType.silver,
      PieceType.promotedKnight => PieceType.knight,
      PieceType.promotedLance => PieceType.lance,
      PieceType.promotedPawn => PieceType.pawn,
      _ => t,
    };

Map<PieceType, int> remaining(Pos p) {
  final rem = Map<PieceType, int>.of(_total);
  for (final r in p.b) {
    for (final x in r) {
      if (x != null && x.type != PieceType.king) rem[base(x.type)] = (rem[base(x.type)] ?? 0) - 1;
    }
  }
  for (final h in [p.p1h, p.p2h]) {
    h.forEach((t, n) => rem[base(t)] = (rem[base(t)] ?? 0) - n);
  }
  return rem;
}

typedef Cand = ({int r, int c, PieceType t, bool p1});

bool placeable(List<List<Piece?>> b, Cand x) {
  if (x.r < 0 || x.r > 8 || x.c < 0 || x.c > 8 || b[x.r][x.c] != null) return false;
  switch (x.t) {
    case PieceType.pawn:
      if (x.p1 ? x.r == 0 : x.r == 8) return false;
      for (int r = 0; r < 9; r++) {
        final q = b[r][x.c];
        if (q != null && q.type == PieceType.pawn && q.isPlayer1 == x.p1) return false;
      }
    case PieceType.lance:
      if (x.p1 ? x.r == 0 : x.r == 8) return false;
    case PieceType.knight:
      if (x.p1 ? x.r <= 1 : x.r >= 7) return false;
    default:
  }
  return true;
}

List<Cand> candidates(List<List<Piece?>> b, bool p1, Pos start, Random rnd, Map<PieceType, int> rem) {
  final out = <Cand>[];
  final f = p1 ? -1 : 1; // 前進方向
  final home = p1 ? 8 : 0;
  final k = GL.kingPos(b, p1);
  void add(int r, int c, PieceType t) => out.add((r: r, c: c, t: t, p1: p1));
  // 1) 玉の囲い（前3マス・横・斜め後ろ）
  if (k != null) {
    final kr = k.$1, kc = k.$2;
    final guards = <Cand>[];
    guards.add((r: kr + f, c: kc, t: PieceType.gold, p1: p1));
    guards.add((r: kr + f, c: kc - 1, t: PieceType.silver, p1: p1));
    guards.add((r: kr + f, c: kc + 1, t: PieceType.silver, p1: p1));
    guards.add((r: kr, c: kc - 1, t: PieceType.gold, p1: p1));
    guards.add((r: kr, c: kc + 1, t: rnd.nextBool() ? PieceType.gold : PieceType.silver, p1: p1));
    guards.add((r: kr - f, c: kc - 1, t: PieceType.silver, p1: p1));
    guards.add((r: kr - f, c: kc + 1, t: PieceType.gold, p1: p1));
    guards.add((r: kr + f, c: kc + (rnd.nextBool() ? 2 : -2), t: PieceType.pawn, p1: p1));
    // 先頭の数枚は固定順（囲いらしさ）、残りは散らす
    out.addAll(guards.take(3));
    final rest = guards.skip(3).toList()..shuffle(rnd);
    out.addAll(rest);
  }
  // 2) 歩の列
  final cols = List.generate(9, (i) => i)..shuffle(rnd);
  for (final c in cols) {
    final row = p1 ? 6 : 2;
    add(row, c, PieceType.pawn);
    final adv = p1 ? 5 : 3;
    if (rnd.nextInt(5) == 0) out.insert(out.length - 1, (r: adv, c: c, t: PieceType.pawn, p1: p1));
  }
  // 3) 香・桂
  for (final c in [0, 8]) {
    add(home, c, PieceType.lance);
  }
  for (final c in [1, 7]) {
    add(home, c, PieceType.knight);
  }
  // 4) 金銀の初期位置（残り）
  for (final c in [3, 5, 2, 6]) {
    add(home, c, c == 3 || c == 5 ? PieceType.gold : PieceType.silver);
  }
  for (final c in [2, 6, 3, 5]) {
    add(home + f, c, c == 2 || c == 6 ? PieceType.silver : PieceType.gold);
  }
  // 5) 飛・角（盤上・持ち駒にその陣営が持っていなければ）
  bool has(PieceType t) {
    for (final r in b) {
      for (final x in r) {
        if (x != null && base(x.type) == t && x.isPlayer1 == p1) return true;
      }
    }
    return (p1 ? start.p1h : start.p2h)[t] != null && (p1 ? start.p1h : start.p2h)[t]! > 0;
  }
  if (!has(PieceType.rook)) add(home + f, p1 ? 7 : 1, PieceType.rook);
  if (!has(PieceType.bishop)) add(home + f, p1 ? 1 : 7, PieceType.bishop);
  return out;
}

int count(List<List<Piece?>> b) {
  int n = 0;
  for (final r in b) {
    for (final x in r) {
      if (x != null) n++;
    }
  }
  return n;
}

String fillStr(List<List<Piece?>> orig, List<List<Piece?>> b) {
  final parts = <String>[];
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 9; c++) {
      if (orig[r][c] == null && b[r][c] != null) {
        final ch = _ch[b[r][c]!.type]!;
        parts.add('$r $c ${b[r][c]!.isPlayer1 ? ch : ch.toLowerCase()}');
      }
    }
  }
  return parts.join(';');
}

/// 1問を処理して (ok, 駒数, fill文字列 or 理由)
(bool, int, String) densify(TesujiProb p, int tries) {
  final me = p.p1Turn;
  final start0 = (b: p.board, p1h: Map<PieceType, int>.of(p.p1Hand), p2h: Map<PieceType, int>.of(p.p2Hand));
  final isTsume = p.category == '詰め';
  final baseGain = isTsume ? 0 : valueOf(start0, p.answer, me) - d(start0, me);
  // 素の問題で既に「正解より強い」とされる別手（これは許容）
  final betterBase = <String>{};
  int bestBaseAlt = 0;
  int? baseRank;
  if (!isTsume) {
    for (final m in AI.allMoves(p.board, me, start0.p1h, start0.p2h)) {
      if (same(m, p.answer)) continue;
      final gv = valueOf(start0, m, me) - d(start0, me);
      if (gv > baseGain) betterBase.add(key(m));
      if (gv > bestBaseAlt) bestBaseAlt = gv;
    }
    final top = AI.topMoves(p.board, Map.of(start0.p1h), Map.of(start0.p2h), me, 4, n: 6);
    final i = top.indexWhere((e) => same(e.$1, p.answer));
    baseRank = i;
  }
  final chk0 = (GL.inCheck(p.board, true), GL.inCheck(p.board, false));
  String lastReason = 'no-try';
  (bool, int, String)? best;
  for (int seed = 0; seed < tries; seed++) {
    final rnd = Random(p.id.hashCode * 31 + seed);
    final b = [for (final r in p.board) List<Piece?>.of(r)];
    final rem = remaining(start0);
    final l1 = candidates(b, true, start0, rnd, rem);
    final l2 = candidates(b, false, start0, rnd, rem);
    final order = <Cand>[];
    for (int i = 0; i < max(l1.length, l2.length); i++) {
      if (i < l1.length) order.add(l1[i]);
      if (i < l2.length) order.add(l2[i]);
    }
    for (final x in order) {
      if ((rem[x.t] ?? 0) <= 0 || !placeable(b, x)) continue;
      b[x.r][x.c] = Piece(x.t, x.p1);
      bool ok = (GL.inCheck(b, true), GL.inCheck(b, false)) == chk0;
      if (ok && isTsume) {
        final pos = tsumePos(b, start0.p1h, start0.p2h);
        final dist = tsumeMateDistance(pos, 7);
        ok = dist != null && tsumeFirstMoveMates(pos, p.answer, dist);
      }
      if (ok && !isTsume) {
        final s = (b: b, p1h: start0.p1h, p2h: start0.p2h);
        final moves = AI.allMoves(b, me, s.p1h, s.p2h);
        ok = moves.any((m) => same(m, p.answer)) &&
            valueOf(s, p.answer, me) - d(s, me) >= baseGain;
      }
      if (ok) {
        rem[x.t] = rem[x.t]! - 1;
      } else {
        b[x.r][x.c] = null;
      }
    }
    final n = count(b);
    final s = (b: b, p1h: start0.p1h, p2h: start0.p2h);
    // 厳密検査
    String? fail;
    if (isTsume) {
      final pos = tsumePos(b, s.p1h, s.p2h);
      final dist = tsumeMateDistance(pos, 7);
      if (dist == null) {
        fail = 'tsume: no mate';
      } else if (!tsumeFirstMoveMates(pos, p.answer, dist)) {
        fail = 'tsume: answer not first move';
      }
    } else {
      final g = valueOf(s, p.answer, me) - d(s, me);
      for (final m in AI.allMoves(b, me, s.p1h, s.p2h)) {
        if (same(m, p.answer)) continue;
        if (valueOf(s, m, me) - d(s, me) > (bestBaseAlt < baseGain + 2 ? g + 1 : max(g, bestBaseAlt)) && !betterBase.contains(key(m))) {
          fail = 'alt stronger move ${key(m)}';
          break;
        }
      }
      if (fail == null && baseRank != null && baseRank >= 0) {
        final top = AI.topMoves(b, Map.of(s.p1h), Map.of(s.p2h), me, 4, n: 6);
        if (!top.any((e) => same(e.$1, p.answer))) fail = 'AI top6 miss';
      }
    }
    if (fail == null) {
      final r = (true, n, fillStr(p.board, b));
      if (best == null || n > best.$2) best = r;
      if (n >= 30) break;
    } else {
      lastReason = fail;
    }
  }
  return best ?? (false, count(p.board), lastReason);
}

void main(List<String> args) {
  String? opt(String n) {
    final i = args.indexOf(n);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  if (args.contains('--merge')) {
    final files = args.skip(args.indexOf('--merge') + 1).toList();
    final map = <String, String>{};
    for (final f in files) {
      for (final line in File(f).readAsLinesSync()) {
        final t = line.split('\t');
        if (t.length >= 4 && t[1] == 'ok') map[t[0]] = t[3];
      }
    }
    final ids = map.keys.toList()..sort();
    final sb = StringBuffer('// 自動生成: tool/densify_tesuji.dart（手作業で編集しない）\n');
    sb.writeln('// 形式: "行 列 SFEN文字;..."（大文字=先手）。素の問題に足す駒。');
    sb.writeln('const Map<String, String> tesujiFill = {');
    for (final id in ids) {
      sb.writeln("  '$id': '${map[id]}',");
    }
    sb.writeln('};');
    File('lib/tesuji_fill.dart').writeAsStringSync(sb.toString());
    stdout.writeln('merged ${ids.length} problems');
    return;
  }

  final tries = int.parse(opt('--tries') ?? '6');
  var probs = buildTesujiProblems(applyFill: false);
  final idsArg = opt('--ids');
  if (idsArg != null) {
    final set = idsArg.split(',').toSet();
    probs = probs.where((p) => set.contains(p.id)).toList();
  }
  final part = opt('--part');
  if (part != null) {
    final t = part.split('/');
    final i = int.parse(t[0]), n = int.parse(t[1]);
    probs = [for (int k = 0; k < probs.length; k++) if (k % n == i) probs[k]];
  }
  final outFile = opt('--out');
  final sink = outFile == null ? null : File(outFile);
  sink?.createSync(recursive: true);
  sink?.writeAsStringSync('');
  for (final p in probs) {
    final sw = Stopwatch()..start();
    final r = densify(p, tries);
    final line = '${p.id}\t${r.$1 ? 'ok' : 'ng'}\t${r.$2}\t${r.$3}';
    stdout.writeln('${line.length > 150 ? line.substring(0, 150) : line}  (${sw.elapsed.inSeconds}s)');
    sink?.writeAsStringSync('$line\n', mode: FileMode.append);
  }
}
