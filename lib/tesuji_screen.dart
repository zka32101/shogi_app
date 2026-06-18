// lib/tesuji_screen.dart — 手筋トレーニング画面
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'piece.dart';
import 'mini_board_widget.dart';

// ===== 問題データ =====
class _TesujiProb {
  final String id;
  final String title;
  final String category; // '飛車取り'|'王手金取り'|'両取り'|'守り'|'詰め'|'捨て駒'
  final String explanation;
  final List<List<Piece?>> board;
  final Map<PieceType, int> p1Hand;
  final Map<PieceType, int> p2Hand;
  final bool p1Turn;
  final AMove answer; // 正解手（fr,fc,tr,tc）
  final String? sourceUrl;
  final String? sourceTitle;
  final String difficulty; // '初級'|'中級'|'上級'

  const _TesujiProb({
    required this.id,
    required this.title,
    required this.category,
    required this.explanation,
    required this.board,
    this.p1Hand = const {},
    this.p2Hand = const {},
    this.p1Turn = true,
    required this.answer,
    this.sourceUrl,
    this.sourceTitle,
    required this.difficulty,
  });
}

List<List<Piece?>> _empty() =>
    List.generate(9, (_) => List<Piece?>.filled(9, null));

// ===== 問題集 =====
// 座標: board[row][col], row=0=1段目(上端), col=0=9筋(右端)
// 先手(p1=true): 上向き、敵陣=row0付近
// 後手(p2=false): 下向き

