// tool/verify_tesuji.dart — 手筋トレーニング問題の検証（今後も問題追加時に実行する）
//
// 実行: dart run tool/verify_tesuji.dart            # 全問題
//       dart run tool/verify_tesuji.dart --verbose  # 同等の別解も表示
//
// 終了コード: 0=エラーなし / 1=エラーあり（WARN は人が確認する指標）
//
// 画面（tesuji_screen.dart）は「正解手と座標が一致するか」だけで判定するため、
// 次を調べる:
//   ERROR  正解手が非合法 / 詰め問題なのに正解手が詰み手でない
//   WARN   正解手がAI探索(深さ4)の上位6手に入らない（最善でない疑い）
//   WARN   駒得になるはずの種類（飛車取り・王手金取り・両取り）なのに駒得が負
//   INFO   同等に良い別手（--verbose）。画面が不正解扱いにする手
//
// 評価は「3手読みの駒の損得」: 自分の手 → 相手の全ての応手 → 自分の最善の取り返し。
// 簡易評価なので WARN は“疑い”であり、最終判断は人が盤面で確認すること。

import 'dart:io';

import 'package:shogi_app/logic.dart';
import 'package:shogi_app/piece.dart';
import 'package:shogi_app/tesuji_problems.dart';
import 'package:shogi_app/tsume_judge.dart';

const _value = {
  PieceType.pawn: 1,
  PieceType.lance: 3,
  PieceType.knight: 3,
  PieceType.silver: 5,
  PieceType.gold: 6,
  PieceType.bishop: 8,
  PieceType.rook: 10,
  PieceType.promotedPawn: 4,
  PieceType.promotedLance: 5,
  PieceType.promotedKnight: 5,
  PieceType.promotedSilver: 6,
  PieceType.promotedBishop: 10,
  PieceType.promotedRook: 12,
  PieceType.king: 0,
};

int _v(PieceType t) => _value[t] ?? 0;

/// [p1] 視点の駒の損得（盤上+持ち駒）
int material(List<List<Piece?>> b, Map<PieceType, int> p1h, Map<PieceType, int> p2h) {
  int s = 0;
  for (final row in b) {
    for (final x in row) {
      if (x == null) continue;
      s += x.isPlayer1 ? _v(x.type) : -_v(x.type);
    }
  }
  p1h.forEach((t, n) => s += _v(t) * n);
  p2h.forEach((t, n) => s -= _v(t) * n);
  return s;
}

typedef Pos = ({List<List<Piece?>> b, Map<PieceType, int> p1h, Map<PieceType, int> p2h});

Pos apply(Pos p, AMove m, bool p1) {
  final n = AI.apply(p.b, p.p1h, p.p2h, m, p1);
  return (b: n.b, p1h: n.p1h, p2h: n.p2h);
}

/// [me] 視点の損得（+なら me が得）
int diff(Pos p, bool me) => me ? material(p.b, p.p1h, p.p2h) : -material(p.b, p.p1h, p.p2h);

const mateScore = 9999;

/// 手 [m] の価値: 相手の最善の応手の後、自分が最善に取り返した損得（3手読み）
int valueOf(Pos start, AMove m, bool me) {
  final after = apply(start, m, me);
  if (GL.inCheck(after.b, !me) &&
      !GL.hasLegalMove(after.b, !me, me ? after.p2h : after.p1h, me ? after.p1h : after.p2h)) {
    return mateScore;
  }
  final replies = AI.allMoves(after.b, !me, after.p1h, after.p2h);
  if (replies.isEmpty) return diff(after, me);
  int worst = 1 << 30;
  for (final d in replies) {
    final p2 = apply(after, d, !me);
    int best = diff(p2, me);
    for (final n in AI.allMoves(p2.b, me, p2.p1h, p2.p2h)) {
      final tgt = n.drop == null ? p2.b[n.tr][n.tc] : null;
      if (tgt == null && n.drop == null) continue; // 取りだけを読む
      final p3 = apply(p2, n, me);
      final v = diff(p3, me);
      if (v > best) best = v;
    }
    if (best < worst) worst = best;
  }
  return worst;
}

