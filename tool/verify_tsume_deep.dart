// tool/verify_tsume_deep.dart — 詰将棋データの厳密検証 CLI（詳細は lib/tsume_verify.dart）
//
// 実行:   dart run tool/verify_tsume_deep.dart            # 内蔵+JSONの全問題
//         dart run tool/verify_tsume_deep.dart --builtin   # 内蔵のみ
//         dart run tool/verify_tsume_deep.dart --json      # assets/tsume_extra.json のみ
//         dart run tool/verify_tsume_deep.dart --strict    # 余詰も失敗扱い
// 終了コード: 0=問題なし / 1=エラーあり

import 'dart:io';

import 'package:shogi_app/tsume_builtin_problems.dart';
import 'package:shogi_app/tsume_verify.dart';

void main(List<String> args) {
  final strict = args.contains('--strict');
  final problems = <Prob>[];
  if (!args.contains('--json')) {
    for (final p in buildTsumeProblems(skipStartPositionFilter: true)) {
      problems.add(Prob(p.title, p.moves, p.board, p.p1Hand, p.p2Hand, p.solution));
    }
  }
  if (!args.contains('--builtin')) {
    final f = File('assets/tsume_extra.json');
    if (f.existsSync()) problems.addAll(loadTsumeJson(f.readAsStringSync()));
  }
  final r = verifyTsumeProblems(problems);
  stdout.writeln('検証した問題数: ${problems.length}');
  stdout.writeln('エラー ${r.errors.length} 件 / 余詰警告 ${r.warnings.length} 件');
  for (final s in r.errors) {
    stdout.writeln(' ERROR $s');
  }
  for (final s in r.warnings) {
    stdout.writeln(' WARN  $s');
  }
  exit(r.errors.isEmpty && (!strict || r.warnings.isEmpty) ? 0 : 1);
}