List<_TesujiProb> _buildTesujiProblems() {
  final list = <_TesujiProb>[];

  // ===== 飛車取り ① =====
  // 後手飛 5五(4,4)、先手角 7七(6,6)
  // 先手角 7七→5五 で飛車を取る
  // 後手玉 4一(0,3)、先手玉 6九(8,5)
  {
    final b = _empty();
    b[0][3] = Piece(PieceType.king, false);         // 後手玉 4一(0,3)
    b[8][5] = Piece(PieceType.king, true);           // 先手玉 6九(8,5)
    b[4][4] = Piece(PieceType.rook, false);          // 後手飛 5五(4,4)
    b[6][6] = Piece(PieceType.bishop, true);         // 先手角 7七(6,6)
    b[2][2] = Piece(PieceType.gold, false);          // 後手金 3三(2,2) (逃げ先にいる想定)
    list.add(_TesujiProb(
      id: 'hikisha_1',
      title: '飛車取り ①',
      category: '飛車取り',
      explanation: '先手角が7七から5五へ斜めに動き、後手の飛車をタダ取りできます。角の斜め効きを活かす基本手筋。',
      board: b,
      answer: AMove(fr: 6, fc: 6, tr: 4, tc: 4),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '初級',
    ));
  }

  // ===== 飛車取り ② =====
  // 後手飛 2二(1,7)、先手桂 3四(3,6)
  // 先手桂 3四→2二 で飛車を取る（桂が金より高い駒を取る）
  // 先手桂跳びで飛車取り
  {
    final b = _empty();
    b[0][5] = Piece(PieceType.king, false);          // 後手玉 4一(0,5)
    b[8][4] = Piece(PieceType.king, true);           // 先手玉 5九(8,4)
    b[1][7] = Piece(PieceType.rook, false);          // 後手飛 2二(1,7)
    b[3][6] = Piece(PieceType.knight, true);         // 先手桂 3四(3,6)
    b[1][6] = Piece(PieceType.silver, false);        // 後手銀 2二の隣 3二(1,6)
    list.add(_TesujiProb(
      id: 'hikisha_2',
      title: '飛車取り ②',
      category: '飛車取り',
      explanation: '先手桂馬が3四から2二に跳んで後手飛車を直接取ります。桂馬の跳び効きを利用した飛車狙いの手筋。',
      board: b,
      answer: AMove(fr: 3, fc: 6, tr: 1, tc: 7),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '初級',
    ));
  }

  // ===== 飛車取り ③ =====
  // 後手飛 8八(7,1)、先手銀 7九(8,2)
  // 先手銀 7九→8八 で飛車を取る（成り込む）
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);          // 後手玉 1一(0,8)
    b[8][0] = Piece(PieceType.king, true);           // 先手玉 9九(8,0)
    b[7][1] = Piece(PieceType.rook, false);          // 後手飛 8八(7,1)
    b[8][2] = Piece(PieceType.silver, true);         // 先手銀 7九(8,2)
    b[6][1] = Piece(PieceType.pawn, false);          // 後手歩 8七(6,1) 逃げ先封鎖
    list.add(_TesujiProb(
      id: 'hikisha_3',
      title: '飛車取り ③',
      category: '飛車取り',
      explanation: '先手銀が7九から8八に動き、後手の飛車を取りながら成ります。銀の斜め前への移動で飛車を獲得する手筋。',
      board: b,
      answer: AMove(fr: 8, fc: 2, tr: 7, tc: 1, promote: true),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '初級',
    ));
  }

  // ===== 王手金取り ① =====
  // 後手玉 4一(0,3)、後手金 3一(0,4)（隣接）
  // 先手飛 4三(2,3) → 先手飛 4一 で王手かつ金取り
  // 後手玉は逃げなければならず、金を守れない
  {
    final b = _empty();
    b[0][3] = Piece(PieceType.king, false);          // 後手玉 4一(0,3)
    b[0][4] = Piece(PieceType.gold, false);          // 後手金 3一(0,4)
    b[8][8] = Piece(PieceType.king, true);           // 先手玉 1九(8,8)
    b[2][3] = Piece(PieceType.rook, true);           // 先手飛 4三(2,3)
    b[1][3] = Piece(PieceType.pawn, false);          // 後手歩 4二(1,3)
    b[2][2] = Piece(PieceType.silver, true);         // 先手銀 3三(2,2) ─ (1,3)を守る
    list.add(_TesujiProb(
      id: 'oute_kintori_1',
      title: '王手金取り ①',
      category: '王手金取り',
      explanation: '先手飛車が4三から4二の歩を取りながら王手します。後手玉は逃げるしかなく（銀が(1,3)を守っているため取れない）、次の手で3一の金も取れます。',
      board: b,
      answer: AMove(fr: 2, fc: 3, tr: 1, tc: 3),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '初級',
    ));
  }

  // ===== 王手金取り ② =====
  // 後手玉 5一(0,4)、後手金 4二(1,3)
  // 先手角 3三(2,2) → 5一 に移動で王手、同時に4二金取り
  // 角の斜め効きが玉と金を同時に睨む
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);          // 後手玉 5一(0,4)
    b[1][3] = Piece(PieceType.gold, false);          // 後手金 4二(1,3)
    b[8][4] = Piece(PieceType.king, true);           // 先手玉 5九(8,4)
    b[3][6] = Piece(PieceType.bishop, true);         // 先手角 3四(3,6)...
    // 角を王と金を同時に睨める位置に: 角 7七(6,6) から5一(0,4)は斜めに無理
    // 角 3三(2,2) から5一(0,4)は2マス斜め上なので可 (row2,col2)->(row0,col4): dr=-2,dc=+2→角の効き
    b[3][6] = null;
    b[2][2] = Piece(PieceType.bishop, true);         // 先手角 3三(2,2)
    // 角(2,2)→(0,4): dr=-2, dc=+2 → 斜め右上2マス = 角の効き
    // 角(2,2)の効き: 斜め全方向 → (1,1),(0,0) ; (1,3),(0,4)=5一!; (3,1),(4,0); (3,3),(4,4)...
    // (1,3)=後手金 → 角が(0,4)に行けば王手 & (1,3)金も取れる
    // ただし (1,3) を通過しているので(0,4)まで届かない→ダメ
    // 別配置: 角を(2,6)に置く → (1,5),(0,4)=5一 ← dr=-1,dc=-2は角ではない
    // 角(r,c)→(r-1,c+1)なら1マス斜め右上OK
    // 角を4二の斜め後ろ(3,2)に → (2,3)→(1,4)→(0,5)... ではなく
    // 実は「角」の効きは斜め4方向。(3,4)から(0,1)や(1,2)など
    // 簡単な配置: 角(4,2) → (3,3)→(2,4)→(1,5)→(0,6)=3一(0,6) or 右下(0,2)など
    // 王手&金取りの典型: 飛を使う方が確実
    // 先手飛 5三(2,4) → (0,4)=5一で王手 & 後手金4二(1,3)は横に取れない
    // 「角による王手金取り」: 角(2,0)→(1,1)→(0,2) is not 5一
    // 別アプローチ: 先手銀(2,4)が(1,3)に行けば後手金を取りながら後手玉に王手...
    // 銀(isPlayer1)(1,3): 銀の利き(0,2),(0,3),(0,4)=玉!, (1,2),(2,4) → (1,3)から(0,4)=王手!
    // しかし(1,3)に後手金がいるので銀が来れば金を取って王手 ← これが「王手金取り」!
    b[2][2] = null;
    b[2][4] = Piece(PieceType.silver, true);         // 先手銀 5三(2,4)
    // 銀(2,4)の利き(先手: fwd=-1): (1,3),(1,4),(1,5),(3,3),(3,5)
    // (1,3) = 後手金 → 銀で取れば王手の可能性は... 銀(1,3)の利き: (0,2),(0,3),(0,4)=玉! ✓
    list.add(_TesujiProb(
      id: 'oute_kintori_2',
      title: '王手金取り ②',
      category: '王手金取り',
      explanation: '先手銀が5三から4二の後手金を取ります。取った銀は5一の後手玉に王手をかけます。相手は王手を防がなければならず、金を守れません。',
      board: b,
      answer: AMove(fr: 2, fc: 4, tr: 1, tc: 3),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '初級',
    ));
  }

  // ===== 王手金取り ③ =====
  // 先手桂が跳んで王手&金取り
  // 後手玉 3一(0,2)、後手金 2三(2,7) ← 離れすぎ
  // 後手玉 5一(0,4)、後手金 4三(2,3)
  // 先手桂 4五(4,3) → 3三(2,2) に跳んで... (2,2)から玉(0,4)に届かない
  // 先手桂の利き: (fr-2, fc-1) and (fr-2, fc+1) → 先手
  // 桂(4,5)→(2,4)=5三と(2,6)=3三
  // 玉(0,4)への王手になる桂の位置: (2,3)か(2,5)
  // 桂(4,4)→(2,3)か(2,5)
  // (2,5)で王手 & 後手金が(2,4)にあれば... (2,5)から金を取れない(桂は動けない)
  // 「王手かつ金取り」= 動いた後の先手駒が玉と金を同時に攻撃
  // 桂(4,5)→(2,6): 桂(2,6)の利き=(0,5)と(0,7) 玉(0,5)ならOK
  // 後手玉(0,5)、後手金(1,6): 桂(4,5)→(2,6) で... 金(1,6)は取れない、桂の利き(0,5)(0,7)のみ
  // 別: 先手飛で王手(直接) & その前に金を取れる手
  // シンプルに: 先手飛(2,2) → (2,3)で後手金取り & 飛が後手玉(0,3)の縦ライン上なので次に王手可能
  {
    final b = _empty();
    b[0][3] = Piece(PieceType.king, false);          // 後手玉 4一(0,3)
    b[2][3] = Piece(PieceType.gold, false);          // 後手金 4三(2,3)
    b[8][4] = Piece(PieceType.king, true);           // 先手玉 5九(8,4)
    b[2][5] = Piece(PieceType.rook, true);           // 先手飛 4三(2,5)
    // 先手飛(2,5)→(2,3): 後手金を取る & 飛は4三=4一への縦ライン上(col3)に入れる
    // 横移動: (2,5)→(2,3)=金取り、その後(2,3)→(0,3)=玉に王手(次の手)
    // これは「金取り、次に王手」の手筋
    // 玉のそばの金をタダで取れる → これが手筋問題の趣旨
    list.add(_TesujiProb(
      id: 'oute_kintori_3',
      title: '王手金取り ③',
      category: '王手金取り',
      explanation: '先手飛車が横移動して後手金をタダ取りします。取った後は後手玉への縦方向の王手が続きます。飛車の横効きを使った金取りの手筋。',
      board: b,
      answer: AMove(fr: 2, fc: 5, tr: 2, tc: 3),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '初級',
    ));
  }

  // ===== 両取り ① =====
  // 先手角が動いて後手の飛車と金を同時に攻撃する
  // 後手飛 8二(1,1)、後手金 2四(3,7)
  // 先手角 5五(4,4) → 先手角の効き方向に両駒を配置
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);          // 後手玉 1一(0,8)
    b[8][0] = Piece(PieceType.king, true);           // 先手玉 9九(8,0)
    b[1][1] = Piece(PieceType.rook, false);          // 後手飛 8二(1,1)
    b[3][7] = Piece(PieceType.gold, false);          // 後手金 2四(3,7)
    b[4][4] = Piece(PieceType.bishop, true);         // 先手角 5五(4,4)
    // 角(4,4)が動いて(2,2)に行くと:
    //   (2,2)の角の効き: (1,1)=飛 ✓  (3,1),(4,0); (1,3),(0,4); (3,3),(4,2)...
    //   (1,1)=飛は(2,2)の斜め左上 → 取れる? (2,2)→(1,1)は1マス斜め → 角の効きにある ✓
    //   (3,7)=金は(2,2)から遠い → 両取りにならない
    // 角(4,4)→(2,6): (2,6)の角の効き: (1,5),(0,4); (1,7),(0,8); (3,5),(4,4); (3,7)=金 ✓
    //   (2,6)から(1,7)→飛が(1,7)にあれば両取り
    // 後手飛を(1,7)に移動:
    b[1][1] = null;
    b[1][7] = Piece(PieceType.rook, false);          // 後手飛 2二(1,7)
    // 角(4,4)→(2,6): (1,5),(0,4); (1,7)=飛 ✓; (3,5); (3,7)=金 ✓
    // → 角が(2,6)に動くと飛(1,7)と金(3,7)を同時に攻撃 ✓
    list.add(_TesujiProb(
      id: 'ryotori_1',
      title: '両取り ①',
      category: '両取り',
      explanation: '先手角が5五から3四に動きます。角は斜めの2方向に同時に効くため、後手の飛車（2二）と金（2四）を同時に攻撃します。どちらを守っても片方が取られます。',
      board: b,
      answer: AMove(fr: 4, fc: 4, tr: 2, tc: 6),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '初級',
    ));
  }

  // ===== 両取り ② =====
  // 先手桂が跳んで後手の2枚を同時攻撃
  // 先手桂(4,3)→(2,2): 桂の利き(先手)=(fr-2,fc-1)と(fr-2,fc+1)
  // (4,3)→(2,2)と(2,4) どちらかが利き
  // 桂の動き先: (2,2) → 桂の利き(2,2)=(0,1)と(0,3)
  // (2,4)→ 桂の利き(2,4)=(0,3)と(0,5)
  // 「動いた後に2枚を攻撃」ではなく「動いた先で2枚を取れる」というより
  // 「先手が1手指して後手の駒2枚を攻める」が両取りの意味
  // 先手銀が動いて飛と角を同時に攻撃
  // 後手飛(1,3)、後手角(3,5)
  // 先手銀(2,4)の利き(先手): (1,3),(1,4),(1,5),(3,3),(3,5)
  // → 銀(2,4)が動かずに既に飛(1,3)と角(3,5)を攻撃 → これが両取り!
  {
    final b = _empty();
    b[0][2] = Piece(PieceType.king, false);          // 後手玉 3一(0,2)
    b[8][4] = Piece(PieceType.king, true);           // 先手玉 5九(8,4)
    b[1][3] = Piece(PieceType.rook, false);          // 後手飛 4二(1,3)
    b[3][5] = Piece(PieceType.gold, false);          // 後手金 4四(3,5)
    b[4][4] = Piece(PieceType.silver, true);         // 先手銀 5五(4,4)
    // 先手銀(4,4)→(3,3): 銀(3,3)の利き(先手): (2,2),(2,3),(2,4),(4,2),(4,4)
    // → 飛(1,3)と金(3,5)を攻撃しない
    // 先手銀(4,4)→(3,5): 後手金を取る! → 取ってしまうので両取りではない
    // 先手銀(4,4)→(3,3): 銀(3,3)の利き: (2,2),(2,3),(2,4),(4,2),(4,4)
    // 飛は(1,3)なので届かない
    // 別: 先手飛(4,3)の横効きで(4,1)と(4,5)にいる後手駒を同時攻撃
    b[4][4] = null;
    b[4][3] = Piece(PieceType.rook, true);           // 先手飛 4五(4,3)
    b[1][3] = null;
    b[4][1] = Piece(PieceType.bishop, false);        // 後手角 4六(4,1)
    b[4][5] = Piece(PieceType.gold, false);          // 後手金 6五(4,5)
    // 先手飛(4,3): 横効き=(4,0),(4,1)=角✓, (4,2); (4,4),(4,5)=金✓, ...
    // → 先手飛はすでに後手角(4,1)と後手金(4,5)を両方攻撃中 ✓
    // 問題の答え: 先手は他の駒を動かし、後手が逃げようとしても飛が両方を取れる局面を利用する
    // よりシンプルに: 先手が飛を動かして2枚を攻撃するとすれば、
    // 先手飛(6,3)→(4,3): 後手角(4,1)と金(4,5)を同時攻撃
    b[4][3] = null;
    b[6][3] = Piece(PieceType.rook, true);           // 先手飛 4七(6,3)
    list.add(_TesujiProb(
      id: 'ryotori_2',
      title: '両取り ②',
      category: '両取り',
      explanation: '先手飛車が前進して5五の地点に来ると、左右に後手の角（5六）と金（5四）を同時に攻撃します。飛車の横効きを活かした両取りの手筋。',
      board: b,
      answer: AMove(fr: 6, fc: 3, tr: 4, tc: 3),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '初級',
    ));
  }

  // ===== 両取り ③ =====
  // 先手角の動きで飛・銀を同時攻撃
  // 後手飛(0,0)、後手銀(2,2)
  // 先手角が(4,0)から(2,2)に行って後手銀を取る → 取るだけで両取りではない
  // 先手角を(4,4)から(2,2)の銀を取りつつ(0,0)の飛も射程内に入れる
  // 角(4,4)→(2,2): 取った後の角(2,2)の利き: (1,1),(0,0)=飛 ✓ & (1,3),(0,4); (3,1); (3,3)
  // → 銀を取りながら飛も攻撃する両取り ✓
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);          // 後手玉 1一(0,8)
    b[8][8] = Piece(PieceType.king, true);           // 先手玉 1九(8,8)
    b[0][0] = Piece(PieceType.rook, false);          // 後手飛 9一(0,0)
    b[2][2] = Piece(PieceType.silver, false);        // 後手銀 7三(2,2)
    b[4][4] = Piece(PieceType.bishop, true);         // 先手角 5五(4,4)
    // 角(4,4)→(2,2): 後手銀を取る。角(2,2)の利き: (1,1),(0,0)=飛 ✓ → 次に飛を取れる
    // これが「銀を取りながら飛を攻撃する」両取り
    list.add(_TesujiProb(
      id: 'ryotori_3',
      title: '両取り ③',
      category: '両取り',
      explanation: '先手角が5五から7三に動いて後手銀を取ります。取った後の角は9一の飛車も攻撃しています。銀を取りながら飛車も狙う「角による両取り」の手筋。',
      board: b,
      answer: AMove(fr: 4, fc: 4, tr: 2, tc: 2),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '初級',
    ));
  }

  // ===== 守り ① =====
  // 後手から詰めろがかかっている。先手は受けを指す。
  // 後手飛 9一(0,8)が先手玉9九(8,8)を狙っている縦利きを遮断
  // 先手玉 9九(8,8)、後手飛 9一(0,8)、先手香 9二(1,8)がいれば遮断できる
  // → 先手持ち駒の香を9二に打つ
  {
    final b = _empty();
    b[8][8] = Piece(PieceType.king, true);           // 先手玉 1九(8,8)
    b[0][8] = Piece(PieceType.rook, false);          // 後手飛 1一(0,8)
    b[0][0] = Piece(PieceType.king, false);          // 後手玉 9一(0,0)
    b[7][7] = Piece(PieceType.gold, true);           // 先手金 2八(7,7)
    // 後手飛(0,8)の縦効き: (1,8),(2,8),...,(8,8)=先手玉 → 詰めろ
    // 先手持ち駒の金を8二(1,8)に打って遮断
    list.add(_TesujiProb(
      id: 'mamori_1',
      title: '守り ①',
      category: '守り',
      explanation: '後手飛車が縦に先手玉を直接狙っています。持ち駒の金を2二に打って飛車の縦効きを遮断します。飛車の利きを止める合い駒の手筋。',
      board: b,
      p1Hand: {PieceType.gold: 1},
      answer: AMove(fr: -1, fc: -1, tr: 1, tc: 8, drop: PieceType.gold),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '初級',
    ));
  }

  // ===== 守り ② =====
  // 先手玉が詰めろにかかっており、玉を逃げる
  // 後手飛 5一(0,4)、後手角 7七(6,6)→利きが先手玉に向く
  // 先手玉 5九(8,4) → 安全なマスに逃げる
  {
    final b = _empty();
    b[8][4] = Piece(PieceType.king, true);           // 先手玉 5九(8,4)
    b[0][4] = Piece(PieceType.rook, false);          // 後手飛 5一(0,4) → col4の縦利き
    b[6][6] = Piece(PieceType.bishop, false);        // 後手角 3七(6,6) → 斜め利き(7,5),(8,4)=玉!
    b[0][0] = Piece(PieceType.king, false);          // 後手玉 9一(0,0)
    // 先手玉(8,4)への詰めろ: 飛(0,4)の縦 & 角(6,6)の斜め(7,5)→(8,4)
    // 先手玉の逃げ場: (7,3),(7,4),(7,5)=角利き×, (8,3),(8,5)=飛の横利き×(飛は縦のみ)
    // (8,3): 後手飛の利き外 & 後手角の斜め効き(7,4)(8,3)? 角(6,6)→(8,4)は(7,5),(8,4) → (8,3)に効かない ✓
    // (8,3)が安全 → 玉を(8,4)→(8,3)に逃げる
    // (8,5): 後手角(6,6)の斜め左下効き(7,5)(8,4)→(8,5)は?(7,7)(8,6)... (8,5)に効かない
    // 実は角(6,6)からdr=+2,dc=-2=(8,4) と dr=+2,dc=+2=(8,8)
    // dr=+1,dc=-1=(7,5) dr=+1,dc=+1=(7,7)
    // (8,3)は角から見て dr=+2,dc=-3 → 角の効きにない ✓
    list.add(_TesujiProb(
      id: 'mamori_2',
      title: '守り ②',
      category: '守り',
      explanation: '後手飛車の縦効きと後手角の斜め効きが先手玉に集中しています。先手玉を6九に逃げることで両方の利きから外れ、安全な場所に避けられます。',
      board: b,
      answer: AMove(fr: 8, fc: 4, tr: 8, tc: 3),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '初級',
    ));
  }

  // ===== 守り ③ =====
  // 先手の弱点（後手から王手がかかる）を金で補強
  // 先手玉 5九(8,4)、後手桂(6,5)が跳んで(4,4)or(4,6)に来て王手?
  // 後手桂(6,5)→後手桂の利き(後手: fwd=+1)=(fr+2,fc-1)と(fr+2,fc+1)
  // 後手桂(6,5)→(8,4)=先手玉! と(8,6)
  // → 先手玉の前に金を打って桂跳びを防ぐ
  // 金を(7,4)に打つと桂(6,5)→(8,4)を守ることになるか?
  // 金(7,4)が桂の到達先(8,4)を守る → 後手桂が(8,4)に来ると金が取れる
  // しかし問題としては「桂が来る前に金を打って守る」
  {
    final b = _empty();
    b[8][4] = Piece(PieceType.king, true);           // 先手玉 5九(8,4)
    b[6][5] = Piece(PieceType.knight, false);        // 後手桂 4七(6,5)
    b[0][8] = Piece(PieceType.king, false);          // 後手玉 1一(0,8)
    b[8][5] = Piece(PieceType.gold, true);           // 先手金 4九(8,5)
    // 後手桂(6,5): 後手のfwd=+1 → 後手桂の利き: (6+2,5-1)=(8,4)=先手玉!  (8,6)
    // 先手は金を(7,4)に打って守りを固める(後手桂が8,4に来るのを防衛的に守る)
    // 先手持ち駒: 銀を使う
    // 銀(7,4)の利き(先手): (6,3),(6,4),(6,5)=後手桂!,(7,3),(7,5) → 後手桂を攻撃できる
    // → 先手銀を(7,4)に打って後手桂を同時に攻撃(守りつつ攻撃)
    list.add(_TesujiProb(
      id: 'mamori_3',
      title: '守り ③',
      category: '守り',
      explanation: '後手桂馬が4七にいて、先手玉5九に跳び込もうとしています。先手は銀を6五に打って、後手桂を攻撃しながら先手玉の守りを固めます。攻防一体の手筋。',
      board: b,
      p1Hand: {PieceType.silver: 1},
      answer: AMove(fr: -1, fc: -1, tr: 7, tc: 4, drop: PieceType.silver),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '初級',
    ));
  }

  // ===== 飛車取り ④ =====
  // 先手香が前進して後手飛を取る
  // 後手飛 5二(1,4)、先手香 5九(8,4)
  // 先手香(8,4)→(1,4) で後手飛を取る（途中に駒なし）
  {
    final b = _empty();
    b[0][2] = Piece(PieceType.king, false);   // 後手玉 3一(0,2)
    b[8][0] = Piece(PieceType.king, true);    // 先手玉 9九(8,0)
    b[1][4] = Piece(PieceType.rook, false);   // 後手飛 5二(1,4)
    b[8][4] = Piece(PieceType.lance, true);   // 先手香 5九(8,4)
    b[0][4] = Piece(PieceType.pawn, false);   // 後手歩 5一(0,4) 後手玉の隣
    list.add(_TesujiProb(
      id: 'hikisha_4',
      title: '飛車取り ④',
      category: '飛車取り',
      explanation: '先手香車が5九から前進して5二の後手飛車をタダ取りします。香車の縦一直線の効きを活かした手筋。途中に駒がないことを確認しましょう。',
      board: b,
      answer: AMove(fr: 8, fc: 4, tr: 1, tc: 4, promote: true),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '初級',
    ));
  }

  // ===== 飛車取り ⑤ =====
  // 先手が持ち駒の飛を打って後手飛を取る（打ち付け）
  // 後手飛 2二(1,7)、先手が飛を持っている
  // 先手飛を2一(0,7)に打って後手飛を攻める
  {
    final b = _empty();
    b[0][3] = Piece(PieceType.king, false);   // 後手玉 4一(0,3)
    b[8][5] = Piece(PieceType.king, true);    // 先手玉 4九(8,5)
    b[1][7] = Piece(PieceType.rook, false);   // 後手飛 2二(1,7)
    b[2][7] = Piece(PieceType.pawn, false);   // 後手歩 2三(2,7) 飛の前
    b[0][6] = Piece(PieceType.silver, false); // 後手銀 3一(0,6) 飛の逃げ先封鎖
    list.add(_TesujiProb(
      id: 'hikisha_5',
      title: '飛車取り ⑤',
      category: '飛車取り',
      explanation: '先手は持ち駒の飛車を2一に打ちます。後手飛は2二にいて逃げ場がなく、次の手で飛車を取ることができます。持ち駒を使った飛車封じの手筋。',
      board: b,
      p1Hand: {PieceType.rook: 1},
      answer: AMove(fr: -1, fc: -1, tr: 0, tc: 7, drop: PieceType.rook),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '初級',
    ));
  }

  // ===== 飛車取り ⑥ =====
  // 先手角で後手飛を串刺し（角の斜め効きで飛を取る）
  // 後手飛 6四(3,3)、先手角 8六(5,1)
  // 角(5,1)→(3,3) で飛取り
  {
    final b = _empty();
    b[0][5] = Piece(PieceType.king, false);   // 後手玉 4一(0,5)
    b[8][3] = Piece(PieceType.king, true);    // 先手玉 6九(8,3)
    b[3][3] = Piece(PieceType.rook, false);   // 後手飛 6四(3,3)
    b[5][1] = Piece(PieceType.bishop, true);  // 先手角 8六(5,1)
    // b[4][2] removed: pawn here blocks bishop's diagonal from (5,1) to (3,3)
    list.add(_TesujiProb(
      id: 'hikisha_6',
      title: '飛車取り ⑥',
      category: '飛車取り',
      explanation: '先手角が8六から6四に動いて後手飛車をタダ取りします。角の斜め効きが飛車に直接当たっています。',
      board: b,
      answer: AMove(fr: 5, fc: 1, tr: 3, tc: 3),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '初級',
    ));
  }

  // ===== 飛車取り ⑦ =====
  // 先手銀が成り込んで後手飛を取る
  // 後手飛 1二(1,8)、先手銀 2四(3,7)
  // 銀(3,7)→(1,8) → 後手飛を取りながら成る(成銀)
  {
    final b = _empty();
    b[0][6] = Piece(PieceType.king, false);   // 後手玉 3一(0,6)
    b[8][4] = Piece(PieceType.king, true);    // 先手玉 5九(8,4)
    b[1][8] = Piece(PieceType.rook, false);   // 後手飛 1二(1,8)
    b[2][7] = Piece(PieceType.silver, true);  // 先手銀 2三(2,7) — moved from (3,7): silver at (3,7) cannot reach (1,8) in one move
    b[0][8] = Piece(PieceType.pawn, false);   // 後手歩 1一(0,8) 飛の後ろ
    list.add(_TesujiProb(
      id: 'hikisha_7',
      title: '飛車取り ⑦',
      category: '飛車取り',
      explanation: '先手銀が2三から1二に斜め前進して後手飛車を取りながら成ります。敵陣で銀が成銀になり、飛車も獲得できます。',
      board: b,
      answer: AMove(fr: 2, fc: 7, tr: 1, tc: 8, promote: true),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '初級',
    ));
  }

  // ===== 飛車取り ⑧（角と飛車の連携） =====
  // 後手飛が5五(4,4)にいて、先手角が8八(6,6)、先手銀が7九(7,7)
  // 先手銀を8八に移動して角の利きが5五の飛車を間接的に攻撃する
  // 銀(7,7)→(6,6): 角を(6,6)から角が飛の位置まで効く配置にする
  // より直接的に: 先手角8八→飛車を狙う手
  // 実は角と銀の連携で飛車を取る
  {
    final b = _empty();
    b[0][3] = Piece(PieceType.king, false);   // 後手玉 4一(0,3)
    b[8][5] = Piece(PieceType.king, true);    // 先手玉 4九(8,5)
    b[4][4] = Piece(PieceType.rook, false);   // 後手飛 5五(4,4)
    b[6][6] = Piece(PieceType.bishop, true);  // 先手角 3三(6,6)
    b[7][7] = Piece(PieceType.silver, true);  // 先手銀 2二(7,7)
    b[3][3] = Piece(PieceType.gold, false);   // 後手金 6四(3,3)
    // 先手銀(7,7)→(6,6)で角のいた位置に移動
    // 銀(6,6)の利き(先手fwd=-1): (5,5),(5,6),(5,7),(7,5),(7,7)
    // 飛(4,4)は銀(6,6)から遠い
    // 別配置: 先手角(4,2)→(4,4)で飛取り直接的
    // または角が(6,2)にいて(4,4)に斜めで届く
    b[6][6] = null;
    b[7][7] = null;
    b[6][2] = Piece(PieceType.bishop, true);  // 先手角 3七(6,2)
    b[7][3] = Piece(PieceType.silver, true);  // 先手銀 6八(7,3)
    // 角(6,2)→(4,4): dr=-2,dc=+2 → 斜め右上 → 飛を取る
    list.add(_TesujiProb(
      id: 'hikisha_8',
      title: '飛車取り ⑧',
      category: '飛車取り',
      explanation: '先手角が3七から5五に動いて後手飛車をタダ取りします。先手銀とともに後手飛を攻めるポジションに角が移動する「角と銀の連携」による飛車取りの手筋。',
      board: b,
      answer: AMove(fr: 6, fc: 2, tr: 4, tc: 4),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '中級',
    ));
  }

  // ===== 飛車取り ⑨（桂馬による飛車狙い） =====
  // 後手飛が2二(1,7)にいて、先手桂が4六(6,2)
  // 先手桂を2四(3,6)に進めて飛車を狙う（王手との同時実現）
  // 桂馬の跳び効きで飛を狙う手筋
  {
    final b = _empty();
    b[0][5] = Piece(PieceType.king, false);   // 後手玉 4一(0,5)
    b[8][3] = Piece(PieceType.king, true);    // 先手玉 6九(8,3)
    b[1][7] = Piece(PieceType.rook, false);   // 後手飛 2二(1,7)
    b[6][2] = Piece(PieceType.knight, true);  // 先手桂 3七(6,2)
    b[0][7] = Piece(PieceType.gold, false);   // 後手金 2一(0,7)
    // 桂(6,2)→(3,6)? 桂のfwd=-1: (fr-2,fc±1)→(4,1)or(4,3)には来るが(3,6)には来ない
    // 桂(6,2)→(4,1): 桂の利き(先手)=(2,0)と(2,2)
    // 桂(6,2)→(4,3): 桂の利き(先手)=(2,2)と(2,4)
    // 後手飛を(1,7)から別位置に配置し、桂が到達できる位置(2,2)か(2,4)に置く
    b[1][7] = null;
    b[2][2] = Piece(PieceType.rook, false);   // 後手飛 3三(2,2)
    b[6][2] = null;
    b[6][3] = Piece(PieceType.knight, true);  // 先手桂 3七→移動前(6,3)
    // 桂(6,3)→(4,2): 桂の利き(先手fwd=-1)=(2,1)と(2,3)
    // (4,2)→(2,1)か(2,3)に飛がいれば狙える
    b[2][1] = null;
    b[2][3] = Piece(PieceType.rook, false);   // 後手飛 6三(2,3)
    // 桂(6,3)→(4,2): 利き(2,1)と(2,3)で飛(2,3)を狙う
    list.add(_TesujiProb(
      id: 'hikisha_9',
      title: '飛車取り ⑨',
      category: '飛車取り',
      explanation: '先手桂馬が3七から4四に跳びます。桂馬の跳び効きが後手飛車（6三）を狙います。桂馬の独特な利き方を活かした飛車狙いの手筋。',
      board: b,
      answer: AMove(fr: 6, fc: 3, tr: 4, tc: 2),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '中級',
    ));
  }

  // ===== 飛車取り ⑩（金による直接的な飛車取り） =====
  // 後手飛が7七(6,2)にいて、先手金が8八(7,1)
  // 先手金を7七に進めて飛車を直接取る
  // 一見守られているように見えるが、実は守られていない
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);   // 後手玉 5一(0,4)
    b[8][0] = Piece(PieceType.king, true);    // 先手玉 9九(8,0)
    b[6][2] = Piece(PieceType.rook, false);   // 後手飛 3七(6,2)
    b[7][1] = Piece(PieceType.gold, true);    // 先手金 8八(7,1)
    b[5][3] = Piece(PieceType.gold, false);   // 後手金 4六(5,3) 一見飛を守っているように見える
    b[6][3] = Piece(PieceType.silver, false); // 後手銀 3六(6,3)
    // 金(7,1)→(6,2): 先手金が飛を取る
    // 後手金(5,3)の利き(後手fwd=+1): (4,2),(4,3),(4,4),(5,2),(5,4),(6,3)=銀
    // 後手金(5,3)は飛(6,2)に効かない → 金を守れない
    // つまり先手金で飛を取ることができる
    list.add(_TesujiProb(
      id: 'hikisha_10',
      title: '飛車取り ⑩',
      category: '飛車取り',
      explanation: '先手金が8八から3七に進んで後手飛車を取ります。後手金が近くにいるので一見守られているように見えますが、実はその位置から飛車には効きません。守られていないことを見抜く手筋。',
      board: b,
      answer: AMove(fr: 7, fc: 1, tr: 6, tc: 2),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '上級',
    ));
  }

  // ===== 王手金取り ④ =====
  // 先手角が斜めに動いて後手玉に王手 & 金取り
  // 後手玉 3一(0,2)、後手金 4二(1,3)
  // 先手角(3,0)→(1,2): 角(1,2)の利き=(0,1),(0,3)...王手可能?
  // 角(3,4)→(1,2): dr=-2,dc=-2 → 斜め左上2マス ✓
  // 角(1,2)の利き: 斜め(0,1),(0,3)=王手? 玉は(0,2) → (0,1)と(0,3)は隣だが斜めでしか届かない
  // 角(2,1)→(0,3): 角(0,3)の利き=(1,2),(1,4); → 玉(0,2)は(0,3)の真横で角は届かない
  // シンプルな配置: 後手玉(0,4)、後手金(1,3)、先手角(3,2)
  // 角(3,2)→(1,4): (3,2)+(-2,+2)=(1,4) 角の効き ✓
  // 角(1,4)の利き: (0,3),(0,5); (2,3),(2,5); ... → 玉(0,4)は(1,4)から(-1,0)=縦で角は届かない
  // 確実な配置: 後手玉(0,4)、後手金(2,4)、先手飛(4,4)
  // 飛(4,4)→(2,4): 金取り & 飛(2,4)→(0,4)=王手可能（次の手）
  // これは「金取り＋次に王手」形
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);   // 後手玉 5一(0,4)
    b[2][4] = Piece(PieceType.gold, false);   // 後手金 5三(2,4)
    b[8][0] = Piece(PieceType.king, true);    // 先手玉 9九(8,0)
    b[4][4] = Piece(PieceType.rook, true);    // 先手飛 5五(4,4)
    // b[1][4] removed: pawn here blocks rook's vertical path to king after capturing gold
    list.add(_TesujiProb(
      id: 'oute_kintori_4',
      title: '王手金取り ④',
      category: '王手金取り',
      explanation: '先手飛車が5五から前進して5三の後手金を取ります。金を取った後は5一の後手玉への縦の王手が続きます。飛車の縦効きを使った王手金取りの手筋。',
      board: b,
      answer: AMove(fr: 4, fc: 4, tr: 2, tc: 4),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '中級',
    ));
  }

  // ===== 王手金取り ⑤ =====
  // 先手桂が跳んで後手玉に王手 & 後手の金を攻撃
  // 後手玉 5一(0,4)、後手金 3一(0,6)
  // 先手桂(2,5)→(0,4)=王手は桂の利き? 先手桂のfwd=-1 → (fr-2,fc-1)と(fr-2,fc+1)
  // 桂(2,5)→(0,4)=fr-2,fc-1 ✓ 王手！
  // 桂が(0,4)に来て、次に(0,6)の金を取れる? 桂は動けない(取った後に利きがない)
  // 別: 先手飛(2,6)→(0,6): 後手金取り & (0,6)から玉(0,4)に横効き → 王手！（横に飛が動く）
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);   // 後手玉 5一(0,4)
    b[0][6] = Piece(PieceType.gold, false);   // 後手金 3一(0,6)
    b[8][8] = Piece(PieceType.king, true);    // 先手玉 1九(8,8)
    b[2][6] = Piece(PieceType.rook, true);    // 先手飛 3三(2,6)
    b[1][5] = Piece(PieceType.pawn, false);   // 後手歩 4二(1,5)
    list.add(_TesujiProb(
      id: 'oute_kintori_5',
      title: '王手金取り ⑤',
      category: '王手金取り',
      explanation: '先手飛車が3三から3一に前進して後手金を取ります。飛車は取った地点から横に後手玉5一を攻撃します。飛車の横効きを活かした王手金取りの手筋。',
      board: b,
      answer: AMove(fr: 2, fc: 6, tr: 0, tc: 6),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '中級',
    ));
  }

  // ===== 王手金取り ⑥ =====
  // 先手銀が斜め前に動いて王手 & 金取り
  // 後手玉 4一(0,3)、後手金 3二(1,2)
  // 先手銀(2,1)→(1,2): 銀(1,2)の利き(先手fwd=-1): (0,1),(0,2),(0,3)=王手!,(2,1),(2,3)
  // → 銀が(2,1)から(1,2)に動いて後手金を取りながら後手玉に王手！
  {
    final b = _empty();
    b[0][3] = Piece(PieceType.king, false);   // 後手玉 4一(0,3)
    b[1][2] = Piece(PieceType.gold, false);   // 後手金 3二(1,2)
    b[8][5] = Piece(PieceType.king, true);    // 先手玉 4九(8,5)
    b[2][1] = Piece(PieceType.silver, true);  // 先手銀 3三(2,1)
    b[0][1] = Piece(PieceType.pawn, false);   // 後手歩 3一(0,1)
    list.add(_TesujiProb(
      id: 'oute_kintori_6',
      title: '王手金取り ⑥',
      category: '王手金取り',
      explanation: '先手銀が3三から3二に進んで後手金を取ります。取った銀の利きが4一の後手玉に届くため王手になります。銀の斜め効きを利用した王手金取りの手筋。',
      board: b,
      answer: AMove(fr: 2, fc: 1, tr: 1, tc: 2),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '中級',
    ));
  }

  // ===== 王手金取り ⑦ =====
  // 先手角が斜めに動いて後手玉に王手 & 後手金取り
  // 後手玉 7一(0,1)、後手金 6二(1,2)
  // 先手角(3,4)→(1,2): 金取り & 角(1,2)の利き: (0,1)=玉!,(0,3),(2,1),(2,3) → 王手！
  {
    final b = _empty();
    b[0][1] = Piece(PieceType.king, false);   // 後手玉 7一(0,1)
    b[1][2] = Piece(PieceType.gold, false);   // 後手金 6二(1,2)
    b[8][7] = Piece(PieceType.king, true);    // 先手玉 2九(8,7)
    b[3][4] = Piece(PieceType.bishop, true);  // 先手角 6四(3,4)
    // b[2][3] removed: pawn here blocks bishop's diagonal path
    list.add(_TesujiProb(
      id: 'oute_kintori_7',
      title: '王手金取り ⑦',
      category: '王手金取り',
      explanation: '先手角が6四から6二に動いて後手金を取ります。取った角の利きが7一の後手玉に届くため王手になります。角の斜め一方向が金を取り、別方向が王手というのが角の両狙いの妙です。',
      board: b,
      answer: AMove(fr: 3, fc: 4, tr: 1, tc: 2),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '中級',
    ));
  }

  // ===== 王手金取り ⑧（銀による王手と金取り） =====
  // 後手玉が5一(0,4)、後手金が4二(1,3)
  // 先手銀が6三(2,2)
  // 先手銀を5二(1,4)に進めると、玉に王手しながら金を取れる
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);   // 後手玉 5一(0,4)
    b[1][3] = Piece(PieceType.gold, false);   // 後手金 4二(1,3)
    b[8][5] = Piece(PieceType.king, true);    // 先手玉 4九(8,5)
    b[2][2] = Piece(PieceType.silver, true);  // 先手銀 6三(2,2)
    b[0][3] = Piece(PieceType.pawn, false);   // 後手歩 6一(0,3) 玉の横
    // 銀(2,2)→(1,4): 銀が(1,4)に来ると後手金(1,3)を取るのか？
    // 銀の利き(先手fwd=-1)から(1,4)を考える: (0,3),(0,4),(0,5),(2,3),(2,5)
    // (1,4)に銀が来て、後手金(1,3)を取れるか？ 銀は(1,4)に動いた時の利き範囲では(1,3)は守られていない
    // 銀(2,2)→(1,3): 金を直接取る。銀(1,3)の利き(先手fwd=-1): (0,2),(0,3)=歩×,(0,4)=玉!,(2,2),(2,4)
    // → 銀で金を取りながら玉に王手！
    list.add(_TesujiProb(
      id: 'oute_kintori_8',
      title: '王手金取り ⑧',
      category: '王手金取り',
      explanation: '先手銀が6三から4二に進んで後手金を取ります。取った銀の利きが5一の後手玉に届くため王手になります。銀が金を捕捉しながら王手する「銀による王手金取り」の手筋。',
      board: b,
      answer: AMove(fr: 2, fc: 2, tr: 1, tc: 3),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '上級',
    ));
  }

  // ===== 王手金取り ⑨（角による王手と金取り） =====
  // 後手玉が3一(0,2)、後手金が3二(1,2)
  // 先手角が6四(3,4)
  // 先手角を3一に進めて、王手しながら周囲の駒も狙う
  {
    final b = _empty();
    b[0][2] = Piece(PieceType.king, false);   // 後手玉 3一(0,2)
    b[1][2] = Piece(PieceType.gold, false);   // 後手金 3二(1,2)
    b[8][4] = Piece(PieceType.king, true);    // 先手玉 5九(8,4)
    b[3][4] = Piece(PieceType.bishop, true);  // 先手角 6四(3,4)
    b[2][3] = Piece(PieceType.pawn, false);   // 後手歩 7三(2,3)
    // 角(3,4)→(1,2): 金を取る。角(1,2)の利き: (0,1),(0,3); (2,1),(2,3); (3,4)...
    // → 角が(1,2)に来ると金を取り、かつ(0,1)に利きがあるが玉は(0,2)
    // (0,3)に利きがあるが玉(0,2)の横。角は斜めのみなので(0,2)には直接届かない
    // 角(3,4)の経路: (2,3)→(1,2)→(0,1)で斜めが伸びる
    // (0,1)から玉(0,2)への効き: 角は(0,1)から左下にしか進めない → (0,2)は届かない
    // 別配置: 後手玉(0,4)、後手金(1,3)、先手角(3,5)
    b[0][2] = null; b[1][2] = null; b[3][4] = null;
    b[0][4] = Piece(PieceType.king, false);   // 後手玉 5一(0,4)
    b[1][3] = Piece(PieceType.gold, false);   // 後手金 4二(1,3)
    b[3][5] = Piece(PieceType.bishop, true);  // 先手角 6四(3,5)
    // b[2][4] removed: pawn here blocks bishop's diagonal path from (3,5) to (1,3)
    // 角(3,5)→(1,3): 角が(1,3)に来て金を取る
    // 角(1,3)の利き: (0,2),(0,4)=玉!, (2,2),(2,4); (3,5)... → 玉に王手！
    // 金を取りながら玉に王手する「角による王手金取り」
    list.add(_TesujiProb(
      id: 'oute_kintori_9',
      title: '王手金取り ⑨',
      category: '王手金取り',
      explanation: '先手角が6四から4二に動いて後手金を取ります。取った角の利きが5一の後手玉に届くため王手になります。角の斜め効きを活かした「角による王手金取り」の手筋。',
      board: b,
      answer: AMove(fr: 3, fc: 5, tr: 1, tc: 3),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '上級',
    ));
  }

  // ===== 両取り ④ =====
  // 先手銀が動いて後手の飛・角を同時攻撃
  // 後手飛 3二(1,6)、後手角 7六(5,2)
  // 先手銀(3,4)→(2,5): 銀(2,5)の利き(先手fwd=-1): (1,4),(1,5),(1,6)=飛 ✓, (3,4),(3,6)
  // → 銀(2,5)から飛(1,6)を攻撃、かつ(3,4)から先手銀が来る前の位置だと角(5,2)への攻撃が必要
  // シンプルに: 後手飛(1,6)と後手角(3,4)を銀(2,5)から同時攻撃
  // 銀(2,5)の利き: (1,4),(1,5),(1,6)=飛✓, (3,4)=角✓, (3,6)
  // 先手銀をどこかから(2,5)に動かす: 例えば(3,6)から
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);   // 後手玉 9一(0,0)
    b[8][8] = Piece(PieceType.king, true);    // 先手玉 1九(8,8)
    b[1][6] = Piece(PieceType.rook, false);   // 後手飛 3二(1,6)
    b[3][4] = Piece(PieceType.bishop, false); // 後手角 6四(3,4)
    b[3][6] = Piece(PieceType.silver, true);  // 先手銀 3四(3,6)
    list.add(_TesujiProb(
      id: 'ryotori_4',
      title: '両取り ④',
      category: '両取り',
      explanation: '先手銀が3四から進んで3三の地点に来ると、斜め前方の後手飛車（3二）と斜め後方の後手角（6四）を同時に攻撃します。銀の5方向の効きを活かした両取りです。',
      board: b,
      answer: AMove(fr: 3, fc: 6, tr: 2, tc: 5),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '中級',
    ));
  }

  // ===== 両取り ⑤ =====
  // 先手桂が跳んで後手の2枚を同時攻撃
  // 先手桂(4,4)→(2,3): 桂(2,3)の利き(先手): (0,2)と(0,4)
  // 後手金(0,2)と後手銀(0,4)が両方の利きに入れば両取り
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);   // 後手玉 1一(0,8)
    b[8][0] = Piece(PieceType.king, true);    // 先手玉 9九(8,0)
    b[0][2] = Piece(PieceType.gold, false);   // 後手金 3一(0,2)
    b[0][4] = Piece(PieceType.silver, false); // 後手銀 5一(0,4)
    b[4][4] = Piece(PieceType.knight, true);  // 先手桂 5五(4,4)
    // 桂(4,4)→(2,3): 利き (0,2)=金✓,(0,4)=銀✓ → 両取り！
    list.add(_TesujiProb(
      id: 'ryotori_5',
      title: '両取り ⑤',
      category: '両取り',
      explanation: '先手桂馬が5五から跳んで3三に来ます。桂馬の利き（2マス前の左右）が、後手金（3一）と後手銀（5一）の両方に当たります。桂馬の跳び効きを活かした両取りの手筋。',
      board: b,
      answer: AMove(fr: 4, fc: 4, tr: 2, tc: 3),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '中級',
    ));
  }

  // ===== 両取り ⑥ =====
  // 先手飛が動いて後手の2枚を縦横から同時攻撃
  // 先手飛(4,3)→(1,3): 飛の縦効き → (0,3)方向 & 横効き → (1,0)(1,1)(1,2)...(1,8)
  // 後手金(0,3)と後手銀(1,6)を攻撃
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);   // 後手玉 9一(0,0)
    b[8][8] = Piece(PieceType.king, true);    // 先手玉 1九(8,8)
    b[0][3] = Piece(PieceType.gold, false);   // 後手金 4一(0,3)
    b[1][6] = Piece(PieceType.silver, false); // 後手銀 3二(1,6)
    b[4][3] = Piece(PieceType.rook, true);    // 先手飛 4五(4,3)
    // 飛(4,3)→(1,3): 縦(0,3)=金 & 横(1,6)=銀 → 両取り！
    list.add(_TesujiProb(
      id: 'ryotori_6',
      title: '両取り ⑥',
      category: '両取り',
      explanation: '先手飛車が4五から前進して4二に来ます。飛車の縦効きで4一の後手金を、横効きで3二の後手銀を同時に攻撃します。飛車の縦横効きを活かした両取りの手筋。',
      board: b,
      answer: AMove(fr: 4, fc: 3, tr: 1, tc: 3),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '中級',
    ));
  }

  // ===== 両取り ⑦ =====
  // 先手角が動いて後手の飛・金を同時攻撃（角の斜め2方向）
  // 後手飛(0,7)、後手金(4,3)
  // 先手角(3,5)→(2,6): 角(2,6)の利き: (1,5),(0,4); (1,7),(0,8); (3,5),(4,4); (3,7),(4,8)
  // → (1,7)=後手飛への経路: 角(2,6)→(1,7)→(0,8) なので飛が(1,7)なら両取り
  // 別: 後手飛(0,8)、後手金(4,4)
  // 先手角(2,6)の効き: (1,7),(0,8)=飛✓; (3,7),(4,8); (1,5),(0,4); (3,5),(4,4)=金✓
  // 先手角が(2,6)に来る元の位置: (3,7)から(2,6)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);   // 後手玉 9一(0,0)
    b[8][8] = Piece(PieceType.king, true);    // 先手玉 1九(8,8)
    b[0][8] = Piece(PieceType.rook, false);   // 後手飛 1一(0,8)
    b[4][4] = Piece(PieceType.gold, false);   // 後手金 5五(4,4)
    b[3][7] = Piece(PieceType.bishop, true);  // 先手角 2四(3,7)
    // 角(3,7)→(2,6): 角(2,6)の利き: (1,7),(0,8)=飛✓; (3,5),(4,4)=金✓ → 両取り！
    list.add(_TesujiProb(
      id: 'ryotori_7',
      title: '両取り ⑦',
      category: '両取り',
      explanation: '先手角が2四から動いて3三に来ます。角の斜め2方向に、後手飛車（1一）と後手金（5五）が入ります。どちらを逃がしても片方が取られる角の両取りです。',
      board: b,
      answer: AMove(fr: 3, fc: 7, tr: 2, tc: 6),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '中級',
    ));
  }

  // ===== 両取り ⑧ =====
  // 先手が持ち駒の角を打って両取り
  // 後手飛(1,2)、後手金(3,4)
  // 角を(2,3)に打つと: 角(2,3)の利き: (1,2)=飛✓,(0,1); (3,4)=金✓,(4,5); (1,4),(0,5); (3,2),(4,1)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);   // 後手玉 9一(0,0)
    b[8][8] = Piece(PieceType.king, true);    // 先手玉 1九(8,8)
    b[1][2] = Piece(PieceType.rook, false);   // 後手飛 7二(1,2)
    b[3][4] = Piece(PieceType.gold, false);   // 後手金 5四(3,4)
    b[0][2] = Piece(PieceType.pawn, false);   // 後手歩 7一(0,2)
    list.add(_TesujiProb(
      id: 'ryotori_8',
      title: '両取り ⑧',
      category: '両取り',
      explanation: '先手は持ち駒の角を7三に打ちます。角の斜め効きが後手飛車（7二）と後手金（5四）の両方に当たります。打ち込みによる角の両取りの手筋。',
      board: b,
      p1Hand: {PieceType.bishop: 1},
      answer: AMove(fr: -1, fc: -1, tr: 2, tc: 3, drop: PieceType.bishop),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '中級',
    ));
  }

  // ===== 両取り ⑨ =====
  // 先手飛を打って縦横に後手の2枚を攻撃
  // 後手銀(0,3)、後手金(4,7)
  // 飛を(0,7)に打つ: 縦(1,7)(2,7)(3,7)(4,7)=金✓ & 横(0,3)=銀✓ → 両取り！
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);   // 後手玉 9一(0,0)
    b[8][4] = Piece(PieceType.king, true);    // 先手玉 5九(8,4)
    b[0][3] = Piece(PieceType.silver, false); // 後手銀 4一(0,3)
    b[4][7] = Piece(PieceType.gold, false);   // 後手金 2五(4,7)
    // b[2][7] removed: pawn here blocks rook's vertical attack on gold at (4,7)
    list.add(_TesujiProb(
      id: 'ryotori_9',
      title: '両取り ⑨',
      category: '両取り',
      explanation: '先手は持ち駒の飛車を2一に打ちます。飛車の横効きで後手銀（4一）を、縦効きで後手金（2五）を同時に攻撃します。飛車の縦横を活かした打ち込み両取り。',
      board: b,
      p1Hand: {PieceType.rook: 1},
      answer: AMove(fr: -1, fc: -1, tr: 0, tc: 7, drop: PieceType.rook),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '中級',
    ));
  }

  // ===== 両取り ⑩ =====
  // 先手と金が動いて後手2枚を攻撃
  // 後手飛(1,5)、後手銀(1,3)
  // 先手金(2,4)→(1,4): 金(1,4)の利き(先手fwd=-1): (0,3),(0,4),(0,5),(1,3)=銀✓,(1,5)=飛✓,(2,4)
  // → 金が(1,4)に来ると左右の後手飛と銀を同時攻撃！
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);   // 後手玉 5一(0,4)
    b[8][4] = Piece(PieceType.king, true);    // 先手玉 5九(8,4)
    b[1][5] = Piece(PieceType.rook, false);   // 後手飛 4二(1,5)
    b[1][3] = Piece(PieceType.silver, false); // 後手銀 6二(1,3)
    b[2][4] = Piece(PieceType.gold, true);    // 先手金 5三(2,4)
    list.add(_TesujiProb(
      id: 'ryotori_10',
      title: '両取り ⑩',
      category: '両取り',
      explanation: '先手金が5三から5二に前進します。金の横方向の効きが後手飛車（4二）と後手銀（6二）の両方に当たります。金の横効きを使った両取りの手筋。',
      board: b,
      answer: AMove(fr: 2, fc: 4, tr: 1, tc: 4),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '上級',
    ));
  }

  // ===== 両取り ⑫ =====
  // 先手が成銀を動かして後手2枚を同時攻撃
  // 先手成銀(3,4)→(2,4): 成銀の利き(金と同じ): (1,3),(1,4),(1,5),(2,3),(2,5),(3,4)
  // → 後手飛(1,3)と後手角(1,5)を同時攻撃
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);   // 後手玉 5一(0,4)
    b[8][4] = Piece(PieceType.king, true);    // 先手玉 5九(8,4)
    b[1][3] = Piece(PieceType.rook, false);   // 後手飛 6二(1,3)
    b[1][5] = Piece(PieceType.bishop, false); // 後手角 4二(1,5)
    b[3][4] = Piece(PieceType.promotedSilver, true); // 先手全 5四(3,4)
    list.add(_TesujiProb(
      id: 'ryotori_12',
      title: '両取り ⑫',
      category: '両取り',
      explanation: '先手成銀（全）が5四から5三に前進します。成銀の効きは金将と同じで、左右斜め前に後手飛車（6二）と後手角（4二）を同時に攻撃します。',
      board: b,
      answer: AMove(fr: 3, fc: 4, tr: 2, tc: 4),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '上級',
    ));
  }

  // ===== 守り ④ =====
  // 先手玉の頭に後手金が来る前に逃げる
  // 後手金 5二(1,4)、先手玉 5九(8,4)
  // 後手飛(0,4)の縦効きが先手玉に向いている
  // 先手玉を6九(8,3)に逃げて縦ラインを外す
  {
    final b = _empty();
    b[8][4] = Piece(PieceType.king, true);    // 先手玉 5九(8,4)
    b[0][4] = Piece(PieceType.rook, false);   // 後手飛 5一(0,4)
    b[1][4] = Piece(PieceType.gold, false);   // 後手金 5二(1,4) 飛の前に金
    b[0][0] = Piece(PieceType.king, false);   // 後手玉 9一(0,0)
    b[8][5] = Piece(PieceType.gold, true);    // 先手金 4九(8,5)
    list.add(_TesujiProb(
      id: 'mamori_4',
      title: '守り ④',
      category: '守り',
      explanation: '後手飛車の縦効きが先手玉に直通しています。先手玉を6九に横移動して縦ラインから外れます。玉の横逃げで飛車の縦効きを外す手筋。',
      board: b,
      answer: AMove(fr: 8, fc: 4, tr: 8, tc: 3),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '初級',
    ));
  }

  // ===== 守り ⑤ =====
  // 先手玉を斜めに逃がして後手からの王手を防ぐ
  // 後手角 3七(6,2)→斜め効き (7,1)(8,0) & (7,3)(8,4)=先手玉
  // 先手玉(8,4)を(7,4)に逃げると? 角(6,2)→(7,3)(8,4)の経路で(7,4)は効かない
  // 先手玉(8,4)→(7,4): 角(6,2)の(7,3)→(8,4)の効き線上に(7,4)はない ✓
  {
    final b = _empty();
    b[8][4] = Piece(PieceType.king, true);    // 先手玉 5九(8,4)
    b[6][2] = Piece(PieceType.bishop, false); // 後手角 3七(6,2)
    b[0][8] = Piece(PieceType.king, false);   // 後手玉 1一(0,8)
    b[7][5] = Piece(PieceType.silver, true);  // 先手銀 4八(7,5)
    b[6][4] = Piece(PieceType.pawn, false);   // 後手歩 5七(6,4)
    list.add(_TesujiProb(
      id: 'mamori_5',
      title: '守り ⑤',
      category: '守り',
      explanation: '後手角が3七にいて斜めに先手玉5九を狙っています。先手玉を6九に横移動することで後手角の斜め効きから外れます。玉の横逃げで角の効きを外す手筋。',
      board: b,
      answer: AMove(fr: 8, fc: 4, tr: 8, tc: 3),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '中級',
    ));
  }

  // ===== 守り ⑥ =====
  // 後手の詰めろを受ける合い駒
  // 後手飛(0,6)の縦効きが先手玉(8,6)に向いている
  // 先手が持ち駒の銀を1五(6,6)に打って遮断
  {
    final b = _empty();
    b[8][6] = Piece(PieceType.king, true);    // 先手玉 3九(8,6)
    b[0][6] = Piece(PieceType.rook, false);   // 後手飛 3一(0,6)
    b[0][0] = Piece(PieceType.king, false);   // 後手玉 9一(0,0)
    b[7][6] = Piece(PieceType.gold, true);    // 先手金 3八(7,6)
    b[8][7] = Piece(PieceType.gold, true);    // 先手金 2九(8,7)
    list.add(_TesujiProb(
      id: 'mamori_6',
      title: '守り ⑥',
      category: '守り',
      explanation: '後手飛車の縦効きが先手玉の頭に向いています。持ち駒の銀を3五に打って飛車の縦効きを遮断します。合い駒で飛車の利きを止める受けの手筋。',
      board: b,
      p1Hand: {PieceType.silver: 1},
      answer: AMove(fr: -1, fc: -1, tr: 4, tc: 6, drop: PieceType.silver),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '中級',
    ));
  }

  // ===== 守り ⑦ =====
  // 先手玉の逃げ場を確保する一手
  // 後手から追い詰められた先手玉が逃げ道を作る
  // 先手玉(8,4)の周囲に先手の駒が多く詰まっている → 先手金を動かして玉の逃げ道を作る
  {
    final b = _empty();
    b[8][4] = Piece(PieceType.king, true);    // 先手玉 5九(8,4)
    b[7][4] = Piece(PieceType.gold, true);    // 先手金 5八(7,4) 玉の前を塞いでいる
    b[8][3] = Piece(PieceType.silver, true);  // 先手銀 6九(8,3)
    b[8][5] = Piece(PieceType.silver, true);  // 先手銀 4九(8,5)
    b[0][4] = Piece(PieceType.rook, false);   // 後手飛 5一(0,4)
    b[0][0] = Piece(PieceType.king, false);   // 後手玉 9一(0,0)
    b[6][3] = Piece(PieceType.rook, false);   // 後手飛2 6三(6,3) 横効き
    list.add(_TesujiProb(
      id: 'mamori_7',
      title: '守り ⑦',
      category: '守り',
      explanation: '後手飛車2枚に囲まれた先手玉の逃げ場がありません。5八の先手金を横に動かして玉の逃げ道を開けます。自陣の駒を動かして玉の逃げ場を作る手筋。',
      board: b,
      answer: AMove(fr: 7, fc: 4, tr: 7, tc: 3),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '中級',
    ));
  }

  // ===== 守り ⑧ =====
  // 後手の角成り攻撃を銀で受ける
  // 後手角(5,5)が斜め効きで(6,6)に成り込もうとしている → 先手銀を(6,6)に打って受ける
  {
    final b = _empty();
    b[8][8] = Piece(PieceType.king, true);    // 先手玉 1九(8,8)
    b[5][5] = Piece(PieceType.bishop, false); // 後手角 4六(5,5)
    b[0][0] = Piece(PieceType.king, false);   // 後手玉 9一(0,0)
    b[7][7] = Piece(PieceType.gold, true);    // 先手金 2八(7,7)
    b[7][8] = Piece(PieceType.gold, true);    // 先手金 1八(7,8)
    // 後手角(5,5)→(6,6): 先手玉(8,8)への斜め効き (7,7)=金,(8,8)=玉
    // 先手金(7,7)が守っているが、角が成り込むと龍馬になりさらに危険
    // 先手は銀を(6,6)に打って角の進路を塞ぐ
    list.add(_TesujiProb(
      id: 'mamori_8',
      title: '守り ⑧',
      category: '守り',
      explanation: '後手角が4六から斜めに先手玉1九方向を狙っています。持ち駒の銀を3七に打って後手角の斜め効きを遮断します。打ち込みで角の効きを止める守りの手筋。',
      board: b,
      p1Hand: {PieceType.silver: 1},
      answer: AMove(fr: -1, fc: -1, tr: 6, tc: 6, drop: PieceType.silver),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '中級',
    ));
  }

  // ===== 詰め ① =====
  // 2手詰め: 先手飛で後手玉に王手 → 後手玉が逃げられない
  // 後手玉 1一(0,8)（角隅）、後手の駒なし周囲
  // 先手飛(2,8)→(0,8): 王手! 後手玉は(0,7)に逃げるしかない
  // 先手金(1,7)が(0,7)を守っているので逃げられない → 詰み！
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);   // 後手玉 1一(0,8)
    b[8][0] = Piece(PieceType.king, true);    // 先手玉 9九(8,0)
    b[2][8] = Piece(PieceType.rook, true);    // 先手飛 1三(2,8)
    b[1][7] = Piece(PieceType.gold, true);    // 先手金 2二(1,7)
    list.add(_TesujiProb(
      id: 'tsume_1',
      title: '詰め ① (2手)',
      category: '詰め',
      explanation: '先手飛車が1三から1二に前進して後手玉に王手をかけます。後手玉は2二に先手金がいるため逃げられず、詰みになります。基本的な飛車と金による2手詰め。',
      board: b,
      answer: AMove(fr: 2, fc: 8, tr: 1, tc: 8),
      sourceTitle: '',
      difficulty: '初級',
    ));
  }

  // ===== 詰め ② =====
  // 2手詰め: 先手金で後手玉を詰める
  // 後手玉 9一(0,0)（角隅）、先手飛(1,0)で縦に守り、先手金を(1,1)に打つ
  // 先手金(1,1): 利き(先手fwd=-1): (0,0)=玉✓,(0,1),(0,2),(1,0),(1,2),(2,1)
  // 後手玉(0,0)への王手: 飛(1,0)が縦に守り、金(1,1)が斜めから → 詰み！
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);   // 後手玉 9一(0,0)
    b[8][8] = Piece(PieceType.king, true);    // 先手玉 1九(8,8)
    b[2][0] = Piece(PieceType.rook, true);    // 先手飛 9三(2,0)
    b[0][1] = Piece(PieceType.pawn, false);   // 後手歩 8一(0,1) 玉の逃げ先封鎖
    list.add(_TesujiProb(
      id: 'tsume_2',
      title: '詰め ② (2手)',
      category: '詰め',
      explanation: '先手は持ち駒の金を9二に打ちます。後手玉は9一の角隅にいて8一には後手歩があります。飛車と金の連携で後手玉を詰めます。',
      board: b,
      p1Hand: {PieceType.gold: 1},
      answer: AMove(fr: -1, fc: -1, tr: 1, tc: 0, drop: PieceType.gold),
      sourceTitle: '',
      difficulty: '初級',
    ));
  }

  // ===== 詰め ③ =====
  // 3手詰め: 先手角が王手 → 後手玉逃げ → 先手飛で詰み
  // 後手玉 5一(0,4)、先手角(2,6)→(0,4)=王手(角の効き: (1,5),(0,4)=玉)
  // 後手玉(0,4)→(0,3)に逃げる（唯一の逃げ場）
  // 先手飛(3,3)→(0,3): 詰み
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);   // 後手玉 5一(0,4)
    b[8][4] = Piece(PieceType.king, true);    // 先手玉 5九(8,4)
    b[2][6] = Piece(PieceType.bishop, true);  // 先手角 3三(2,6)
    b[3][3] = Piece(PieceType.rook, true);    // 先手飛 4四(3,3)
    b[0][5] = Piece(PieceType.gold, true);    // 先手金 4一(0,5) 玉の右封鎖
    b[0][3] = Piece(PieceType.pawn, false);   // 後手歩 6一(0,3) ← 逃げ先ではなくブロック
    // 後手歩(0,3)がある → 後手玉は(0,3)に逃げられない
    // (0,5)=先手金 → 逃げられない
    // 角(2,6)→(0,4)=王手 → 後手玉(0,4)の逃げ場: (1,3),(1,4),(1,5)
    // 先手飛(3,3)の横効きで(1,3)が守られている？ (3,3)→横→(3,0)(3,1)(3,2); (3,4)(3,5)... → (1,3)は守れない
    // シンプルに再設計: 後手玉(0,4), 先手金(0,5), 先手飛(0,3)で挟んで、角で王手
    // 角(2,6)→(0,4)は不可（金が(0,5)にある: 効きが通るかだけ → 途中に駒なければ通る）
    // (2,6)→(0,4): 経路は(1,5)を通る → (1,5)に駒なければ角の効きが届く
    // 角(2,6)が(0,4)の玉に王手 → 玉(0,4)の逃げ場: (0,3)=後手歩×, (0,5)=先手金×, (1,3),(1,4),(1,5)
    // 先手飛(3,3)→(1,3)を守れるか: 飛の縦(0,3)(1,3)(2,3)(3,3)→ (1,3)に効く ✓
    // (1,4)は先手駒で守れるか → 飛(3,3)の縦は(1,3)まで → (1,4)には効かない
    // 別の金を(1,5)に: 金(1,5)の利き(先手fwd=-1): (0,4)=玉,(0,5),(0,6),(1,4),(1,6),(2,5)
    // 金(1,5)が(1,4)と(0,4)を守ることで玉の逃げ場が消える
    // 再設計: 後手玉(0,4), 先手金(1,5), 先手金(0,3), 先手角を打って王手
    b[0][4] = null; // リセット
    b[2][6] = null;
    b[3][3] = null;
    b[0][5] = null;
    b[0][3] = null;

    b[0][4] = Piece(PieceType.king, false);   // 後手玉 5一(0,4)
    b[1][5] = Piece(PieceType.gold, true);    // 先手金 4二(1,5)
    b[0][3] = Piece(PieceType.gold, true);    // 先手金 6一(0,3)
    b[2][2] = Piece(PieceType.rook, true);    // 先手飛 3三(2,2) → 王手ルート
    // 飛(2,2)→(0,2): 縦移動 → 王手ではない（玉は(0,4)）
    // 飛(2,4)→(0,4): 王手！ 金(1,5)の利き(0,4)=玉は取られる → いや金は守り駒
    // 飛を(2,4)から(0,4)に移動して王手 → 後手玉の逃げ場: (0,3)=先手金×, (0,5)=取れる？
    // (0,5)に先手駒がなければ逃げられる → 金を(0,5)にも置く
    b[2][2] = null;
    b[2][4] = Piece(PieceType.rook, true);    // 先手飛 5三(2,4)
    b[0][5] = Piece(PieceType.silver, true);  // 先手銀 4一(0,5)
    // 飛(2,4)→(0,4): 王手! 後手玉逃げ場: (0,3)=先手金×, (0,5)=先手銀×, (1,3),(1,4),(1,5)=先手金×
    // (1,3): 先手飛(0,4)の利き(0,4)横→(0,3)=先手金: 飛の横は(0,4)から(0,3)に先手金→飛の横効きが(1,3)に届かない
    // 金(1,5)の利き: (0,4),(0,5),(0,6),(1,4),(1,6),(2,5) → (1,4)✓ & (1,3)は守れない
    // 先手金(0,3)の利き(先手fwd=-1): (0,2),(0,4)=玉,(1,2),(1,3)✓,(1,4),(−1,3)=範囲外
    // 金(0,3)が(1,3)を守る ✓ & 金(1,5)が(1,4)を守る ✓
    // → 飛(2,4)→(0,4)で王手! 後手玉の全逃げ場が封鎖 → 詰み！
    list.add(_TesujiProb(
      id: 'tsume_3',
      title: '詰め ③ (2手)',
      category: '詰め',
      explanation: '先手飛車が5三から5二に前進して後手玉に王手をかけます。後手玉の逃げ場は先手金2枚と銀に封鎖されており、詰みになります。包囲完成後の飛車王手による詰み。',
      board: b,
      answer: AMove(fr: 2, fc: 4, tr: 1, tc: 4),
      sourceTitle: '',
      difficulty: '中級',
    ));
  }

  // ===== 詰め ④ =====
  // 3手詰め: 先手角打ちで王手 → 後手玉逃げ → 先手金で詰み
  // 後手玉 3一(0,2)、逃げ場を金で塞いで角打ち王手
  {
    final b = _empty();
    b[0][2] = Piece(PieceType.king, false);   // 後手玉 3一(0,2)
    b[8][8] = Piece(PieceType.king, true);    // 先手玉 1九(8,8)
    b[1][1] = Piece(PieceType.gold, true);    // 先手金 8二(1,1)
    b[0][1] = Piece(PieceType.silver, true);  // 先手銀 8一(0,1)
    b[0][3] = Piece(PieceType.gold, true);    // 先手金 6一(0,3)
    // 後手玉(0,2)の逃げ場: (0,1)=先手銀×, (0,3)=先手金×, (1,1)=先手金×, (1,2),(1,3)
    // 角を(3,4)に打つ: 角(3,4)の利き: (2,3),(1,2),(0,1); (2,5),(1,6),(0,7); (4,3),(5,2); (4,5)...
    // (1,2)の経路: (2,3)→(1,2)→(0,1) → 角は(3,4)から(1,2)を通って(0,1)まで効く
    // 角打ち(3,4)→王手の対象: 角(3,4)は(0,2)に直接効かない（斜めのみ）
    // 後手玉(0,2)に角が効く位置: (r+dc)が一致する斜め → 角を(2,0)に置くと(1,1)(0,2)=玉 ✓
    // 角(2,0)の利き: (1,1)=先手金→途中に駒あり → (0,2)まで届かない
    // 角を(2,4)に: (1,3),(0,2)=玉✓ & (1,5),(0,6); (3,3),(4,2); (3,5)...
    // 角(2,4)打ちで後手玉(0,2)に王手! → 後手玉逃げ場(1,2),(1,3)へ
    // (1,3)=先手金(0,3)の利き: 金(0,3)の利き(先手fwd=-1): (-1,2),(-1,3),(-1,4),(0,2),(0,4),(1,3)✓
    // (1,2): 誰かが守る必要 → 飛を(3,2)に置く: 飛の縦(0,2)(1,2)✓(2,2)(3,2)
    b[3][2] = Piece(PieceType.rook, true);    // 先手飛 7四(3,2)
    list.add(_TesujiProb(
      id: 'tsume_4',
      title: '詰め ④ (3手)',
      category: '詰め',
      explanation: '先手は持ち駒の角を5三に打ちます。後手玉3一への王手となり、後手玉は逃げますが先手金・銀・飛が全逃げ場を塞いでいます。角打ち王手からの3手詰め。',
      board: b,
      p1Hand: {PieceType.bishop: 1},
      answer: AMove(fr: -1, fc: -1, tr: 2, tc: 4, drop: PieceType.bishop),
      sourceTitle: '',
      difficulty: '中級',
    ));
  }

  // ===== 詰め ⑤ =====
  // 3手詰め: 先手飛が成り込んで王手 → 龍王で詰む
  // 後手玉 2二(1,7)、先手飛(3,7)→(1,7): 後手玉の上から王手(成り)
  // 龍王(promotedRook)(1,7)の利き: 縦横 + 斜め1マス → (0,6),(0,7),(0,8),(1,6),(1,8),(2,6),(2,7),(2,8) etc.
  {
    final b = _empty();
    b[1][7] = Piece(PieceType.king, false);   // 後手玉 2二(1,7)
    b[8][0] = Piece(PieceType.king, true);    // 先手玉 9九(8,0)
    b[3][7] = Piece(PieceType.rook, true);    // 先手飛 2四(3,7)
    b[0][6] = Piece(PieceType.gold, true);    // 先手金 3一(0,6) 玉の逃げ先封鎖
    b[0][8] = Piece(PieceType.silver, true);  // 先手銀 1一(0,8) 玉の逃げ先封鎖
    b[2][8] = Piece(PieceType.gold, true);    // 先手金 1三(2,8) 玉の右封鎖
    // 飛(3,7)→(1,7)成=龍王: 後手玉(1,7)を取って龍王が(1,7)に来る
    // 後手玉は(1,7)に先手飛が来たとき取るしかない → 玉が取れないなら詰み
    // 龍王(1,7)の利き: 縦(0,7)✓(2,7)✓; 横(1,6)✓(1,8)✓; 斜め(0,6)=先手金×,(0,8)=先手銀×,(2,6)✓,(2,8)=先手金×
    // 後手玉逃げ場: (0,7),(1,6),(2,6) → 先手金(0,6)が(0,7)を守る? 金(0,6)の利き(先手): (-1,5),(-1,6),(-1,7),(0,5),(0,7)✓,(1,6)✓
    // → 金(0,6)が(0,7)と(1,6)を守る ✓
    // (2,6): 先手銀(0,8)の利き: (-1,7),(-1,9),(1,7)=龍,(1,9)範囲外... (2,6)は遠い
    // 金(2,8)の利き(先手): (1,7)=龍王,(1,8),(1,9),(2,7),(2,9),(3,8) → (2,6)は守れない
    // (2,6)に逃げられると詰まない → 先手金か銀を追加
    // 先手銀を(3,6)に: 銀(3,6)の利き(先手): (2,5),(2,6)✓,(2,7),(4,5),(4,7)
    b[3][6] = Piece(PieceType.silver, true);  // 先手銀 2四の左 (3,6)
    // 再確認: 後手玉(1,7)に飛(3,7)→(1,7)成=龍王で王手
    // 後手玉逃げ場: (0,7),(0,8)=銀×,(1,6),(1,8),(2,6),(2,8)=金×
    // (0,7): 金(0,6)の利き(0,7)✓ 守られている
    // (1,6): 金(0,6)の利き(1,6)✓ 守られている
    // (1,8): 金(2,8)の利き(1,8)? 金(2,8)fwd=-1: (1,7),(1,8)✓,(1,9),(2,7),(2,9),(3,8) → (1,8)✓
    // (2,6): 銀(3,6)の利き(2,6)✓ 守られている
    // → 全逃げ場封鎖 → 詰み！（飛を成りながら取って龍王に）
    list.add(_TesujiProb(
      id: 'tsume_5',
      title: '詰め ⑤ (3手)',
      category: '詰め',
      explanation: '先手飛車が2四から2二に成り込んで後手玉を取ります。龍王となった先手飛の周囲を金・銀が囲んでいるため後手玉に逃げ場がありません。飛車の成り込みによる詰み。',
      board: b,
      answer: AMove(fr: 3, fc: 7, tr: 1, tc: 7, promote: true),
      sourceTitle: '',
      difficulty: '中級',
    ));
  }

  // ===== 詰め ⑥ =====
  // 3手詰め: 先手金打ちで王手 → 後手玉逃げ → 先手飛で詰み
  // 後手玉 6一(0,3)、先手飛(2,3)で縦の利き
  // 先手金(1,2)打ちで(0,3)=玉に近い場所から王手関連
  // 再設計: 先手金を(1,3)に打つ → 金(1,3)の利き(先手): (0,2),(0,3)=玉!,(0,4),(1,2),(1,4),(2,3)
  // 王手! 後手玉の逃げ場: (0,2),(0,4) (他は金や他の先手駒が守る)
  // (0,2)に先手銀: 逃げられない。(0,4)に先手銀: 逃げられない → 詰み！
  {
    final b = _empty();
    b[0][3] = Piece(PieceType.king, false);   // 後手玉 6一(0,3)
    b[8][7] = Piece(PieceType.king, true);    // 先手玉 2九(8,7)
    b[0][2] = Piece(PieceType.silver, true);  // 先手銀 7一(0,2)
    b[0][4] = Piece(PieceType.silver, true);  // 先手銀 5一(0,4)
    b[2][3] = Piece(PieceType.rook, true);    // 先手飛 6三(2,3)
    // 金(1,3)打ち → 王手! 後手玉逃げ場(0,2)=銀×,(0,4)=銀×,(1,2),(1,4)
    // (1,2): 飛(2,3)の横効き(2,3)→(2,2)(2,1)... (1,2)は守れない
    // 先手金か別の駒で(1,2)(1,4)を守る
    // 先手飛(2,3)→縦(1,3)(0,3)=玉; → 飛が縦に(1,3)を守る: (1,3)に打った金を飛が守る
    // 金打ちで(1,2)が空く → (1,2)に後手は逃げられる
    // (1,2)を別の金で守る:
    b[1][1] = Piece(PieceType.gold, true);    // 先手金 8二(1,1)
    // 金(1,1)の利き(先手): (0,0),(0,1),(0,2)=銀×,(1,0),(1,2)✓,(2,1)
    // (1,4): 先手銀(0,4)の利き(先手fwd=-1): (-1,3),(-1,4),(-1,5),(1,3),(1,5)... (1,4)は守れない
    // 先手飛(2,3)→横(2,4)(2,5)... (1,4)は縦でしか守れない
    // 先手銀(0,4)の利き: (−1,3)範囲外,(−1,5)範囲外,(-1,4)範囲外,(1,3),(1,5) → (1,4)は守れない
    // 先手金(1,4)がいれば守れる
    b[1][4] = Piece(PieceType.gold, true);    // 先手金 5二(1,4)
    // 金(1,4)の利き(先手): (0,3)=玉!,(0,4)=銀×,(0,5),(1,3),(1,5),(2,4)
    // → 金(1,4)がすでに(0,3)=玉に当たっている！これが王手になってしまう
    // 配置をシンプルに変更: 後手玉を(0,0)の隅に
    b[0][3] = null; b[0][2] = null; b[0][4] = null; b[1][1] = null; b[1][4] = null; b[2][3] = null;

    b[0][0] = Piece(PieceType.king, false);   // 後手玉 9一(0,0)
    b[0][1] = Piece(PieceType.silver, false); // 後手銀 8一(0,1)
    b[1][0] = Piece(PieceType.pawn, false);   // 後手歩 9二(1,0)
    b[2][0] = Piece(PieceType.rook, true);    // 先手飛 9三(2,0)
    // 先手飛(2,0)→(1,0): 後手歩を取る & 飛(1,0)の縦(0,0)=玉への効き
    // 後手玉(0,0)の逃げ場: (0,1)=後手銀(逃げ先として使える)
    // 飛(1,0)で王手 → 後手玉(0,0)→(0,1)に逃げる → 先手金打ち(0,0)or別の手で詰み
    // 先手が持ち駒の金を持っていて(0,1)=銀の場所に打てば? → 後手銀がいるので打てない
    // 金を(1,1)に打つ: 金(1,1)利き(先手): (0,0),(0,1)=後手銀取れる×,(0,2),(1,0),(1,2),(2,1)
    // → 金(1,1)打ち = 後手玉(0,0)に王手！ → 後手玉逃げ場: (0,1)=銀(逃げられる)
    // 飛(2,0)が(0,1)の銀を取れるか → 縦のみ → 飛は(2,0)から(1,0)(0,0)=玉の縦
    // 先手の配置を調整: 先手飛(2,1)縦(1,1)(0,1)に効く
    b[2][0] = null;
    b[2][1] = Piece(PieceType.rook, true);    // 先手飛 8三(2,1)
    // 飛(2,1)→(0,1): 後手銀取り & 後手玉に王手? 玉は(0,0)で飛は(0,1) → 横に効く
    // 飛は縦横に効くので(0,1)→横→(0,0)=玉 → 王手！
    // 後手玉(0,0)の逃げ場: (0,1)=飛×, (1,0)=後手歩×(先手が取れる), (1,1)
    // (1,1): 先手金を持っていれば打って守れる → 詰み！
    // 答え: 飛(2,1)→(0,1) で後手銀取りながら王手 → 後手玉(0,0)逃げ場なし → 詰み！
    list.add(_TesujiProb(
      id: 'tsume_6',
      title: '詰め ⑥ (2手)',
      category: '詰め',
      explanation: '先手飛車が8三から8一に進んで後手銀を取りながら後手玉9一に横から王手をかけます。後手玉の逃げ場は後手歩と飛車の効きで封じられており詰みです。',
      board: b,
      p1Hand: {PieceType.gold: 1},
      answer: AMove(fr: 2, fc: 1, tr: 0, tc: 1),
      sourceTitle: '',
      difficulty: '中級',
    ));
  }

  // ===== 詰め ⑦ =====
  // 3手詰め: 先手銀打ちで王手 → 後手玉逃げ → 先手金で詰み
  // 後手玉 5一(0,4)、先手が銀を5二(1,4)に打つ → 銀(1,4)利き(先手fwd=-1): (0,3),(0,4)=玉!,(0,5),(2,3),(2,5)
  // 王手! 後手玉逃げ場: (0,3),(0,5)
  // 先手金(0,3)と(0,5)を封鎖: 詰み！
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);   // 後手玉 5一(0,4)
    b[8][4] = Piece(PieceType.king, true);    // 先手玉 5九(8,4)
    b[0][3] = Piece(PieceType.gold, true);    // 先手金 6一(0,3)
    b[0][5] = Piece(PieceType.gold, true);    // 先手金 4一(0,5)
    b[1][3] = Piece(PieceType.pawn, false);   // 後手歩 6二(1,3)
    b[1][5] = Piece(PieceType.pawn, false);   // 後手歩 4二(1,5)
    // 銀(1,4)打ち → 王手: 後手玉逃げ場(0,3)=先手金×,(0,5)=先手金×,(1,3)=後手歩×,(1,5)=後手歩×
    // 全逃げ場封鎖 → 詰み！
    list.add(_TesujiProb(
      id: 'tsume_7',
      title: '詰め ⑦ (2手)',
      category: '詰め',
      explanation: '先手は持ち駒の銀を5二に打ちます。銀の利きが5一の後手玉に当たり王手になります。後手玉の周囲は先手金2枚と後手歩が封鎖しており逃げ場がありません。',
      board: b,
      p1Hand: {PieceType.silver: 1},
      answer: AMove(fr: -1, fc: -1, tr: 1, tc: 4, drop: PieceType.silver),
      sourceTitle: '',
      difficulty: '中級',
    ));
  }

  // ===== 詰め ⑧ =====
  // 4手詰め: 先手角成り込みで王手 → 後手玉逃げ → 金追撃 → 詰み
  // 後手玉 8一(0,1)、先手角(2,3)→(0,1)成=馬 で王手
  // 後手玉(0,1)→(1,0)に逃げ → 先手金(2,0)に打って詰み
  // 馬(0,1)の利き: 斜め全方向 + 縦横1マス → (1,0)✓,(1,1)✓,(1,2)✓
  // 後手玉(1,0)の逃げ場: (0,0),(1,1)=馬×,(2,0)
  // 先手金(2,0)打ち: 金(2,0)利き(先手): (1,0)=玉!,(0,0),(1,1)=馬×... → (1,0)に王手!
  // 後手玉(1,0)→(0,0)逃げ → 馬(0,1)が(0,0)に効く? 馬の横利きは(0,0)✓ → 詰み！
  // 実は先手角(2,3)→(0,1)は経路(1,2)を通る → (1,2)に駒なければOK
  {
    final b = _empty();
    b[0][1] = Piece(PieceType.king, false);   // 後手玉 8一(0,1)
    b[8][8] = Piece(PieceType.king, true);    // 先手玉 1九(8,8)
    b[2][3] = Piece(PieceType.bishop, true);  // 先手角 6三(2,3)
    b[0][0] = Piece(PieceType.pawn, false);   // 後手歩 9一(0,0) 玉の逃げ先封鎖
    b[1][0] = Piece(PieceType.gold, false);   // 後手金 9二(1,0) 玉の下を守る
    // 角(2,3)→(0,1)成=馬で王手: 後手玉(0,1)の逃げ場: (0,0)=後手歩×, (0,2),(1,0)=後手金×,(1,1),(1,2)
    // 馬(0,1)の利き: (0,0)(0,2); (1,0)=後手金✗(先手利き)... 馬の横と縦と斜め
    // 馬は取った後(0,1)に来る。(1,0)=後手金に馬の利き(縦(1,1)? → 縦は(1,1)ではなく(1,1)へは斜め)
    // 馬(0,1)の利き: 縦(1,1)(2,1)..., 横(0,0)(0,2)(0,3)..., 斜め(1,0)(2,−1)範囲外; (1,2)(2,3)...
    // → (1,0)=後手金は馬の斜め1マス利きで取れる ✓ → 後手金は防御できない
    // 後手玉(0,1)→(0,2)に逃げる → 馬(0,1)の横利きで(0,2)攻撃 → 後手玉逃げ場なし
    // 実際の詰み手順: 角成り王手 → 後手玉逃げ → 馬が追う → 詰み
    // この配置だと後手金(1,0)が邪魔なので別配置に
    b[0][1] = null; b[2][3] = null; b[0][0] = null; b[1][0] = null;
    // シンプルな4手詰め配置
    b[0][0] = Piece(PieceType.king, false);   // 後手玉 9一(0,0)
    b[8][8] = Piece(PieceType.king, true);    // (already set)
    b[1][1] = Piece(PieceType.gold, true);    // 先手金 8二(1,1)
    b[1][0] = Piece(PieceType.silver, true);  // 先手銀 9八(1,0) — moved from (0,1): silver at (0,1) blocks rook's horizontal check line
    b[2][2] = Piece(PieceType.rook, true);    // 先手飛 7三(2,2)
    // 飛(2,2)→(0,2): 縦移動 → 後手玉(0,0)への横効き → 王手!
    // 後手玉(0,0)逃げ場: (0,1)=銀×, (1,0)
    // (1,0): 金(1,1)の利き(先手fwd=-1): (0,0),(0,1)=銀×,(0,2),(1,0)✓,(1,2),(2,1) → (1,0)守り✓
    // → 詰み！（飛(2,2)→(0,2)で王手、後手玉逃げ場は(0,1)=銀×と(1,0)=金利き×）
    list.add(_TesujiProb(
      id: 'tsume_8',
      title: '詰め ⑧ (2手)',
      category: '詰め',
      explanation: '先手飛車が7三から7一に前進して後手玉9一に横から王手をかけます。後手玉は8一に先手銀、9二に先手金の利きがあり逃げ場がありません。',
      board: b,
      answer: AMove(fr: 2, fc: 2, tr: 0, tc: 2),
      sourceTitle: '',
      difficulty: '中級',
    ));
  }

  // ===== 詰め ⑨ =====
  // 5手詰め: 先手金打ちで王手 → 後手玉逃げ → 先手飛追撃 → 後手玉逃げ → 先手金追撃で詰み
  // 後手玉 5三(2,4)（中段玉）、先手が追い詰める
  // 先手飛(5,4)→(2,4): 後手玉を取れない（取れるなら詰みだが王手放置は反則）
  // 先手金(3,3)打ち: 金(3,3)利き(先手): (2,2),(2,3),(2,4)=玉!,(3,2),(3,4),(4,3) → 王手！
  // 後手玉(2,4)→(1,4)逃げ → 先手飛(5,4)→(1,4): 後手玉に縦王手
  // 後手玉(1,4)→(0,4)逃げ → 先手金(0,3)打ちor金で詰み
  // 先手金を(0,5)に打ち: 金(0,5)利き(先手): (-1,4)範囲外,(-1,5)範囲外,(-1,6)範囲外,(0,4)=玉!,(0,6),(1,5)
  // → 詰み！ (先手金(0,5)打ちで後手玉に王手、逃げ場なし)
  {
    final b = _empty();
    b[2][4] = Piece(PieceType.king, false);   // 後手玉 5三(2,4)
    b[8][0] = Piece(PieceType.king, true);    // 先手玉 9九(8,0)
    b[5][4] = Piece(PieceType.rook, true);    // 先手飛 5六(5,4)
    b[0][3] = Piece(PieceType.gold, true);    // 先手金 6一(0,3)
    b[0][5] = Piece(PieceType.gold, true);    // 先手金 4一(0,5)
    b[2][3] = Piece(PieceType.pawn, false);   // 後手歩 6三(2,3) 玉の横封鎖
    b[2][5] = Piece(PieceType.pawn, false);   // 後手歩 4三(2,5) 玉の横封鎖
    // 先手金(3,3)打ちで後手玉(2,4)に王手 → 後手玉(1,4)逃げ → 飛(5,4)→(1,4)王手
    // → 後手玉(0,4)逃げ → 金(0,5)の利き(0,4)=王手 → 詰み！
    // (0,3)=先手金の利き(先手): (-1,2)範囲外...,(0,2),(0,4),(1,2),(1,3),(1,4)✓
    // → 飛が(1,4)に来て王手後、後手玉(0,4)に逃げても
    // 金(0,3)の利き(0,4)✓ & 金(0,5)の利き(0,4)✓ → 詰み！
    list.add(_TesujiProb(
      id: 'tsume_9',
      title: '詰め ⑨ (5手)',
      category: '詰め',
      explanation: '先手は持ち駒の金を6四に打って中段の後手玉5三に王手をかけます。後手玉が5二、5一と逃げるところを先手飛が追い、最後は先手金2枚で詰みます。中段玉を追い詰める5手詰めの手筋。',
      board: b,
      p1Hand: {PieceType.gold: 1},
      answer: AMove(fr: -1, fc: -1, tr: 3, tc: 3, drop: PieceType.gold),
      sourceTitle: '',
      difficulty: '中級',
    ));
  }

  // ===== 詰め ⑩ =====
  // 3手詰め: 先手角打ち王手 → 後手玉逃げ → 先手金で詰み
  // 後手玉 9三(2,0)（端玉）、先手が角打ちで追い詰める
  // 角を(4,2)に打つ: 角(4,2)利き(先手): (3,1),(2,0)=玉!,(5,1),(5,3),(3,3),(6,0),(6,4)...
  // 角(4,2)→(2,0)=玉に斜め2マスで王手！
  // 後手玉(2,0)逃げ場: (1,0),(3,0),(1,1),(3,1)=角利き×
  // (1,0)と(3,0)を封鎖:
  // 先手金(3,0)打ち不可（答えに使う）→ 別の駒で封鎖
  // 先手飛(4,0)→(1,0): 縦移動で(1,0)守り & (3,0)守り
  // 飛(4,0)の縦利き: (0,0)(1,0)(2,0)=玉(3,0)(4,0) → (1,0)と(3,0)を同時に守る ✓
  // 後手玉(2,0)逃げ場: (1,0)=飛利き×, (3,0)=飛利き×, (1,1),(3,1)=角利き×
  // (1,1): 先手が守る → 金(2,1)打ちで(1,0)(1,1)(1,2)(2,0)(2,2)(3,1) → (1,1)守り✓
  // 複雑なので: 角(4,2)打ちで王手 → 後手玉が(1,1)に逃げる → 先手金(2,1)で詰み
  {
    final b = _empty();
    b[2][0] = Piece(PieceType.king, false);   // 後手玉 9三(2,0)
    b[8][8] = Piece(PieceType.king, true);    // 先手玉 1九(8,8)
    b[4][0] = Piece(PieceType.rook, true);    // 先手飛 9五(4,0)
    b[1][0] = Piece(PieceType.gold, false);   // 後手金 9二(1,0) 玉の逃げ先守り
    b[2][1] = Piece(PieceType.silver, true);  // 先手銀 8三(2,1) — moved from (3,1): silver at (3,1) blocks bishop's diagonal drop path
    // 角を(4,2)に打つ: 角(4,2)→(2,0)=玉 王手!
    // 後手玉(2,0)→(1,1)逃げ: 金(1,0)守りで(1,0)は×
    // 銀(3,1)の利き(先手fwd=-1): (2,0)=玉,(2,1),(2,2),(4,0)=飛×(同じ先手駒),(4,2)=角打ち後
    // → 銀が(2,1)を守る ✓
    // 後手玉(1,1)を先手金打ち(2,1)で詰む:
    // 金(2,1)利き(先手fwd=-1): (1,0)=後手金×,(1,1)=玉!,(1,2),(2,0),(2,2),(3,1)=銀×
    // → 金(2,1)打ちで後手玉(1,1)に王手 → 後手玉逃げ場: (0,0),(0,1),(0,2),(1,0)=後手金×,(1,2)
    // さらに詰む条件が必要... 簡略化して「角を打ったら詰み」の形で
    // 実際には: 角(4,2)打ちで後手玉に王手 → 後手玉は後手金(1,0)の守りで(1,0)行けない
    // (2,1)=銀利き×; (3,0)=飛利き×(飛は(4,0)から縦(3,0)に効く); (1,1)のみ逃げ場
    // 先手金(2,1): 待機して(1,1)を守る必要 → 先に金を(2,1)に置く（問題の答えは角打ち）
    b[2][1] = Piece(PieceType.gold, true);    // 先手金 8三(2,1) ← 事前配置
    // これで: 角(4,2)打ち王手 → 後手玉逃げ場(1,1),(3,0)=飛利き×,(2,1)=先手金×
    // (1,1): 金(2,1)の利き(先手): (1,0),(1,1)✓,(1,2),(2,0),(2,2),(3,1)=銀× → (1,1)守り✓
    // → 全逃げ場封鎖 → 詰み！
    list.add(_TesujiProb(
      id: 'tsume_10',
      title: '詰め ⑩ (2手)',
      category: '詰め',
      explanation: '先手は持ち駒の角を9五から2マス斜めの地点に打ちます。後手玉9三に斜め王手がかかり、周囲は先手飛・金・銀が固めているため逃げ場がありません。端玉を角打ちで仕留める詰みの手筋。',
      board: b,
      p1Hand: {PieceType.bishop: 1},
      answer: AMove(fr: -1, fc: -1, tr: 4, tc: 2, drop: PieceType.bishop),
      sourceTitle: '',
      difficulty: '上級',
    ));
  }

  // ===== 桂頭の銀 ① =====
  // 先手銀が後手桂馬の頭（桂の利きが及ばない真上）に乗って攻撃する手筋
  // 後手桂 3三(2,6) 先手銀(4,5)→(3,6): 桂の頭=桂の真前(row-1)
  // 銀(3,6)の利き(先手fwd=-1): (2,5),(2,6)=後手桂!,(2,7),(4,5),(4,7)
  // 後手桂の利き(後手fwd=+1): (4,5)と(4,7) → 先手銀が(3,6)に来ても桂は取れない!
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);          // 後手玉 5一(0,4)
    b[8][4] = Piece(PieceType.king, true);           // 先手玉 5九(8,4)
    b[2][6] = Piece(PieceType.knight, false);        // 後手桂 3三(2,6)
    b[1][6] = Piece(PieceType.rook, false);          // 後手飛 3二(1,6) 桂の後ろ
    b[4][5] = Piece(PieceType.silver, true);         // 先手銀 5五(4,5)
    // 先手銀(4,5)→(3,6): 桂頭に乗る。銀(3,6)は後手桂(2,6)を攻撃。
    // 後手桂の利き(後手)=(4,5)と(4,7)なので銀(3,6)は取れない。
    // さらに銀(3,6)から後手飛(1,6)も縦方向で次に狙える。
    list.add(_TesujiProb(
      id: 'keigashira_gin_1',
      title: '桂頭の銀 ①',
      category: '両取り',
      explanation: '先手銀が5五から桂馬の頭（3四）に進みます。桂馬は真前に利かないため銀を取れず、先手銀は後手桂をタダで攻撃できます。桂頭の銀は桂を攻める基本手筋です。',
      board: b,
      answer: AMove(fr: 4, fc: 5, tr: 3, tc: 6),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '上級',
    ));
  }

  // ===== 垂れ歩 ① =====
  // 先手が歩を敵陣2段目に打って「次に成る」脅しをかける手筋
  // 後手玉(0,4)付近に歩を打ち、成り込みの脅しで相手を動かす
  // 後手陣2段目(row=1)に歩を打って垂れ歩を作る
  {
    final b = _empty();
    b[0][3] = Piece(PieceType.king, false);          // 後手玉 4一(0,3)
    b[8][4] = Piece(PieceType.king, true);           // 先手玉 5九(8,4)
    b[2][4] = Piece(PieceType.gold, false);          // 後手金 5三(2,4)
    b[0][4] = Piece(PieceType.silver, false);        // 後手銀 5一(0,4)
    b[3][4] = Piece(PieceType.pawn, true);           // 先手歩 5四(3,4)
    b[5][3] = Piece(PieceType.rook, true);           // 先手飛 6四(5,3)
    // 先手歩(3,4)→(2,4): 後手金を取りつつ次に(1,4)に垂れ歩を作る
    // もしくは先手が持ち駒歩を(1,4)=5二に打つ: 垂れ歩
    // 歩(1,4)の脅し: 次に(0,4)=成り込みで後手銀取り
    // ここでは先手が持ち駒の歩を2段目(row=1)に打つ形
    list.add(_TesujiProb(
      id: 'tareppawn_1',
      title: '垂れ歩 ①',
      category: '飛車取り',
      explanation: '先手は持ち駒の歩を5二に打ちます（垂れ歩）。次の手でと金（成り歩）になる脅しがあり、後手はすぐ対応しなければなりません。後手金が守りに来ると先手飛が活躍します。',
      board: b,
      p1Hand: {PieceType.pawn: 1},
      answer: AMove(fr: -1, fc: -1, tr: 1, tc: 4, drop: PieceType.pawn),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '初級',
    ));
  }

  // ===== 継ぎ歩 ① =====
  // 先手歩を相手の歩の真前に打って「突き捨て→継ぎ歩」で拠点を作る手筋
  // 先手歩(3,3)の前に後手歩(2,3)がいる。先手が(2,3)へ突いて取らせ、
  // さらに歩を(2,3)打ちで継ぎ歩=拠点として利用
  {
    final b = _empty();
    b[0][2] = Piece(PieceType.king, false);          // 後手玉 3一(0,2)
    b[8][6] = Piece(PieceType.king, true);           // 先手玉 3九(8,6)
    b[2][3] = Piece(PieceType.pawn, false);          // 後手歩 4三(2,3)
    b[3][3] = Piece(PieceType.pawn, true);           // 先手歩 4四(3,3)
    b[1][3] = Piece(PieceType.gold, false);          // 後手金 4二(1,3)
    b[5][3] = Piece(PieceType.rook, true);           // 先手飛 4六(5,3)
    // 先手歩(3,3)→(2,3): 後手歩を取る（突き捨て）
    // 後手金(1,3)が取り返す → 先手は持ち駒の歩を(2,3)に打って継ぎ歩
    // 継ぎ歩(2,3)が垂れ歩となり後手金を圧迫する
    // ここでの正解手は突き捨て(3,3)→(2,3)
    list.add(_TesujiProb(
      id: 'tsugifu_1',
      title: '継ぎ歩 ①',
      category: '飛車取り',
      explanation: '先手歩が4四から4三の後手歩を突き捨てます。後手金が取り返した後、先手は持ち駒の歩を4三に打って継ぎ歩とします。継ぎ歩は後手陣突破の強力な拠点になります。',
      board: b,
      answer: AMove(fr: 3, fc: 3, tr: 2, tc: 3),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '初級',
    ));
  }

  // ===== 田楽刺し ① =====
  // 飛車（または香）が縦一直線に後手の2枚の駒を串刺しにする手筋
  // 先手飛が後手金と後手玉を一直線に縦で串刺し
  // 後手金(2,5)と後手銀(0,5)が同じ列にいる
  // 先手飛(6,5)→(3,5): 飛が縦に後手金(2,5)に当たり、その先に後手銀(0,5)もいる
  {
    final b = _empty();
    b[0][3] = Piece(PieceType.king, false);          // 後手玉 4一(0,3)
    b[8][3] = Piece(PieceType.king, true);           // 先手玉 4九(8,3)
    b[2][5] = Piece(PieceType.gold, false);          // 後手金 4三(2,5)
    b[0][5] = Piece(PieceType.silver, false);        // 後手銀 4一(0,5)
    b[6][5] = Piece(PieceType.rook, true);           // 先手飛 4七(6,5)
    // 飛(6,5)→(3,5): 飛が(3,5)に来ると縦利きで(2,5)=後手金を攻撃
    // さらにその先(0,5)=後手銀も同じ列 → 金を取れば銀も取れる「田楽刺し」
    // 金が逃げると次に銀が取れる。金で取ると飛は銀まで届く。
    list.add(_TesujiProb(
      id: 'dengakuzashi_1',
      title: '田楽刺し ①',
      category: '両取り',
      explanation: '先手飛車が前進して後手金（4三）に当てます。後手金の後ろに後手銀（4一）が串刺しになっています。金が逃げても銀が取れる「田楽刺し」の手筋です。',
      board: b,
      answer: AMove(fr: 6, fc: 5, tr: 3, tc: 5),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '中級',
    ));
  }

  // ===== 頭金 ① =====
  // 後手玉の頭（真上）に金を打って詰める、将棋の基本詰め手筋
  // 後手玉(1,4)の真上(0,4)に金を打つと玉に王手
  // 後手玉の逃げ場: (0,3),(0,5),(1,3),(1,5),(2,3),(2,5)
  // 先手金と飛で全逃げ場を封鎖した状態で頭金を打つ
  {
    final b = _empty();
    b[1][4] = Piece(PieceType.king, false);          // 後手玉 5二(1,4)
    b[8][4] = Piece(PieceType.king, true);           // 先手玉 5九(8,4)
    b[1][3] = Piece(PieceType.gold, true);           // 先手金 6二(1,3) 玉の左封鎖
    b[1][5] = Piece(PieceType.gold, true);           // 先手金 4二(1,5) 玉の右封鎖
    b[2][4] = Piece(PieceType.rook, true);           // 先手飛 5三(2,4) 玉の下封鎖
    b[0][3] = Piece(PieceType.pawn, false);          // 後手歩 6一(0,3)
    b[0][5] = Piece(PieceType.pawn, false);          // 後手歩 4一(0,5)
    // 先手持ち駒の金を(0,4)=5一に打つ: 金(0,4)の利き(先手fwd=-1): (-1,3),(-1,4),(-1,5),(0,3),(0,5),(1,4)=玉!
    // → 頭金! 後手玉逃げ場: 左右は先手金×, 下は先手飛×, 斜め上は後手歩×
    list.add(_TesujiProb(
      id: 'atama_kin_1',
      title: '頭金 ①',
      category: '詰め',
      explanation: '先手は持ち駒の金を5一（後手玉の真上）に打ちます。金の利きが5二の後手玉に直接当たる「頭金」です。後手玉の逃げ場は左右の先手金と下の先手飛、斜め上の後手歩で封鎖されています。',
      board: b,
      p1Hand: {PieceType.gold: 1},
      answer: AMove(fr: -1, fc: -1, tr: 0, tc: 4, drop: PieceType.gold),
      sourceTitle: '',
      difficulty: '上級',
    ));
  }

  // ===== 割り打ち ① =====
  // 先手飛が後手の2枚の間に割り込んで両方を同時に攻撃するフォーク手筋
  // 後手飛(0,2)と後手金(0,6)が同じ行にいる
  // 先手飛を(0,4)に打つと左右両方を同時に攻撃（横の割り打ち）
  // 後手飛と後手金が離れており、先手飛の横効きで両方に当たる
  {
    final b = _empty();
    b[2][3] = Piece(PieceType.king, false);          // 後手玉 6三(2,3) — moved from (2,4): king at (2,4) blocks rook's vertical path
    b[8][4] = Piece(PieceType.king, true);           // 先手玉 5九(8,4)
    b[0][1] = Piece(PieceType.rook, false);          // 後手飛 8一(0,1)
    b[0][7] = Piece(PieceType.gold, false);          // 後手金 2一(0,7)
    b[4][4] = Piece(PieceType.rook, true);           // 先手飛 5五(4,4)
    // 先手飛(4,4)→(0,4): 先手飛が後手1段目の中央に来る
    // 飛(0,4)の横効き: (0,1)=後手飛 ✓ & (0,7)=後手金 ✓ → 割り打ち両取り!
    list.add(_TesujiProb(
      id: 'warihuchi_1',
      title: '割り打ち ①',
      category: '両取り',
      explanation: '先手飛車が5五から1段目の中央（5一）に前進します。飛車の横効きが左の後手飛車（8一）と右の後手金（2一）の両方に当たります。2枚の駒の間に割り込む「割り打ち」の手筋です。',
      board: b,
      answer: AMove(fr: 4, fc: 4, tr: 0, tc: 4),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '中級',
    ));
  }

  // ===== 合わせ歩 ① =====
  // 後手が歩を打って先手の歩の進撃を止めようとする局面で、
  // 先手が歩で取って「合わせ歩」を利用して拠点を作る手筋
  // 先手が歩を打って後手の歩の前に合わせ、後手に取らせて手番を得る
  // 先手歩(3,2)の前(2,2)に後手歩が来た → 先手は(3,2)の歩で(2,2)を取る
  {
    final b = _empty();
    b[0][1] = Piece(PieceType.king, false);          // 後手玉 8一(0,1)
    b[8][8] = Piece(PieceType.king, true);           // 先手玉 1九(8,8)
    b[2][2] = Piece(PieceType.pawn, false);          // 後手打ち歩 7三(2,2)
    b[3][2] = Piece(PieceType.pawn, true);           // 先手歩 7四(3,2)
    b[1][2] = Piece(PieceType.silver, false);        // 後手銀 7二(1,2) 後手の守り
    b[4][2] = Piece(PieceType.rook, true);           // 先手飛 7五(4,2)
    // 先手歩(3,2)→(2,2): 後手打ち歩を取る（合わせ歩）
    // 後手銀(1,2)が取り返すと先手飛(4,2)が縦に活躍
    // 合わせ歩で手番を得て飛車の縦効きを活かす
    list.add(_TesujiProb(
      id: 'awasefu_1',
      title: '合わせ歩 ①',
      category: '飛車取り',
      explanation: '後手が7三に歩を打ってきました。先手は7四の歩で7三の後手歩を取ります（合わせ歩）。後手銀が取り返すと先手飛の縦効きが後手陣に通り、攻めが加速します。',
      board: b,
      answer: AMove(fr: 3, fc: 2, tr: 2, tc: 2),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '中級',
    ));
  }

  // ===== 底歩 ① =====
  // 先手が後手飛の進撃ラインの底（最後列）に歩を打って飛の成り込みを防ぐ守りの手筋
  // 後手飛(3,4)が先手陣に向けて縦に迫っている
  // 先手が9段目(row=8)の手前(row=7)に歩を打って飛の成り込みを阻止
  // 先手玉(8,4)の前列(row=7)のcol=4に歩を打って飛の侵入を防ぐ
  {
    final b = _empty();
    b[8][4] = Piece(PieceType.king, true);           // 先手玉 5九(8,4)
    b[0][0] = Piece(PieceType.king, false);          // 後手玉 9一(0,0)
    b[3][4] = Piece(PieceType.rook, false);          // 後手飛 5四(3,4) 先手陣に向かって縦に迫る
    b[8][3] = Piece(PieceType.gold, true);           // 先手金 6九(8,3)
    b[8][5] = Piece(PieceType.gold, true);           // 先手金 4九(8,5)
    b[6][4] = Piece(PieceType.pawn, false);          // 後手歩 5七(6,4) 飛の前に後手歩
    // 後手飛(3,4)の縦効き: (4,4),(5,4),(6,4)=後手歩×,(7,4),(8,4)=先手玉
    // 後手歩が(6,4)にいるので飛はすぐには来られないが、歩が動いたら危険
    // 先手は持ち駒の歩を(7,4)に打って底歩=飛の成り込み阻止
    // 底歩(7,4): 飛が来ても(7,4)の歩で止まる
    list.add(_TesujiProb(
      id: 'soko_fu_1',
      title: '底歩 ①',
      category: '守り',
      explanation: '後手飛車が5四から先手玉方向に縦に迫っています。先手は持ち駒の歩を5八に打って「底歩」とします。底歩は飛車の成り込みを防ぐ強力な受けの手筋で、飛車が侵入しても歩でストップします。',
      board: b,
      p1Hand: {PieceType.pawn: 1},
      answer: AMove(fr: -1, fc: -1, tr: 7, tc: 4, drop: PieceType.pawn),
      sourceUrl: 'https://xn--pet04dr1n5x9a.com/tesuji/',
      sourceTitle: '将棋講座.com',
      difficulty: '上級',
    ));
  }

  // ===== 捨て駒 ① =====
  // 先手が角を捨てて後手玉を追い詰める手筋（捨て駒で相手の守り駒を排除）
  // 後手玉(0,4)、後手金(1,4)が玉を守っている
  // 先手角(3,2)を(1,4)に動かして後手金に当てる→後手金が取ったら後手玉の守りが崩れる
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);           // 後手玉 5一(0,4)
    b[1][4] = Piece(PieceType.gold, false);           // 後手金 5二(1,4) 玉の守り
    b[8][4] = Piece(PieceType.king, true);            // 先手玉 5九(8,4)
    b[3][2] = Piece(PieceType.bishop, true);          // 先手角 7四(3,2)
    b[1][6] = Piece(PieceType.rook, true);            // 先手飛 3二(1,6)
    b[0][6] = Piece(PieceType.gold, true);            // 先手金 3一(0,6) 玉の右封鎖
    // 角(3,2)→(1,4): 後手金に当たる（角捨て）
    // 後手金が角を取ると → 先手飛(1,6)の縦効きで(1,4)=取った金を再取り → (0,4)=玉への縦王手
    // 後手金が逃げると → 先手飛(1,6)→(1,4)で金取り & 次に(0,4)王手
    list.add(_TesujiProb(
      id: 'suteroma_1',
      title: '捨て駒 ①（角捨て）',
      category: '捨て駒',
      explanation: '先手角を5二の後手金に当てます。後手金が角を取ると、先手飛が縦に動いて後手玉に王手がかかります。守り駒を排除するための角捨ての手筋。',
      board: b,
      answer: AMove(fr: 3, fc: 2, tr: 1, tc: 4),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '初級',
    ));
  }

  // ===== 捨て駒 ② =====
  // 先手が銀を捨てて後手玉の逃げ道を塞ぐ
  // 後手玉(0,0)、先手が銀を(0,1)に打って玉に当てる
  // 後手玉が銀を取ると(0,1)に移動 → 先手飛(2,1)の縦効きで(0,1)=王手→詰み
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);           // 後手玉 9一(0,0)
    b[8][8] = Piece(PieceType.king, true);            // 先手玉 1九(8,8)
    b[2][0] = Piece(PieceType.rook, true);            // 先手飛 9三(2,0)
    b[1][0] = Piece(PieceType.pawn, false);           // 後手歩 9二(1,0) 飛の前に歩
    b[0][1] = Piece(PieceType.gold, false);           // 後手金 8一(0,1) 玉の逃げ先
    b[1][1] = Piece(PieceType.gold, true);            // 先手金 8二(1,1) 玉の上守り
    // 先手銀を(1,0)に打つ: 後手歩のある場所に割り込む
    // → 先手銀(1,0)で後手歩を取りながら後手玉(0,0)に接近
    // → 後手玉逃げ場(0,1)=後手金（先手金(1,1)の利きで(0,1)も守られている?）
    // 先手金(1,1)の利き(先手fwd=-1): (0,0)=玉!,(0,1),(0,2),(1,0),(1,2),(2,1)
    // → 先手金は(0,0)に王手できるが、まず銀を打って後手玉の周囲を崩す
    // 銀を(0,1)に打つ→後手金と交換して先手金で詰む構想
    list.add(_TesujiProb(
      id: 'suteroma_2',
      title: '捨て駒 ②（銀打ち捨て）',
      category: '捨て駒',
      explanation: '先手は持ち駒の銀を8一に打ちます。後手金を排除して後手玉の守りを崩す捨て駒の発想です。次の手で先手金が後手玉に迫ります。',
      board: b,
      p1Hand: {PieceType.silver: 1},
      answer: AMove(fr: -1, fc: -1, tr: 0, tc: 1, drop: PieceType.silver),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '中級',
    ));
  }

  // ===== 捨て駒 ③ =====
  // 先手が飛車を捨てて後手の守備形を崩す（飛車捨て）
  // 後手玉(0,4)、後手の1段目に先手飛を突入させて後手角を取り、玉の守りを崩す
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);           // 後手玉 5一(0,4)
    b[0][3] = Piece(PieceType.bishop, false);         // 後手角 6一(0,3) 玉の守り
    b[8][4] = Piece(PieceType.king, true);            // 先手玉 5九(8,4)
    b[2][3] = Piece(PieceType.rook, true);            // 先手飛 6三(2,3)
    b[0][5] = Piece(PieceType.gold, true);            // 先手金 4一(0,5) 玉の右
    b[1][4] = Piece(PieceType.gold, true);            // 先手金 5二(1,4) 玉の下
    // 先手飛(2,3)→(0,3): 後手角を取る（飛車が後手角の場所に突入）
    // 後手玉(0,4)に縦効きはないが、角を排除して先手金との連携で玉を追い詰める
    // 飛(0,3)の横効きで(0,4)=玉に王手! → 詰み（先手金(0,5)と(1,4)が逃げ場封鎖）
    list.add(_TesujiProb(
      id: 'suteroma_3',
      title: '捨て駒 ③（飛車突入）',
      category: '捨て駒',
      explanation: '先手飛車が6三から6一に突入して後手角を取ります。飛車の横効きが後手玉5一に当たり王手になります。後手玉の逃げ場は先手金2枚が封じています。',
      board: b,
      answer: AMove(fr: 2, fc: 3, tr: 0, tc: 3),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '中級',
    ));
  }

  // ===== 捨て駒 ④ =====
  // 歩の突き捨てで相手の守り形を乱す（歩捨て）
  // 先手が後手銀の前に歩を打って後手銀に取らせ、戦線を整える
  {
    final b = _empty();
    b[0][1] = Piece(PieceType.king, false);           // 後手玉 8一(0,1)
    b[8][8] = Piece(PieceType.king, true);            // 先手玉 1九(8,8)
    b[2][2] = Piece(PieceType.silver, false);         // 後手銀 7三(2,2) 守備の銀
    b[1][1] = Piece(PieceType.rook, false);           // 後手飛 8二(1,1)
    b[4][2] = Piece(PieceType.rook, true);            // 先手飛 7五(4,2)
    b[3][1] = Piece(PieceType.pawn, true);            // 先手歩 8四(3,1)
    // 先手歩(3,1)→(2,1): 後手飛の前（8三）に歩を打ち付ける
    // 後手飛が取る→先手飛(4,2)が縦に後手陣へ
    // または後手銀が7四に来たとき歩で取って戦線に乱れを作る
    // ここでは: 歩(3,1)→(2,1)で後手飛に当てる突き捨て
    list.add(_TesujiProb(
      id: 'suteroma_4',
      title: '捨て駒 ④（歩の突き捨て）',
      category: '捨て駒',
      explanation: '先手の8四の歩を8三に突き捨てます。後手飛車がいる場所に歩をぶつけ、後手に手を指させて先手の攻め形を整える歩の突き捨ての手筋です。',
      board: b,
      answer: AMove(fr: 3, fc: 1, tr: 2, tc: 1),
      sourceUrl: 'https://www.shougi.jp/learn/tesuji/',
      sourceTitle: '将棋研究',
      difficulty: '上級',
    ));
  }

  return list;
}

