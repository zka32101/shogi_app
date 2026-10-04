// 詰将棋データの厳密検証（lib/tsume_verify.dart）をCIで実行する。
// 問題を追加・編集して壊すと、このテストが落ちる。
// 詳細な一覧は `dart run tool/verify_tsume_deep.dart` で確認できる。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shogi_app/tsume_builtin_problems.dart';
import 'package:shogi_app/tsume_verify.dart';

void main() {
  test('内蔵の詰将棋: 局面が成立し、解答が正しく詰む', () {
    final problems = [
      for (final p in buildTsumeProblems(skipStartPositionFilter: true))
        Prob(p.title, p.moves, p.board, p.p1Hand, p.p2Hand, p.solution),
    ];
    final r = verifyTsumeProblems(problems);
    expect(r.errors, isEmpty, reason: r.errors.join('\n'));
  });

  test('assets/tsume_extra.json: 局面が成立し、解答が正しく詰む', () {
    final problems = loadTsumeJson(File('assets/tsume_extra.json').readAsStringSync());
    expect(problems.length, greaterThan(100));
    final r = verifyTsumeProblems(problems);
    expect(r.errors, isEmpty, reason: r.errors.join('\n'));
  });
}
