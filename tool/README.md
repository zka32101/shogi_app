# tool/ — データ検証ツール

問題データ（詰将棋・手筋）を **追加・編集したら必ず実行する**。

| コマンド | 内容 | 目安 |
|---|---|---|
| `dart run tool/verify_tsume_deep.dart` | 詰将棋（内蔵+`assets/tsume_extra.json`）の厳密検証。局面の妥当性・解答手順・短手数詰め・解答初手・余詰 | 約10秒 |
| `dart run tool/repair_tsume.dart` | 診断（書き換えなし）。解答が誤りの問題は探索で再計算案を出し、局面が成立しない／詰みが無い問題を「DROP」として列挙 | 数秒 |
| `dart run tool/repair_tsume.dart --write` | `assets/tsume_extra.json` を修復（DROPは除外）して保存。内蔵問題は表示のみなので手で直す | 数秒 |
| `dart run tool/verify_tesuji.dart` | 手筋トレーニング（`lib/tesuji_problems.dart`）の検証。正解手の合法性・詰め問題の詰み・AI探索との比較 | 約7分 |

- 検証の中核は `lib/tsume_verify.dart` / `lib/tsume_judge.dart`（アプリの画面も `tsume_judge.dart` を使う）。
- `flutter test`（`test/tsume_data_test.dart`）でも同じ検証が走る。CIで落ちたら問題データが壊れている。
- 余詰（初手の別解）は警告のみ。アプリは「詰み手ならどれでも正解」と判定するので遊びには影響しない。
- `verify_tesuji` の WARN は「疑い」。AIの最善手が詰みや大きな駒得で、データの正解より強い手がある場合に出る。
  画面側は別解も受け入れる（`tesuji_screen.dart`）。

## 手筋問題の仕分け（tool/triage_tesuji.dart / tool/inspect_tesuji.dart）

- `dart run tool/triage_tesuji.dart` — 全問を「正解手の3手読み損得」で OK / WEAK / BAD に仕分ける（約5分）。
  捨て駒・守りは最初に駒損になるのが正しいことがあるため BAD でも即不正解とは限らない。
  飛車取り・王手金取り・両取りで BAD は成立していない問題。
- `dart run tool/inspect_tesuji.dart <id>...` — 盤面・正解手・相手の最善応手・AI上位手を表示する。
- 成立していない問題は `lib/tesuji_problems.dart` 末尾の `excluded` で出題から外している（直したら外す）。
  2026-10 時点: 102問 → 82問（20問を除外）。

## 手筋問題は「全駒配置」が原則（2026-10 方針）

盤上に数枚しか駒が無いと「どこが狙いか」が一目で分かってしまう。**手筋問題は初期配置に近い全駒配置（目安: 盤上 30枚前後・各陣営とも玉+金銀桂香歩の囲い・飛角・歩列）で作る**。問題を追加するときも同じ。

- `lib/tesuji_problems.dart` の各問題は「手筋に必要な最小の駒」だけを書く（素の問題）。
  盤面に足す駒は `lib/tesuji_fill.dart`（`tesujiFill`: id → `"行 列 駒;..."`）に分けてあり、`buildTesujiProblems()` が自動で足す。
  素の問題だけ欲しいときは `buildTesujiProblems(applyFill: false)`。
- `dart run tool/densify_tesuji.dart --out tool/out/fill_0.txt [--part 0/12] [--ids a,b] [--tries 6]` が、空きマスに囲い・歩列・香桂・金銀・飛角を足す。
  二歩・行き所のない駒・駒の総数超過（持ち駒も数える）・新たな王手は作らない。1枚ごとに「正解手の3手読み駒得が素の問題以上」を確認し、
  最後に「正解より強い別手が新たに生まれていないか」「AI(深さ4)の上位6手に入るか」（詰めは詰み確認）を厳密検査して、失敗したら別配置を試す。
  `--merge tool/out/fill_*.txt` で `lib/tesuji_fill.dart` を再生成する（`tool/out/` はコミットしない）。
- 新しい問題を足したら、素の問題を書く → `densify_tesuji` で全駒配置にする → `verify_tesuji` を通す、の順。
  densify しても成立しない問題（駒を足すと手筋が崩れる）は `excluded` に入れる。
- 「狙いの周りだけ空白」の偏りを避けるため、駒は盤全体にバランスよく置く。囮（取れそうで取れない駒）が増えるのは構わないが、正解は最善であること。