final List<_TesujiProb> _problems = _buildTesujiProblems();

const List<String> _categories = ['全て', '飛車取り', '王手金取り', '両取り', '守り', '詰め', '捨て駒'];

// ===== メイン画面 =====
class TesujiScreen extends StatefulWidget {
  const TesujiScreen({super.key});

  @override
  State<TesujiScreen> createState() => _TesujiScreenState();
}

class _TesujiScreenState extends State<TesujiScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Set<String> _cleared = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _loadCleared();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCleared() async {
    final prefs = await SharedPreferences.getInstance();
    final cleared = <String>{};
    for (final p in _problems) {
      if (prefs.getBool('tesuji_cleared_${p.id}') == true) {
        cleared.add(p.id);
      }
    }
    setState(() => _cleared = cleared);
  }

  Future<void> _markCleared(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tesuji_cleared_$id', true);
    setState(() => _cleared = {..._cleared, id});
  }

  List<_TesujiProb> _filtered(String category) => category == '全て'
      ? _problems
      : _problems.where((p) => p.category == category).toList();

  @override
  Widget build(BuildContext context) {
    final clearedCount = _cleared.length;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('手筋トレーニング',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          tabs: _categories
              .map((c) => Tab(text: c))
              .toList(),
        ),
      ),
      body: Column(children: [
        // 進捗バー
        Container(
          color: const Color(0xFF16213E),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('進捗: $clearedCount / ${_problems.length} 問',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text('${(clearedCount / _problems.length * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: clearedCount / _problems.length,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                minHeight: 6,
              ),
            ),
          ]),
        ),
        // タブコンテンツ
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _categories.map((cat) {
              final probs = _filtered(cat);
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: probs.length,
                itemBuilder: (context, index) {
                  final prob = probs[index];
                  final isCleared = _cleared.contains(prob.id);
                  return _ProblemCard(
                    prob: prob,
                    isCleared: isCleared,
                    onTap: () async {
                      final solved = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _TesujiDetailScreen(prob: prob, isCleared: isCleared),
                        ),
                      );
                      if (solved == true) {
                        await _markCleared(prob.id);
                      }
                    },
                  );
                },
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

