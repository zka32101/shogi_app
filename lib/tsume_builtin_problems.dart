// lib/tsume_builtin_problems.dart
// tsume_screen.dart に埋め込まれていた内蔵詰将棋問題データを純Dartファイルへ分離。
// tsume_screen.dart は flutter/material.dart 等に依存するため `dart run` では
// コンパイルできず、tool/validate_tsume_screen.dart から検証できなかった。
// このファイルは piece.dart / logic.dart のみに依存する純Dartのため検証可能。

import 'piece.dart';
import 'logic.dart';

class TsumeProb {
  final String title;
  final int moves;
  final List<List<Piece?>> board;
  final Map<PieceType, int> p1Hand;
  final Map<PieceType, int> p2Hand;
  final bool p1Turn;
  // 手順: 偶数インデックス(0,2,4)=先手の手、奇数インデックス(1,3)=後手の応手
  final List<AMove> solution;
  final String explanation;

  const TsumeProb({
    required this.title,
    required this.moves,
    required this.board,
    required this.p1Hand,
    required this.p2Hand,
    // ignore: unused_element_parameter
  this.p1Turn = true,
    required this.solution,
    this.explanation = '',
  });
}

List<List<Piece?>> _empty() =>
    List.generate(9, (_) => List<Piece?>.filled(9, null));

