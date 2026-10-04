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