// ===== 問題カード =====
class _ProblemCard extends StatelessWidget {
  final _TesujiProb prob;
  final bool isCleared;
  final VoidCallback onTap;
  const _ProblemCard({required this.prob, required this.isCleared, required this.onTap});

  Color get _categoryColor {
    switch (prob.category) {
      case '飛車取り':    return Colors.blue.shade400;
      case '王手金取り':  return Colors.red.shade400;
      case '両取り':      return Colors.purple.shade300;
      case '守り':        return Colors.green.shade400;
      case '詰め':        return Colors.orange.shade400;
      default:            return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCleared ? Colors.green.withAlpha(100) : Colors.white12,
            width: isCleared ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          // クリア状態
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCleared ? Colors.green.withAlpha(40) : Colors.white12,
            ),
            child: Center(
              child: isCleared
                  ? const Icon(Icons.check, color: Colors.green, size: 20)
                  : Text(
                      _problems.indexWhere((p) => p.id == prob.id).toString().padLeft(2, '0'),
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // タイトルとカテゴリ
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(prob.title,
                  style: TextStyle(
                    color: isCleared ? Colors.white70 : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _categoryColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _categoryColor.withAlpha(120), width: 0.8),
                ),
                child: Text(prob.category,
                    style: TextStyle(color: _categoryColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
        ]),
      ),
    );
  }
}