List<TsumeProb> buildTsumeProblems({bool skipStartPositionFilter = false}) {
  final list = <TsumeProb>[];

  // ===== 1手詰め ① =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[0][1] = Piece(PieceType.silver, true);
    b[2][1] = Piece(PieceType.gold, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '1手詰め ①',
      moves: 1,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 2, fc: 1, tr: 1, tc: 0),
      ],
      explanation: '',
    ));
  }

  // ===== 1手詰め ② =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);
    b[2][8] = Piece(PieceType.gold, true);
    b[4][4] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '1手詰め ②',
      moves: 1,
      board: b,
      p1Hand: {PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 1, tc: 7, drop: PieceType.gold),
      ],
      explanation: '',
    ));
  }

  // ===== 1手詰め ③ =====
  // 先手龍で王手・詰め
  // (旧版は龍・金が共に開始局面から後手玉に王手をかけてしまう不正な局面だった。
  //  TsumeEngineでの検証により発覚・修正: 龍は斜め1マスで5二に踏み込み、
  //  桂馬が5二を紐付けする形に変更)
  // 後手玉 5一(0,4)、先手龍 4三(2,3)、先手桂 4四(3,3)
  // 手順: 龍 4三→5二(1,4)で王手（龍の八方効きで四方封鎖、桂が5二を守る）
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);          // 後手玉 5一(0,4)
    b[8][4] = Piece(PieceType.king, true);            // 先手玉 5九(8,4)
    b[2][3] = Piece(PieceType.promotedRook, true);   // 先手龍 4三(2,3)
    b[3][3] = Piece(PieceType.knight, true);          // 先手桂 4四(3,3) ← 5二を守る
    list.add(TsumeProb(
      title: '1手詰め ③',
      moves: 1,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 2, fc: 3, tr: 1, tc: 4), // 龍 4三→5二(斜め、王手・詰み)
      ],
      explanation: '',
    ));
  }

  // ===== 1手詰め ④ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[2][3] = Piece(PieceType.bishop, true);
    b[3][2] = Piece(PieceType.knight, true);
    b[5][3] = Piece(PieceType.promotedRook, true);
    b[8][4] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '1手詰め ④',
      moves: 1,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 5, fc: 3, tr: 5, tc: 0),
      ],
      explanation: '',
    ));
  }

  // ===== 1手詰め ⑤ =====
  // 持ち駒の銀を打って詰める
  // (旧版は金・飛が共に開始局面から王手をかけてしまう不正な局面だった。
  //  TsumeEngineでの検証により発覚・修正)
  // 後手玉 9一(0,8)、先手金 7三(2,7) ← 8二・9二を守る、先手銀 8三(1,6) ← 8一を守る
  // (金・銀だけで開始局面から後手玉の全逃げ場を封鎖してしまい、王手はして
  //  いないものの合法手が無い＝終端状態になっていたため、後手に歩を持たせて
  //  開始局面に合法手を残した)
  // 手順: 銀 8二(1,7)打ち
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);   // 後手玉 9一(0,8)
    b[8][8] = Piece(PieceType.king, true);    // 先手玉 9九(8,8)
    b[2][7] = Piece(PieceType.gold, true);    // 先手金 7三(2,7) ← 8二・9二を守る
    b[1][6] = Piece(PieceType.silver, true);  // 先手銀 8三(1,6) ← 8一を守る
    b[4][4] = Piece(PieceType.pawn, false);   // 後手歩（開始局面が終端状態になるのを防ぐ）
    list.add(TsumeProb(
      title: '1手詰め ⑤',
      moves: 1,
      board: b,
      p1Hand: {PieceType.silver: 1},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 1, tc: 7, drop: PieceType.silver), // 銀 8二打ち(王手・詰み)
      ],
      explanation: '',
    ));
  }

  // ===== 1手詰め ⑥ =====
  // (旧版は馬・金2枚・銀の全てが開始局面から王手をかけてしまう不正な局面
  //  だった。TsumeEngineでの検証により発覚・修正)
  // 後手玉 5一(0,4)、先手馬 5三(2,4)、先手金 7二(1,2) ← 4一・4二を守る、
  // 先手桂 3四(3,6) ← 6二を守る
  // 手順: 馬 5三→6二(1,5)で王手（馬の八方効きで四方封鎖、桂が6二を守る）
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);           // 後手玉 5一(0,4)
    b[8][4] = Piece(PieceType.king, true);             // 先手玉 5九(8,4)
    b[2][4] = Piece(PieceType.promotedBishop, true);   // 先手馬 5三(2,4)
    b[1][2] = Piece(PieceType.gold, true);             // 先手金 7二(1,2) ← 4一・4二を守る
    b[3][6] = Piece(PieceType.knight, true);           // 先手桂 3四(3,6) ← 6二を守る
    list.add(TsumeProb(
      title: '1手詰め ⑥',
      moves: 1,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 2, fc: 4, tr: 1, tc: 5), // 馬 5三→6二(斜め、王手・詰み)
      ],
      explanation: '',
    ));
  }

  // ===== 1手詰め ⑦ =====
  // 持ち駒の金を打って端玉を詰める
  // (旧版は金・飛が共に開始局面から王手をかけてしまう不正な局面だった。
  //  TsumeEngineでの検証により発覚・修正: 桂馬1枚で打った金を守る形に変更)
  // 後手玉 1一(0,0)、先手桂 2四(3,1) ← 1二を守る
  // 手順: 金 1二(1,0)打ち（金自身が2一・2二を利き、桂が金を守るため詰み）
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);   // 後手玉 1一(0,0)
    b[8][8] = Piece(PieceType.king, true);    // 先手玉 9九(8,8)
    b[3][1] = Piece(PieceType.knight, true);  // 先手桂 2四(3,1) ← 1二を守る
    list.add(TsumeProb(
      title: '1手詰め ⑦',
      moves: 1,
      board: b,
      p1Hand: {PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 1, tc: 0, drop: PieceType.gold), // 金 1二打ち(王手・詰み)
      ],
      explanation: '',
    ));
  }

  // ===== 3手詰め ① =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][1] = Piece(PieceType.pawn, false);
    b[0][2] = Piece(PieceType.king, false);
    b[1][1] = Piece(PieceType.lance, false);
    b[1][3] = Piece(PieceType.pawn, false);
    b[2][2] = Piece(PieceType.pawn, false);
    b[2][5] = Piece(PieceType.knight, true);
    b[3][5] = Piece(PieceType.knight, true);
    b[4][2] = Piece(PieceType.rook, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ①',
      moves: 3,
      board: b,
      p1Hand: {PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: 4, fc: 2, tr: 2, tc: 2),
        AMove(fr: 0, fc: 2, tr: 0, tc: 3),
        AMove(fr: -1, fc: -1, tr: 1, tc: 4, drop: PieceType.gold),
      ],
      explanation: '',
    ));
  }

  // ===== 3手詰め ② =====
  // 龍で後手歩を取り王手→後手玉2一に逃げ→角(馬)成りで詰み
  // 後手玉 1一(0,0)、先手龍 1六(5,0)、先手金 3三(2,2)、先手角 2三(2,1)、後手歩 1四(3,0)
  // 手順:
  //   1. 龍 1六→1四(後手歩取り、縦で王手)
  //   2. 後手玉 1一→2一(0,1)逃げ(唯一の逃げ: 1二は龍縦・2二は金斜め封鎖)
  //   3. 角 2三→3二成(1,2)、王手。2一の逃げ道は
  //      1一=龍の縦利き、3一=馬の縦利き、2二=金と馬の利きで全て封鎖、
  //      馬自体も金が守っているため取れず、詰み。
  // (以前は3手目に龍を1一へ寄せる手を解として登録していたが、
  //  1一の龍は無防備で王が取れてしまい実際には詰んでいなかった。
  //  TsumeEngine.findMate による検証で不成立と判明したため、
  //  角を追加して正しく詰む形に修正した)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);          // 後手玉 1一(0,0)
    b[8][8] = Piece(PieceType.king, true);            // 先手玉 9九(8,8)
    b[5][0] = Piece(PieceType.promotedRook, true);   // 先手龍 1六(5,0)
    b[2][2] = Piece(PieceType.gold, true);            // 先手金 3三(2,2)
    b[2][1] = Piece(PieceType.bishop, true);          // 先手角 2三(2,1)
    b[3][0] = Piece(PieceType.pawn, false);           // 後手歩 1四(3,0) ← 龍の王手を遮断
    list.add(TsumeProb(
      title: '3手詰め ②',
      moves: 3,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 5, fc: 0, tr: 3, tc: 0),  // 龍 1六→1四(後手歩取り、縦で王手)
        AMove(fr: 0, fc: 0, tr: 0, tc: 1),  // 後手玉 1一→2一(0,1)逃げ
        AMove(fr: 2, fc: 1, tr: 1, tc: 2, promote: true),  // 角 2三→3二成(1,2)、詰み
      ],
      explanation: '',
    ));
  }

  // ===== 3手詰め ③ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);
    b[2][3] = Piece(PieceType.rook, true);
    b[3][5] = Piece(PieceType.knight, true);
    b[8][0] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ③',
      moves: 3,
      board: b,
      p1Hand: {PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: 2, fc: 3, tr: 2, tc: 8, promote: true),
        AMove(fr: 0, fc: 8, tr: 0, tc: 7),
        AMove(fr: -1, fc: -1, tr: 1, tc: 6, drop: PieceType.gold),
      ],
      explanation: '',
    ));
  }


  // ===== 3手詰め ⑤ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[2][2] = Piece(PieceType.silver, true);
    b[3][0] = Piece(PieceType.gold, true);
    b[3][4] = Piece(PieceType.rook, true);
    b[4][1] = Piece(PieceType.knight, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ⑤',
      moves: 3,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 3, fc: 4, tr: 0, tc: 4),
        AMove(fr: 0, fc: 0, tr: 1, tc: 0),
        AMove(fr: 3, fc: 0, tr: 2, tc: 0),
      ],
      explanation: '',
    ));
  }

  // ===== 3手詰め ⑥ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);
    b[1][5] = Piece(PieceType.promotedBishop, true);
    b[2][8] = Piece(PieceType.knight, true);
    b[3][6] = Piece(PieceType.gold, true);
    b[8][0] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ⑥',
      moves: 3,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 1, fc: 5, tr: 2, tc: 6),
        AMove(fr: 0, fc: 8, tr: 1, tc: 8),
        AMove(fr: 3, fc: 6, tr: 2, tc: 7),
      ],
      explanation: '',
    ));
  }

  // ===== 3手詰め ⑦ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);
    b[2][2] = Piece(PieceType.knight, true);
    b[2][4] = Piece(PieceType.pawn, false);
    b[2][7] = Piece(PieceType.knight, true);
    b[3][5] = Piece(PieceType.knight, true);
    b[3][6] = Piece(PieceType.knight, true);
    b[6][4] = Piece(PieceType.rook, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ⑦',
      moves: 3,
      board: b,
      p1Hand: {PieceType.silver: 1},
      p2Hand: {},
      solution: [
        AMove(fr: 6, fc: 4, tr: 2, tc: 4, promote: true),
        AMove(fr: 0, fc: 4, tr: 0, tc: 5),
        AMove(fr: -1, fc: -1, tr: 1, tc: 5, drop: PieceType.silver),
      ],
      explanation: '',
    ));
  }

  // ===== 5手詰め ① =====
  // (Workflow並列エージェント第2ラウンドがTsumeEngineで余詰みなし・行き所のない駒なしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[1][1] = Piece(PieceType.pawn, false);
    b[4][1] = Piece(PieceType.knight, true);
    b[5][0] = Piece(PieceType.knight, true);
    b[5][1] = Piece(PieceType.knight, true);
    b[5][2] = Piece(PieceType.knight, true);
    b[8][3] = Piece(PieceType.rook, true);
    list.add(TsumeProb(
      title: '5手詰め ①',
      moves: 5,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 8, fc: 3, tr: 0, tc: 3),
        AMove(fr: 0, fc: 0, tr: 1, tc: 0),
        AMove(fr: 5, fc: 2, tr: 3, tc: 1),
        AMove(fr: 1, fc: 0, tr: 2, tc: 1),
        AMove(fr: 0, fc: 3, tr: 2, tc: 3),
      ],
      explanation: '',
    ));
  }



  // ===== 5手詰め ④ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '5手詰め ④',
      moves: 5,
      board: b,
      p1Hand: {PieceType.rook: 1, PieceType.gold: 2},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 2, tc: 0, drop: PieceType.rook),
        AMove(fr: 0, fc: 0, tr: 0, tc: 1),
        AMove(fr: 2, fc: 0, tr: 2, tc: 1, promote: true),
        AMove(fr: 0, fc: 1, tr: 0, tc: 0),
        AMove(fr: -1, fc: -1, tr: 0, tc: 1, drop: PieceType.gold),
      ],
      explanation: '',
    ));
  }

  // ===== 5手詰め ⑤ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[3][1] = Piece(PieceType.knight, true);
    b[3][2] = Piece(PieceType.knight, true);
    b[4][3] = Piece(PieceType.knight, true);
    b[4][4] = Piece(PieceType.knight, true);
    b[5][3] = Piece(PieceType.rook, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '5手詰め ⑤',
      moves: 5,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 5, fc: 3, tr: 5, tc: 0),
        AMove(fr: 0, fc: 0, tr: 0, tc: 1),
        AMove(fr: 4, fc: 3, tr: 2, tc: 2),
        AMove(fr: 0, fc: 1, tr: 0, tc: 2),
        AMove(fr: 4, fc: 4, tr: 2, tc: 3),
      ],
      explanation: '',
    ));
  }



  // ===== 追加問題 (⑧以降) =====
  _buildExtraProblems(list);

  if (skipStartPositionFilter) return list;

  // 開始局面で後手玉がすでに王手または詰みの問題を除外
  list.retainWhere((p) =>
      !GL.inCheck(p.board, false) &&
      GL.hasLegalMove(p.board, false, p.p2Hand, p.p1Hand));
  return list;
}