bool sameMove(AMove a, AMove b) =>
    a.fr == b.fr && a.fc == b.fc && a.tr == b.tr && a.tc == b.tc && a.drop == b.drop && a.promote == b.promote;

String sq(int r, int c) => '${9 - c}${'一二三四五六七八九'[r]}';
String mvStr(AMove m) => m.drop != null
    ? '${sq(m.tr, m.tc)}${m.drop!.name}打'
    : '${sq(m.fr, m.fc)}→${sq(m.tr, m.tc)}${m.promote ? '成' : ''}';

const _aiDepth = 4;

// 「駒得になるはず」のカテゴリ（最低限の期待値）
const _expectGain = {'飛車取り': 4, '王手金取り': 4, '両取り': 2};

void main(List<String> args) {
  final verbose = args.contains('--verbose');
  final probs = buildTesujiProblems();
  int errors = 0, warns = 0;
  void out(String level, TesujiProb p, String msg) {
    stdout.writeln(' $level [${p.id} ${p.category}/${p.title}] $msg');
    if (level == 'ERROR') errors++;
    if (level == 'WARN ') warns++;
  }

  for (final p in probs) {
    final me = p.p1Turn;
    final start = (b: p.board, p1h: Map.of(p.p1Hand), p2h: Map.of(p.p2Hand));

    // 基本の整合
    final moves = AI.allMoves(p.board, me, start.p1h, start.p2h);
    if (!moves.any((m) => sameMove(m, p.answer))) {
      // 成りの有無だけが違う場合は別メッセージ
      final loose = moves.any((m) =>
          m.fr == p.answer.fr && m.fc == p.answer.fc && m.tr == p.answer.tr && m.tc == p.answer.tc && m.drop == p.answer.drop);
      out('ERROR', p, loose ? '正解手の成り指定が不正 (${mvStr(p.answer)})' : '正解手 ${mvStr(p.answer)} が非合法');
      continue;
    }

    // 詰め問題: 正解手は詰み手のはず
    if (p.category == '詰め') {
      if (!me) {
        out('WARN ', p, '後手番の詰め問題は未検証');
      } else {
        final pos = tsumePos(p.board, start.p1h, start.p2h);
        final dist = tsumeMateDistance(pos, 7);
        if (dist == null) {
          out('ERROR', p, '詰めの問題だが7手以内の詰みが存在しない');
        } else if (!tsumeFirstMoveMates(pos, p.answer, dist)) {
          out('ERROR', p, '正解手 ${mvStr(p.answer)} は最短$dist手詰めの初手ではない');
        }
      }
      continue;
    }

    // AI探索（深さ _aiDepth）の上位候補に正解手が入るか
    final top = AI.topMoves(p.board, start.p1h, start.p2h, me, _aiDepth, n: 6);
    final rank = top.indexWhere((e) => sameMove(e.$1, p.answer));
    if (top.isNotEmpty && rank < 0) {
      final t = top.first;
      out('WARN ', p,
          '正解 ${mvStr(p.answer)} はAI(深さ$_aiDepth)の上位6手に無い。AI最善=${mvStr(t.$1)}(評価${t.$2})');
    } else if (rank > 0 && verbose) {
      out('INFO ', p, '正解はAIの${rank + 1}番手 (最善=${mvStr(top.first.$1)})');
    }

    // 駒の損得（3手読み）— 「駒得になるはず」の種類だけ、明らかな駒損をERRORにしない警告で出す
    final base = diff(start, me);
    final gain = valueOf(start, p.answer, me) - base;
    final need = _expectGain[p.category];
    if (need != null && gain < 0) {
      out('WARN ', p, '駒得にならない疑い: 正解手 ${mvStr(p.answer)} の3手読みの駒得 $gain');
    }
    if (verbose) {
      final equal = <String>[];
      final ansV = gain + base;
      for (final m in moves) {
        if (sameMove(m, p.answer)) continue;
        if (valueOf(start, m, me) >= ansV) equal.add(mvStr(m));
      }
      if (equal.isNotEmpty) out('INFO ', p, '3手読みで同等以上の別手 ${equal.length}: ${equal.take(6).join(', ')}');
    }
  }

  stdout.writeln('検証した問題数: ${probs.length}  ERROR $errors / WARN $warns');
  exit(errors == 0 ? 0 : 1);
}