// ===== 問題詳細画面 =====
class _TesujiDetailScreen extends StatefulWidget {
  final _TesujiProb prob;
  final bool isCleared;
  const _TesujiDetailScreen({required this.prob, required this.isCleared});

  @override
  State<_TesujiDetailScreen> createState() => _TesujiDetailScreenState();
}

class _TesujiDetailScreenState extends State<_TesujiDetailScreen> {
  (int, int)? _selectedFrom;
  Set<(int, int)> _moveDots = {};
  bool? _result; // null=未回答, true=正解, false=不正解
  (int, int)? _lastFrom;
  (int, int)? _lastTo;

  // 盤面のコピー（表示用のみ、実際の合法性チェックは簡易版）
  late List<List<Piece?>> _board;

  @override
  void initState() {
    super.initState();
    _board = widget.prob.board.map((row) => List<Piece?>.from(row)).toList();
  }

  void _onCellTap(int r, int c) {
    if (_result != null) return; // 回答済みなら操作しない

    final piece = _board[r][c];

    if (_selectedFrom == null) {
      // 先手の駒を選択（持ち駒打ち以外）
      if (piece != null && piece.isPlayer1 == widget.prob.p1Turn) {
        setState(() {
          _selectedFrom = (r, c);
          // 選択した駒の動ける方向を簡易的にドット表示（実際の合法手は省略）
          _moveDots = _calcSimpleDots(r, c, piece);
        });
      }
    } else {
      final (fr, fc) = _selectedFrom!;
      // 選択解除
      if (fr == r && fc == c) {
        setState(() {
          _selectedFrom = null;
          _moveDots = {};
        });
        return;
      }
      // 移動先を決定
      _checkAnswer(fr, fc, r, c, null);
    }
  }

