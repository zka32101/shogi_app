import 'dart:io';
import 'package:shogi_app/piece.dart';
import 'package:shogi_app/tsume_builtin_problems.dart';
import 'package:shogi_app/tsume_verify.dart';

void main() {
  final ps = <Prob>[];
  for (final p in buildTsumeProblems(skipStartPositionFilter: true)) {
    ps.add(Prob(p.title, p.moves, p.board, p.p1Hand, p.p2Hand, p.solution));
  }
  ps.addAll(loadTsumeJson(File('assets/tsume_extra.json').readAsStringSync()));
  int k1 = 0, h2 = 0, h1 = 0;
  final byMoves = <int, int>{};
  for (final p in ps) {
    bool hasK1 = false;
    for (final r in p.board) for (final x in r) {
      if (x != null && x.type == PieceType.king && x.isPlayer1) hasK1 = true;
    }
    if (hasK1) k1++;
    if (p.p2Hand.values.any((v) => v > 0)) h2++;
    if (p.p1Hand.values.any((v) => v > 0)) h1++;
    byMoves[p.moves] = (byMoves[p.moves] ?? 0) + 1;
  }
  stdout.writeln('total=${ps.length} attackerKingOnBoard=$k1 defenderHand=$h2 attackerHand=$h1 byMoves=$byMoves');
}