/// 追加の詰将棋問題（21問→33問）
void _buildExtraProblems(List<TsumeProb> list) {
  // ── 1手詰め ⑧ ─────────────────────────────
  // 後手玉9一(0,8), 先手金7二(1,6), 持ち駒:金1
  // 手順: 金8二(1,7)打ち → step(-1,1)=(0,8)=9一✓
  // 逃げ場: 8一→金(1,6)step(-1,1)=(0,7)✓封鎖 / 9二→打った金step(0,1)=(1,8)✓封鎖 / 8二→打った金を取ると金(1,6)step(0,1)=(1,7)✓違法手
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king,  false); // 後手玉 9一
    b[8][0] = Piece(PieceType.king,  true);  // 先手玉 1九
    b[1][6] = Piece(PieceType.gold,  true);  // 先手金 7二
    list.add(TsumeProb(
      title: '1手詰め ⑧', moves: 1, board: b,
      p1Hand: {PieceType.gold: 1}, p2Hand: {},
      solution: [AMove(fr: -1, fc: -1, tr: 1, tc: 7, drop: PieceType.gold)],
      explanation: '',
    ));
  }

  // ── 1手詰め ⑨ ─────────────────────────────
  // 後手玉1一(0,0), 先手龍3二(1,2), 持ち駒:銀1
  // 手順: 銀1二(1,0)打ち → step(-1,0)=(0,0)=1一✓
  // 逃げ場: 2一→龍step(-1,-1)=(0,1)✓ / 1二→取ると龍slide(0,-1)=(1,1),(1,0)✓違法手 / 2二→龍slide(0,-1)=(1,1)✓
  // (旧版は龍が開始局面で既に後手玉の全逃げ場を封鎖しており、王手はしていない
  //  ものの後手に合法手が無い＝開始局面が既に終端状態という不正な局面だった。
  //  TsumeEngineでの検証により発覚・修正: 後手に歩を1枚持たせ、
  //  開始局面で合法手が存在するようにした)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king,         false); // 後手玉 1一
    b[8][8] = Piece(PieceType.king,         true);  // 先手玉 9九
    b[1][2] = Piece(PieceType.promotedRook, true);  // 先手龍 3二
    b[0][1] = Piece(PieceType.pawn,         false); // 後手歩 2一（開始局面が終端状態になるのを防ぐ）
    list.add(TsumeProb(
      title: '1手詰め ⑨', moves: 1, board: b,
      p1Hand: {PieceType.silver: 1}, p2Hand: {},
      solution: [AMove(fr: -1, fc: -1, tr: 1, tc: 0, drop: PieceType.silver)],
      explanation: '',
    ));
  }

  // ===== 1手詰め ⑩ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[1][0] = Piece(PieceType.pawn, false);
    b[2][1] = Piece(PieceType.gold, true);
    b[2][3] = Piece(PieceType.bishop, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '1手詰め ⑩',
      moves: 1,
      board: b,
      p1Hand: {PieceType.bishop: 1},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 2, tc: 2, drop: PieceType.bishop),
      ],
      explanation: '',
    ));
  }


  // ===== 3手詰め ⑨ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[2][2] = Piece(PieceType.knight, true);
    b[3][0] = Piece(PieceType.gold, true);
    b[3][2] = Piece(PieceType.knight, true);
    b[4][1] = Piece(PieceType.knight, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ⑨',
      moves: 3,
      board: b,
      p1Hand: {PieceType.bishop: 1},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 1, tc: 1, drop: PieceType.bishop),
        AMove(fr: 0, fc: 0, tr: 1, tc: 0),
        AMove(fr: 3, fc: 0, tr: 2, tc: 0),
      ],
      explanation: '',
    ));
  }

  // ── 3手詰め ⑩ ─────────────────────────────
  // 龍横移動で後手銀取り王手→玉1一逃げ→香打ち詰め
  // 後手玉2一(0,1), 後手銀3一(0,2)で龍の横を止める
  // 先手龍4一(0,3): 横(0,2)=後手銀止→出発点王手なし ✓
  // 先手銀2三(2,1): step(-1,-1)=(1,0)=1二, step(-1,0)=(1,1)=2二を封鎖
  {
    final b = _empty();
    b[0][1] = Piece(PieceType.king,         false); // 後手玉 2一
    b[0][2] = Piece(PieceType.silver,       false); // 後手銀 3一(龍の横を止める)
    b[8][8] = Piece(PieceType.king,         true);  // 先手玉 9九
    b[0][3] = Piece(PieceType.promotedRook, true);  // 先手龍 4一
    b[2][1] = Piece(PieceType.silver,       true);  // 先手銀 2三(1二・2二封鎖)
    list.add(TsumeProb(
      title: '3手詰め ⑩', moves: 3, board: b,
      p1Hand: {PieceType.lance: 1}, p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 1, tc: 1, drop: PieceType.lance), // 香 8二打 王手
        AMove(fr: 0, fc: 1, tr: 0, tc: 0),                          // 後手玉 2一→1一逃げ
        AMove(fr: 0, fc: 3, tr: 0, tc: 2),                          // 龍 4一→3一(銀取り) 詰み
      ],
      explanation: '',
    ));
  }

  // ── 1手詰め ⑪ ─────────────────────────────
  // (旧版は飛・金が共に開始局面から王手をかける不正な局面な上、解答手も
  //  後手玉のマスへ直接移動する不成立な手だった。TsumeEngineでの検証により
  //  発覚・修正: 飛を横から9二へ成り込む形に変更)
  // 後手玉9一(0,8), 先手飛6二(1,3), 先手金7三(2,7) ← 9二を守る
  // 手順: 飛 6二→9二(1,8)成り 王手（龍の八方効きで8一・8二を封鎖、金が龍を守る）
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);  // 後手玉 9一
    b[8][0] = Piece(PieceType.king, true);   // 先手玉 1九
    b[1][3] = Piece(PieceType.rook, true);   // 先手飛 6二
    b[2][7] = Piece(PieceType.gold, true);   // 先手金 7三 ← 9二を守る
    list.add(TsumeProb(
      title: '1手詰め ⑪', moves: 1, board: b,
      p1Hand: {}, p2Hand: {},
      solution: [AMove(fr: 1, fc: 3, tr: 1, tc: 8, promote: true)], // 飛→9二成
      explanation: '',
    ));
  }

  // ── 1手詰め ⑫ ─────────────────────────────
  // (旧版は馬・金2枚が全て開始局面から王手をかけてしまう不正な局面だった。
  //  TsumeEngineでの検証により発覚・修正)
  // 後手玉5一(0,4), 先手馬4三(2,3), 先手桂3六(3,5) ← 5二を守る
  // 手順: 馬 4三→5二(1,4) 王手（馬の八方効きで四方封鎖、桂が5二を守る）
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);           // 後手玉 5一
    b[8][4] = Piece(PieceType.king, true);            // 先手玉 5九
    b[2][3] = Piece(PieceType.promotedBishop, true);  // 先手馬 4三
    b[3][5] = Piece(PieceType.knight, true);          // 先手桂 3六 ← 5二を守る
    list.add(TsumeProb(
      title: '1手詰め ⑫', moves: 1, board: b,
      p1Hand: {}, p2Hand: {},
      solution: [AMove(fr: 2, fc: 3, tr: 1, tc: 4)], // 馬 4三→5二 王手
      explanation: '',
    ));
  }

  // ===== 3手詰め ⑪ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[1][2] = Piece(PieceType.silver, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ⑪',
      moves: 3,
      board: b,
      p1Hand: {PieceType.gold: 2},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 0, tc: 1, drop: PieceType.gold),
        AMove(fr: 0, fc: 0, tr: 1, tc: 0),
        AMove(fr: -1, fc: -1, tr: 2, tc: 1, drop: PieceType.gold),
      ],
      explanation: '',
    ));
  }

  // ===== 3手詰め ⑫ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);
    b[1][7] = Piece(PieceType.lance, true);
    b[2][6] = Piece(PieceType.silver, true);
    b[3][7] = Piece(PieceType.gold, true);
    b[3][8] = Piece(PieceType.gold, true);
    b[8][0] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ⑫',
      moves: 3,
      board: b,
      p1Hand: {PieceType.knight: 1},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 2, tc: 7, drop: PieceType.knight),
        AMove(fr: 0, fc: 8, tr: 1, tc: 8),
        AMove(fr: 3, fc: 8, tr: 2, tc: 8),
      ],
      explanation: '',
    ));
  }

  // ===== 5手詰め ⑦ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[4][3] = Piece(PieceType.knight, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '5手詰め ⑦',
      moves: 5,
      board: b,
      p1Hand: {PieceType.rook: 1, PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 2, tc: 0, drop: PieceType.rook),
        AMove(fr: 0, fc: 0, tr: 0, tc: 1),
        AMove(fr: 2, fc: 0, tr: 2, tc: 1, promote: true),
        AMove(fr: 0, fc: 1, tr: 0, tc: 0),
        AMove(fr: -1, fc: -1, tr: 0, tc: 1, drop: PieceType.gold),
      ],
      explanation: '',
    ));
  }

  // ===== 5手詰め ⑧ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '5手詰め ⑧',
      moves: 5,
      board: b,
      p1Hand: {PieceType.bishop: 1, PieceType.gold: 1, PieceType.rook: 1},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 2, tc: 2, drop: PieceType.bishop),
        AMove(fr: 0, fc: 0, tr: 1, tc: 0),
        AMove(fr: -1, fc: -1, tr: 1, tc: 1, drop: PieceType.gold),
        AMove(fr: 1, fc: 0, tr: 2, tc: 0),
        AMove(fr: -1, fc: -1, tr: 0, tc: 0, drop: PieceType.rook),
      ],
      explanation: '',
    ));
  }

  // ── 1手詰め ⑬ ─────────────────────────────
  // (旧版は銀が開始局面から王手をかけてしまう不正な局面だった。
  //  TsumeEngineでの検証により発覚・修正)
  // 後手玉3一(0,2), 持ち駒金、先手飛4二(1,3) ← 2二・3二を守る、
  // 先手金5二(1,4) ← 4一を守る、先手銀1二(1,0) ← 2一を守る
  // (これらの駒だけで開始局面から後手玉の全逃げ場を封鎖してしまい、王手は
  //  していないものの合法手が無い＝終端状態になっていたため、後手に歩を
  //  持たせて開始局面に合法手を残した)
  {
    final b = _empty();
    b[0][2] = Piece(PieceType.king,   false); // 後手玉 3一
    b[8][8] = Piece(PieceType.king,   true);  // 先手玉 9九
    b[1][3] = Piece(PieceType.rook,   true);  // 先手飛 4二 ← 2二・3二を守る
    b[1][4] = Piece(PieceType.gold,   true);  // 先手金 5二 ← 4一を守る
    b[1][0] = Piece(PieceType.silver, true);  // 先手銀 1二 ← 2一を守る
    b[4][4] = Piece(PieceType.pawn,   false); // 後手歩（開始局面が終端状態になるのを防ぐ）
    list.add(TsumeProb(
      title: '1手詰め ⑬', moves: 1, board: b,
      p1Hand: {PieceType.gold: 1}, p2Hand: {},
      solution: [AMove(fr: -1, fc: -1, tr: 0, tc: 1, drop: PieceType.gold)], // 金2一打ち
      explanation: '',
    ));
  }

  // ===== 3手詰め ⑬ =====
  // (Workflow並列エージェント第2ラウンドがTsumeEngineで余詰みなし・行き所のない駒なしを自己検証して再設計)
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);
    b[1][4] = Piece(PieceType.pawn, false);
    b[2][7] = Piece(PieceType.knight, true);
    b[3][3] = Piece(PieceType.lance, true);
    b[3][5] = Piece(PieceType.knight, true);
    b[5][5] = Piece(PieceType.bishop, true);
    b[8][0] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ⑬',
      moves: 3,
      board: b,
      p1Hand: {PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: 5, fc: 5, tr: 3, tc: 7),
        AMove(fr: 0, fc: 4, tr: 0, tc: 5),
        AMove(fr: -1, fc: -1, tr: 0, tc: 4, drop: PieceType.gold),
      ],
      explanation: '',
    ));
  }



  // ── 1手詰め ⑭ ─────────────────────────────
  // (旧版は飛が開始局面から王手をかけている上、解答の打ち場所に既に銀が
  //  存在する二重に不正な局面だった。TsumeEngineでの検証により発覚・修正:
  //  飛・銀を削除し金1枚だけで詰む形に簡略化)
  // 後手玉9九(8,8), 先手金8八(7,7)
  {
    final b = _empty();
    b[8][8] = Piece(PieceType.king,  false); // 後手玉 9九
    b[0][0] = Piece(PieceType.king,  true);  // 先手玉 1一
    b[7][7] = Piece(PieceType.gold,  true);  // 先手金 8八
    list.add(TsumeProb(
      title: '1手詰め ⑭', moves: 1, board: b,
      p1Hand: {PieceType.gold: 1}, p2Hand: {},
      solution: [AMove(fr: -1, fc: -1, tr: 7, tc: 8, drop: PieceType.gold)], // 金9八打ち
      explanation: '',
    ));
  }

  // ===== 3手詰め ⑭ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);
    b[1][4] = Piece(PieceType.pawn, false);
    b[2][3] = Piece(PieceType.promotedPawn, true);
    b[2][7] = Piece(PieceType.knight, true);
    b[3][4] = Piece(PieceType.knight, true);
    b[3][7] = Piece(PieceType.knight, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ⑭',
      moves: 3,
      board: b,
      p1Hand: {PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: 2, fc: 3, tr: 1, tc: 3),
        AMove(fr: 0, fc: 4, tr: 0, tc: 5),
        AMove(fr: -1, fc: -1, tr: 1, tc: 5, drop: PieceType.gold),
      ],
      explanation: '',
    ));
  }
}