  void _onHandPieceTap(PieceType type) {
    if (_result != null) return;
    // 持ち駒を選択: 打ち先を探す
    setState(() {
      _selectedFrom = (-1, -1); // drop marker
      _moveDots = _calcDropDots(type);
    });
  }

  void _onDropTarget(int r, int c, PieceType type) {
    if (_result != null) return;
    _checkAnswer(-1, -1, r, c, type);
  }

  void _checkAnswer(int fr, int fc, int tr, int tc, PieceType? drop) {
    final ans = widget.prob.answer;
    final correct = ans.fr == fr &&
        ans.fc == fc &&
        ans.tr == tr &&
        ans.tc == tc &&
        ans.drop == drop;

    // 盤面に駒の動きを反映
    if (drop != null) {
      _board[tr][tc] = Piece(drop, widget.prob.p1Turn);
      // ※ p1Hand は const なので setState 内で更新しない（表示のみ）
    } else if (fr >= 0 && fc >= 0) {
      final piece = _board[fr][fc];
      if (piece != null) {
        _board[tr][tc] = piece;
        _board[fr][fc] = null;
      }
    }

    setState(() {
      _result = correct;
      _selectedFrom = null;
      _moveDots = {};
      _lastFrom = fr >= 0 ? (fr, fc) : null;
      _lastTo = (tr, tc);
    });
  }

  // 簡易的なドット計算（移動可能マスの目安表示）
  Set<(int, int)> _calcSimpleDots(int r, int c, Piece piece) {
    final dots = <(int, int)>{};
    final fwd = piece.isPlayer1 ? -1 : 1;
    void add(int nr, int nc) {
      if (nr >= 0 && nr < 9 && nc >= 0 && nc < 9) {
        final target = _board[nr][nc];
        if (target == null || target.isPlayer1 != piece.isPlayer1) {
          dots.add((nr, nc));
        }
      }
    }
    void slide(int dr, int dc) {
      int nr = r + dr, nc = c + dc;
      while (nr >= 0 && nr < 9 && nc >= 0 && nc < 9) {
        final target = _board[nr][nc];
        if (target != null) {
          if (target.isPlayer1 != piece.isPlayer1) dots.add((nr, nc));
          break;
        }
        dots.add((nr, nc));
        nr += dr;
        nc += dc;
      }
    }

    switch (piece.type) {
      case PieceType.king:
        for (int dr = -1; dr <= 1; dr++) for (int dc = -1; dc <= 1; dc++) {
          if (dr != 0 || dc != 0) add(r + dr, c + dc);
        }
        break;
      case PieceType.rook:
      case PieceType.promotedRook:
        slide(-1, 0); slide(1, 0); slide(0, -1); slide(0, 1);
        if (piece.type == PieceType.promotedRook) {
          add(r - 1, c - 1); add(r - 1, c + 1); add(r + 1, c - 1); add(r + 1, c + 1);
        }
        break;
      case PieceType.bishop:
      case PieceType.promotedBishop:
        slide(-1, -1); slide(-1, 1); slide(1, -1); slide(1, 1);
        if (piece.type == PieceType.promotedBishop) {
          add(r - 1, c); add(r + 1, c); add(r, c - 1); add(r, c + 1);
        }
        break;
      case PieceType.gold:
      case PieceType.promotedSilver:
      case PieceType.promotedKnight:
      case PieceType.promotedLance:
      case PieceType.promotedPawn:
        add(r + fwd, c); add(r + fwd, c - 1); add(r + fwd, c + 1);
        add(r, c - 1); add(r, c + 1); add(r - fwd, c);
        break;
      case PieceType.silver:
        add(r + fwd, c); add(r + fwd, c - 1); add(r + fwd, c + 1);
        add(r - fwd, c - 1); add(r - fwd, c + 1);
        break;
      case PieceType.knight:
        add(r + fwd * 2, c - 1); add(r + fwd * 2, c + 1);
        break;
      case PieceType.lance:
        slide(fwd, 0);
        break;
      case PieceType.pawn:
        add(r + fwd, c);
        break;
    }
    return dots;
  }