// ===== 内蔵詰将棋問題の検証（tool/validate_tsume_screen.dart から呼び出す） =====
// 手筋・囲い崩し(tool/validate_tactics.dart)と異なり、この画面の詰将棋は
// 手打ちの座標データを直接 List に埋め込んでいるため、これまで自動検証の
// 対象外だった（tsume_extra.json のみ検証済み）。TsumeEngine と同じ考え方で
// 解答手順通りに進めて本当に詰み（合法手なし）になるかを確認する。
List<String> validateBuiltinTsumeProblems() {
  final errs = <String>[];
  final problems = buildTsumeProblems();
  for (final p in problems) {
    try {
      var board = List.generate(9, (r) => List<Piece?>.from(p.board[r]));
      var p1h = Map<PieceType, int>.from(p.p1Hand);
      var p2h = Map<PieceType, int>.from(p.p2Hand);
      bool moverIsP1 = true;
      for (int i = 0; i < p.solution.length; i++) {
        final mv = p.solution[i];
        final r = AI.apply(board, p1h, p2h, mv, moverIsP1);
        board = r.b;
        p1h = r.p1h;
        p2h = r.p2h;
        moverIsP1 = !moverIsP1;
        if (i.isEven && !GL.inCheck(board, false)) {
          errs.add('[${p.title}] 手${i + 1}: 先手の手が王手になっていない');
        }
      }
      if (GL.hasLegalMove(board, false, p2h, p1h)) {
        errs.add('[${p.title}] 解答後に後手玉が詰んでいない（合法手が残っている）');
      }
    } catch (e) {
      errs.add('[${p.title}] 検証中に例外: $e');
    }
  }
  return errs;
}