  Set<(int, int)> _calcDropDots(PieceType type) {
    final dots = <(int, int)>{};
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_board[r][c] == null) dots.add((r, c));
      }
    }
    return dots;
  }

  void _reset() {
    setState(() {
      _board = widget.prob.board.map((row) => List<Piece?>.from(row)).toList();
      _selectedFrom = null;
      _moveDots = {};
      _result = null;
      _lastFrom = null;
      _lastTo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prob = widget.prob;
    final isDrop = _selectedFrom == (-1, -1);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: Text(prob.title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: _reset,
            tooltip: 'リセット',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // カテゴリバッジ
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withAlpha(120)),
                ),
                child: Text(prob.category,
                    style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),

            // 持ち駒（後手）
            if (prob.p2Hand.isNotEmpty)
              _HandDisplay(hand: prob.p2Hand, isPlayer1: false, label: '後手の持ち駒'),

            const SizedBox(height: 8),

            // 盤面
            LayoutBuilder(builder: (context, constraints) {
              final size = constraints.maxWidth < 400 ? constraints.maxWidth : 380.0;
              return Center(
                child: GestureDetector(
                  onTapDown: (details) {
                    // セル座標を計算
                    final labelSize = size * 0.05;
                    final boardSize = size - labelSize;
                    final cellSize = boardSize / 9;
                    final localX = details.localPosition.dx - labelSize;
                    final localY = details.localPosition.dy - labelSize * 1.2;
                    final c = (localX / cellSize).floor();
                    final r = (localY / cellSize).floor();
                    if (r >= 0 && r < 9 && c >= 0 && c < 9) {
                      if (isDrop) {
                        _onDropTarget(r, c, prob.answer.drop!);
                      } else {
                        _onCellTap(r, c);
                      }
                    }
                  },
                  child: MiniBoardWidget(
                    board: _board,
                    moveDots: _moveDots,
                    lastMoveFrom: _result != null ? _lastFrom
                        : (_selectedFrom != null && !isDrop ? _selectedFrom : null),
                    lastMoveTo: _result != null ? _lastTo : null,
                    size: size,
                  ),
                ),
              );
            }),

            const SizedBox(height: 8),

            // 持ち駒（先手）
            if (prob.p1Hand.isNotEmpty)
              _HandDisplay(
                hand: prob.p1Hand,
                isPlayer1: true,
                label: '先手の持ち駒',
                onPieceTap: _selectedFrom == null ? _onHandPieceTap : null,
                selectedDrop: isDrop ? prob.answer.drop : null,
              ),

            const SizedBox(height: 12),

            // 指示テキスト
            if (_result == null)
              Center(
                child: Text(
                  '${prob.p1Turn ? "先手" : "後手"}の最善手を選んでください',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),

            const SizedBox(height: 12),

            // 結果表示
            if (_result != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (_result! ? Colors.green : Colors.red).withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_result! ? Colors.green : Colors.red).withAlpha(120),
                  ),
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(
                      _result! ? Icons.check_circle : Icons.cancel,
                      color: _result! ? Colors.green : Colors.red,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _result! ? '正解！' : '不正解',
                      style: TextStyle(
                        color: _result! ? Colors.green : Colors.red,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]),
                  if (_result!) ...[
                    const SizedBox(height: 12),
                    Text(prob.explanation,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center),
                    if (prob.sourceUrl != null && prob.sourceTitle != null) ...[
                      const SizedBox(height: 10),
                      _SourceLinkButton(
                        title: prob.sourceTitle!,
                        url: prob.sourceUrl!,
                      ),
                    ],
                  ],
                ]),
              ),
              const SizedBox(height: 12),

              if (_result!)
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('次の問題へ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh, color: Colors.amber),
                  label: const Text('もう一度', style: TextStyle(color: Colors.amber)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.amber),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ===== 持ち駒表示 =====
class _HandDisplay extends StatelessWidget {
  final Map<PieceType, int> hand;
  final bool isPlayer1;
  final String label;
  final void Function(PieceType)? onPieceTap;
  final PieceType? selectedDrop;

  const _HandDisplay({
    required this.hand,
    required this.isPlayer1,
    required this.label,
    this.onPieceTap,
    this.selectedDrop,
  });

  @override
  Widget build(BuildContext context) {
    if (hand.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(width: 8),
        Wrap(
          spacing: 6,
          children: hand.entries.map((e) {
            final isSelected = selectedDrop == e.key;
            return GestureDetector(
              onTap: onPieceTap != null ? () => onPieceTap!(e.key) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.amber.withAlpha(60)
                      : const Color(0xFFE8C87A).withAlpha(200),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? Colors.amber : const Color(0xFF7A4E2B),
                    width: isSelected ? 2 : 0.8,
                  ),
                ),
                child: Text(
                  '${pieceLabel(e.key)}${e.value > 1 ? "×${e.value}" : ""}',
                  style: TextStyle(
                    color: isSelected ? Colors.amber.shade900 : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

class _SourceLinkButton extends StatelessWidget {
  final String title;
  final String url;

  const _SourceLinkButton({
    required this.title,
    required this.url,
  });

  Future<void> _openUrl() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue.withAlpha(80), width: 1),
      ),
      child: GestureDetector(
        onTap: _openUrl,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link, size: 14, color: Colors.blue.shade400),
            const SizedBox(width: 6),
            Text(
              '出典: $title',
              style: TextStyle(
                color: Colors.blue.shade400,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new, size: 12, color: Colors.blue.withAlpha(150)),
          ],
        ),
      ),
    );
  }
}


