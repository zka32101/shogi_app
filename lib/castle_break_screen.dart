// lib/castle_break_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'piece.dart';
import 'mini_board_widget.dart';

// ──────────────────────────────────────────────
// Data model
// ──────────────────────────────────────────────
class _CBProb {
  final String id;
  final String title;
  final String castle; // '美濃', '矢倉', '穴熊', '居飛車穴熊'
  final String description;
  final List<List<Piece?>> board;
  final Map<PieceType, int> p1Hand; // 先手の持ち駒
  final AMove answer; // correct answer move
  final String explanation;
  const _CBProb({
    required this.id,
    required this.title,
    required this.castle,
    required this.description,
    required this.board,
    required this.p1Hand,
    required this.answer,
    required this.explanation,
  });
}

// ──────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────
List<List<Piece?>> _empty() =>
    List.generate(9, (_) => List<Piece?>.filled(9, null));

// ──────────────────────────────────────────────
// Problem definitions
// ──────────────────────────────────────────────
List<_CBProb> _buildProblems() {
  // Board coordinates: row 0=top(後手 side), row 8=bottom(先手 side)
  // col 0=9筋, col 8=1筋
  // isPlayer1=true means 先手 (attacks from bottom going up, decreasing row)
  // isPlayer1=false means 後手

  // ========== 美濃囲い ==========

  // 美濃1: 端攻め。先手が香車を使って端から崩す
  final mino1 = _empty();
  // 後手 美濃囲い (右上 = 9筋側)
  mino1[0][0] = Piece(PieceType.king, false);   // 後手玉 9一
  mino1[0][1] = Piece(PieceType.gold, false);   // 後手金 8一
  mino1[1][0] = Piece(PieceType.silver, false); // 後手銀 9二
  mino1[1][1] = Piece(PieceType.gold, false);   // 後手金 8二
  mino1[2][0] = Piece(PieceType.pawn, false);   // 後手歩 9三
  mino1[2][1] = Piece(PieceType.pawn, false);   // 後手歩 8三
  mino1[2][2] = Piece(PieceType.pawn, false);   // 後手歩 7三
  // 先手攻め駒
  mino1[3][0] = Piece(PieceType.lance, true);   // 先手香 9六
  mino1[5][4] = Piece(PieceType.rook, true);    // 先手飛 5四
  mino1[8][8] = Piece(PieceType.king, true);    // 先手玉 1九

  // 美濃2: 桂馬跳ねから攻める
  final mino2 = _empty();
  mino2[0][0] = Piece(PieceType.king, false);
  mino2[0][1] = Piece(PieceType.gold, false);
  mino2[1][0] = Piece(PieceType.silver, false);
  mino2[1][1] = Piece(PieceType.gold, false);
  mino2[2][0] = Piece(PieceType.pawn, false);
  mino2[2][1] = Piece(PieceType.pawn, false);
  mino2[2][2] = Piece(PieceType.pawn, false);
  // 先手
  // 桂は2段前+左右1移動。isPlayer1=true なので (fr,fc)→(fr-2,fc±1)
  // (5,3)→(3,2) or (3,4) どちらも合法。答えは (5,3)→(3,4)=6四桂を4四へ
  mino2[5][3] = Piece(PieceType.knight, true);  // 先手桂 6四
  mino2[5][4] = Piece(PieceType.rook, true);    // 先手飛 5四
  mino2[8][8] = Piece(PieceType.king, true);

  // 美濃3: 銀を活用して崩す
  final mino3 = _empty();
  mino3[0][0] = Piece(PieceType.king, false);
  mino3[0][1] = Piece(PieceType.gold, false);
  mino3[1][0] = Piece(PieceType.silver, false);
  mino3[1][1] = Piece(PieceType.gold, false);
  mino3[2][1] = Piece(PieceType.pawn, false);
  mino3[2][2] = Piece(PieceType.pawn, false);
  // 先手の銀が8四(row=3,col=1)に迫る
  mino3[3][1] = Piece(PieceType.silver, true);  // 先手銀 8四
  mino3[4][4] = Piece(PieceType.rook, true);    // 先手飛 5五
  mino3[8][8] = Piece(PieceType.king, true);

  // ========== 矢倉 ==========

  // 矢倉1: 4五歩突破
  final yagura1 = _empty();
  // 後手矢倉 (中央上)
  yagura1[0][4] = Piece(PieceType.king, false);  // 後手玉 5一
  yagura1[0][3] = Piece(PieceType.gold, false);  // 後手金 6一
  yagura1[0][5] = Piece(PieceType.gold, false);  // 後手金 4一
  yagura1[1][3] = Piece(PieceType.silver, false);// 後手銀 6二
  yagura1[1][5] = Piece(PieceType.silver, false);// 後手銀 4二
  yagura1[2][3] = Piece(PieceType.pawn, false);  // 後手歩 6三
  yagura1[2][4] = Piece(PieceType.pawn, false);  // 後手歩 5三
  yagura1[2][5] = Piece(PieceType.pawn, false);  // 後手歩 4三
  // 先手
  yagura1[4][5] = Piece(PieceType.pawn, true);   // 先手歩 4五
  yagura1[5][4] = Piece(PieceType.rook, true);   // 先手飛 5四
  yagura1[5][3] = Piece(PieceType.bishop, true); // 先手角 6四
  yagura1[8][4] = Piece(PieceType.king, true);

  // 矢倉2: 3五歩からの攻め
  final yagura2 = _empty();
  yagura2[0][4] = Piece(PieceType.king, false);
  yagura2[0][3] = Piece(PieceType.gold, false);
  yagura2[0][5] = Piece(PieceType.gold, false);
  yagura2[1][3] = Piece(PieceType.silver, false);
  yagura2[1][5] = Piece(PieceType.silver, false);
  yagura2[2][3] = Piece(PieceType.pawn, false);
  yagura2[2][4] = Piece(PieceType.pawn, false);
  yagura2[2][6] = Piece(PieceType.pawn, false);
  // 先手
  yagura2[4][6] = Piece(PieceType.pawn, true);   // 先手歩 3五
  yagura2[5][6] = Piece(PieceType.silver, true); // 先手銀 3四
  yagura2[5][4] = Piece(PieceType.rook, true);   // 先手飛 5四
  yagura2[8][4] = Piece(PieceType.king, true);

  // 矢倉3: 角を活かした攻め
  final yagura3 = _empty();
  yagura3[0][4] = Piece(PieceType.king, false);
  yagura3[0][3] = Piece(PieceType.gold, false);
  yagura3[0][5] = Piece(PieceType.gold, false);
  yagura3[1][3] = Piece(PieceType.silver, false);
  yagura3[1][5] = Piece(PieceType.silver, false);
  yagura3[2][3] = Piece(PieceType.pawn, false);
  yagura3[2][4] = Piece(PieceType.pawn, false);
  yagura3[2][5] = Piece(PieceType.pawn, false);
  // 先手
  yagura3[4][3] = Piece(PieceType.bishop, true); // 先手角 6五
  yagura3[5][4] = Piece(PieceType.rook, true);
  yagura3[6][5] = Piece(PieceType.knight, true); // 先手桂 4三に跳ねる
  yagura3[8][4] = Piece(PieceType.king, true);

  // ========== 穴熊 ==========

  // 穴熊1: 桂頭攻め
  final anaguma1 = _empty();
  anaguma1[0][0] = Piece(PieceType.king, false);   // 後手玉 9一
  anaguma1[0][1] = Piece(PieceType.gold, false);   // 後手金 8一
  anaguma1[0][2] = Piece(PieceType.gold, false);   // 後手金 7一
  anaguma1[1][0] = Piece(PieceType.silver, false); // 後手銀 9二
  anaguma1[1][2] = Piece(PieceType.knight, false); // 後手桂 7二
  anaguma1[2][0] = Piece(PieceType.pawn, false);   // 後手歩 9三
  anaguma1[2][1] = Piece(PieceType.pawn, false);   // 後手歩 8三
  anaguma1[2][2] = Piece(PieceType.pawn, false);   // 後手歩 7三
  // 先手
  // 桂(4,2)→(2,1) 8三に跳ねる (isPlayer1=true: fr-2, fc±1)
  anaguma1[4][2] = Piece(PieceType.knight, true);  // 先手桂 7五
  anaguma1[5][4] = Piece(PieceType.rook, true);    // 先手飛 5四
  anaguma1[8][8] = Piece(PieceType.king, true);

  // 穴熊2: 端から銀で崩す
  final anaguma2 = _empty();
  anaguma2[0][0] = Piece(PieceType.king, false);
  anaguma2[0][1] = Piece(PieceType.gold, false);
  anaguma2[0][2] = Piece(PieceType.gold, false);
  anaguma2[1][0] = Piece(PieceType.silver, false);
  anaguma2[1][2] = Piece(PieceType.knight, false);
  anaguma2[2][0] = Piece(PieceType.pawn, false);
  anaguma2[2][1] = Piece(PieceType.pawn, false);
  anaguma2[2][2] = Piece(PieceType.pawn, false);
  // 先手
  anaguma2[3][1] = Piece(PieceType.silver, true);  // 先手銀 8四
  anaguma2[4][0] = Piece(PieceType.lance, true);   // 先手香 9五
  anaguma2[5][4] = Piece(PieceType.rook, true);
  anaguma2[8][8] = Piece(PieceType.king, true);

  // 穴熊3: 飛車を使って端を破る
  final anaguma3 = _empty();
  anaguma3[0][0] = Piece(PieceType.king, false);
  anaguma3[0][1] = Piece(PieceType.gold, false);
  anaguma3[0][2] = Piece(PieceType.gold, false);
  anaguma3[1][0] = Piece(PieceType.silver, false);
  anaguma3[2][0] = Piece(PieceType.pawn, false);
  anaguma3[2][1] = Piece(PieceType.pawn, false);
  anaguma3[2][2] = Piece(PieceType.pawn, false);
  // 先手の飛車が9筋に
  anaguma3[4][0] = Piece(PieceType.rook, true);    // 先手飛 9五
  anaguma3[5][2] = Piece(PieceType.silver, true);
  anaguma3[8][8] = Piece(PieceType.king, true);

  // ========== 居飛車穴熊 ==========

  // 居飛車穴熊1: 飛車打ち込み
  final ibisha1 = _empty();
  ibisha1[0][0] = Piece(PieceType.king, false);
  ibisha1[0][1] = Piece(PieceType.gold, false);
  ibisha1[0][2] = Piece(PieceType.gold, false);
  ibisha1[1][0] = Piece(PieceType.silver, false);
  ibisha1[1][1] = Piece(PieceType.knight, false);
  ibisha1[2][0] = Piece(PieceType.pawn, false);
  ibisha1[2][1] = Piece(PieceType.pawn, false);
  ibisha1[2][2] = Piece(PieceType.pawn, false);
  ibisha1[3][3] = Piece(PieceType.rook, false);    // 後手飛 6四
  // 先手
  ibisha1[5][4] = Piece(PieceType.rook, true);     // 先手飛 5四
  ibisha1[6][3] = Piece(PieceType.bishop, true);   // 先手角
  ibisha1[8][8] = Piece(PieceType.king, true);

  // 居飛車穴熊2: 角銀連携
  final ibisha2 = _empty();
  ibisha2[0][0] = Piece(PieceType.king, false);
  ibisha2[0][1] = Piece(PieceType.gold, false);
  ibisha2[0][2] = Piece(PieceType.gold, false);
  ibisha2[1][0] = Piece(PieceType.silver, false);
  ibisha2[1][2] = Piece(PieceType.knight, false);
  ibisha2[2][0] = Piece(PieceType.pawn, false);
  ibisha2[2][1] = Piece(PieceType.pawn, false);
  ibisha2[2][3] = Piece(PieceType.pawn, false);
  ibisha2[4][5] = Piece(PieceType.rook, false);    // 後手飛
  // 先手
  ibisha2[3][2] = Piece(PieceType.silver, true);   // 先手銀 7四
  ibisha2[4][4] = Piece(PieceType.bishop, true);   // 先手角 5五
  ibisha2[5][4] = Piece(PieceType.rook, true);
  ibisha2[8][8] = Piece(PieceType.king, true);

  // 居飛車穴熊3: 桂香でこじ開ける
  final ibisha3 = _empty();
  ibisha3[0][0] = Piece(PieceType.king, false);
  ibisha3[0][1] = Piece(PieceType.gold, false);
  ibisha3[0][2] = Piece(PieceType.gold, false);
  ibisha3[1][0] = Piece(PieceType.silver, false);
  ibisha3[1][2] = Piece(PieceType.knight, false);
  ibisha3[2][0] = Piece(PieceType.pawn, false);
  ibisha3[2][1] = Piece(PieceType.pawn, false);
  ibisha3[2][2] = Piece(PieceType.pawn, false);
  ibisha3[3][5] = Piece(PieceType.rook, false);
  // 先手
  ibisha3[4][2] = Piece(PieceType.knight, true);   // 先手桂 7五
  ibisha3[5][0] = Piece(PieceType.lance, true);    // 先手香 9四
  ibisha3[5][4] = Piece(PieceType.rook, true);
  ibisha3[8][8] = Piece(PieceType.king, true);

  return [
    // ── 美濃囲い ──
    _CBProb(
      id: 'mino_1',
      title: '美濃①：端攻め',
      castle: '美濃',
      description: '先手番。香車を活かした端攻めで美濃を崩せ！\n先手の香を前進させ、後手の9三歩を攻めよう。',
      board: mino1,
      p1Hand: const {},
      // 香(3,0)を9四(2,0)へ前進
      answer: AMove(fr: 3, fc: 0, tr: 2, tc: 0),
      explanation: '9四香と前進！後手の9三歩を攻め、美濃の端から崩すのが急所。飛車との連携で端を突破しよう。美濃囲いは端が弱点なので、香・飛の連携で端を攻めるのが定跡の攻め筋。',
    ),
    _CBProb(
      id: 'mino_2',
      title: '美濃②：桂馬跳ね',
      castle: '美濃',
      description: '先手番。桂馬を跳ねて美濃の急所を突け！\n(6四の桂を跳ねて後手の守りに迫ろう)',
      board: mino2,
      p1Hand: const {},
      // 桂(5,3)を(3,4)に跳ねる: isPlayer1=true → fr-2=3, fc+1=4
      answer: AMove(fr: 5, fc: 3, tr: 3, tc: 4),
      explanation: '桂馬を跳ねて後手の囲いに迫る！美濃の急所である8二の金を狙い、飛車との連携で攻めを組み立てよう。桂は美濃崩しの重要な駒で、跳ねた桂が金に当たると効果的。',
    ),
    _CBProb(
      id: 'mino_3',
      title: '美濃③：銀の活用',
      castle: '美濃',
      description: '先手番。銀を活かして美濃の金銀を剥がせ！\n8四の銀を前進させよう。',
      board: mino3,
      p1Hand: const {},
      // 銀(3,1)を(2,0)=9三へ前進
      answer: AMove(fr: 3, fc: 1, tr: 2, tc: 0),
      explanation: '銀を9三に進出！後手の9三歩を取って美濃の端に銀が侵入する。飛車の横利きと合わせて後手玉を追い詰めよう。銀が囲いに食い込むと守りが崩れやすくなる。',
    ),

    // ── 矢倉 ──
    _CBProb(
      id: 'yagura_1',
      title: '矢倉①：4五歩突破',
      castle: '矢倉',
      description: '先手番。4五の歩を前進させて矢倉の守りを崩せ！',
      board: yagura1,
      p1Hand: const {},
      // 歩(4,5)を(3,5)=4四へ前進
      answer: AMove(fr: 4, fc: 5, tr: 3, tc: 5),
      explanation: '4四歩と前進！矢倉の4五の歩を突いて後手の銀の動きを制限する。飛車との連携で攻めを続けよう。矢倉崩しの基本は中央からの圧力で、4五歩突破は代表的な攻め筋。',
    ),
    _CBProb(
      id: 'yagura_2',
      title: '矢倉②：3五歩突き',
      castle: '矢倉',
      description: '先手番。3五の歩を前進させて矢倉の横を攻めよ！',
      board: yagura2,
      p1Hand: const {},
      // 歩(4,6)を(3,6)=3四へ前進
      answer: AMove(fr: 4, fc: 6, tr: 3, tc: 6),
      explanation: '3四歩と前進！矢倉の横から攻めを組み立て、銀の活用と合わせて後手の守りを崩していこう。矢倉は正面だけでなく横からの攻めも有効で、3五歩突破は重要な攻め筋。',
    ),
    _CBProb(
      id: 'yagura_3',
      title: '矢倉③：角の活用',
      castle: '矢倉',
      description: '先手番。桂馬を跳ねて矢倉の急所に迫れ！\n(6三の桂を跳ねて4二に当てよう)',
      board: yagura3,
      p1Hand: const {},
      // 桂(6,5)を(4,4)に跳ねる: isPlayer1=true → fr-2=4, fc-1=4
      answer: AMove(fr: 6, fc: 5, tr: 4, tc: 4),
      explanation: '桂馬を4三方向へ跳ねて矢倉の金銀に当てる！角との連携で矢倉の守りを瓦解させよう。矢倉は縦の連携が強い囲いだが、斜めからの角と桂の連携には弱い。',
    ),

    // ── 穴熊 ──
    _CBProb(
      id: 'anaguma_1',
      title: '穴熊①：桂頭攻め',
      castle: '穴熊',
      description: '先手番。桂を跳ねて穴熊の急所・桂頭を攻めよ！\n7五の桂を跳ねよう。',
      board: anaguma1,
      p1Hand: const {},
      // 桂(4,2)を(2,1)=8三へ跳ねる: fr-2=2, fc-1=1
      answer: AMove(fr: 4, fc: 2, tr: 2, tc: 1),
      explanation: '桂馬を8三に跳ねて後手の桂頭を攻撃！穴熊の急所である桂頭への攻めは強力。飛車と連携して一気に崩そう。穴熊は強固な囲いだが、桂頭を攻めると金銀が動かざるを得ない。',
    ),
    _CBProb(
      id: 'anaguma_2',
      title: '穴熊②：端の銀攻め',
      castle: '穴熊',
      description: '先手番。銀と香の連携で穴熊の端を突破せよ！\n8四の銀を前進させよう。',
      board: anaguma2,
      p1Hand: const {},
      // 銀(3,1)を(2,0)=9三へ前進
      answer: AMove(fr: 3, fc: 1, tr: 2, tc: 0),
      explanation: '銀を9三へ！香車との連携で後手の9三歩を攻め、穴熊の端から崩すのが有効な攻め。穴熊は端の守りが薄くなりがちで、銀香連携の端攻めは穴熊崩しの基本。',
    ),
    _CBProb(
      id: 'anaguma_3',
      title: '穴熊③：飛車の端突撃',
      castle: '穴熊',
      description: '先手番。飛車を活かして穴熊の端を突破せよ！\n9五の飛車を突進させよう。',
      board: anaguma3,
      p1Hand: const {},
      // 飛車(4,0)を(2,0)=9三へ前進
      answer: AMove(fr: 4, fc: 0, tr: 2, tc: 0),
      explanation: '飛車を9三に突撃！穴熊の端歩を破り、後手玉へのコースを開く強烈な一手。飛車の突進で端の歩を取り、一気に後手玉に迫ろう。',
    ),

    // ── 居飛車穴熊 ──
    _CBProb(
      id: 'ibisha_1',
      title: '居飛車穴熊①：飛車突進',
      castle: '居飛車穴熊',
      description: '先手番。飛車で居飛車穴熊の急所を突け！\n5四の飛車を前進させよう。',
      board: ibisha1,
      p1Hand: const {},
      // 飛車(5,4)を(2,4)=5二へ前進
      answer: AMove(fr: 5, fc: 4, tr: 2, tc: 4),
      explanation: '飛車を5二に突撃！居飛車穴熊の守りを中央から崩し、角との連携で後手玉を追い詰めよう。居飛車穴熊は中央の守りを飛車で突き崩すのが効果的。',
    ),
    _CBProb(
      id: 'ibisha_2',
      title: '居飛車穴熊②：角銀連携',
      castle: '居飛車穴熊',
      description: '先手番。銀を前進させて居飛車穴熊を崩せ！\n7四の銀を8三へ進めよう。',
      board: ibisha2,
      p1Hand: const {},
      // 銀(3,2)を(2,1)=8三へ前進
      answer: AMove(fr: 3, fc: 2, tr: 2, tc: 1),
      explanation: '銀を8三に進出！角との連携で後手の守りに風穴を開ける。居飛車穴熊は角銀の連携攻めが効果的で、銀が囲いに食い込むと急速に崩れる。',
    ),
    _CBProb(
      id: 'ibisha_3',
      title: '居飛車穴熊③：桂跳ね',
      castle: '居飛車穴熊',
      description: '先手番。桂を跳ねて居飛車穴熊を攻略せよ！\n7五の桂を跳ねて8三に当てよう。',
      board: ibisha3,
      p1Hand: const {},
      // 桂(4,2)を(2,1)=8三へ跳ねる: fr-2=2, fc-1=1
      answer: AMove(fr: 4, fc: 2, tr: 2, tc: 1),
      explanation: '桂馬を8三へ！香車との連携で後手の守りを突破する。居飛車穴熊には桂頭への攻めが急所になることが多く、桂香連携で端から崩すのが定跡的な攻め筋。',
    ),
  ];
}

// ──────────────────────────────────────────────
// Main Screen
// ──────────────────────────────────────────────
class CastleBreakScreen extends StatefulWidget {
  const CastleBreakScreen({super.key});

  @override
  State<CastleBreakScreen> createState() => _CastleBreakScreenState();
}

class _CastleBreakScreenState extends State<CastleBreakScreen>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFF1A1A2E);
  static const _appBarColor = Color(0xFF16213E);

  late final List<_CBProb> _problems;
  final Set<String> _cleared = {};
  late TabController _tabController;

  final List<String> _castles = ['美濃', '矢倉', '穴熊', '居飛車穴熊'];

  @override
  void initState() {
    super.initState();
    _problems = _buildProblems();
    _tabController = TabController(length: 4, vsync: this);
    _loadProgress();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final cleared = <String>{};
    for (final p in _problems) {
      if (prefs.getBool('castle_break_${p.id}') == true) {
        cleared.add(p.id);
      }
    }
    if (mounted) setState(() => _cleared.addAll(cleared));
  }

  List<_CBProb> _probsForCastle(String castle) =>
      _problems.where((p) => p.castle == castle).toList();

  void _openSolveView(BuildContext context, _CBProb prob) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SolveScreen(
          prob: prob,
          isCleared: _cleared.contains(prob.id),
          onCleared: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('castle_break_${prob.id}', true);
            if (mounted) setState(() => _cleared.add(prob.id));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _appBarColor,
        title: const Text(
          '囲い崩し道場',
          style: TextStyle(
            color: Color(0xDEFFFFFF),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xDEFFFFFF)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          tabs: _castles.map((c) => Tab(text: c)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _castles.map((castle) {
          final probs = _probsForCastle(castle);
          return _CastleTabView(
            castle: castle,
            problems: probs,
            cleared: _cleared,
            onTapProblem: (p) => _openSolveView(context, p),
          );
        }).toList(),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Tab View (problem list for one castle type)
// ──────────────────────────────────────────────
class _CastleTabView extends StatelessWidget {
  final String castle;
  final List<_CBProb> problems;
  final Set<String> cleared;
  final void Function(_CBProb) onTapProblem;

  const _CastleTabView({
    required this.castle,
    required this.problems,
    required this.cleared,
    required this.onTapProblem,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CastleHeader(castle: castle),
        const SizedBox(height: 12),
        ...problems.map((p) => _ProblemCard(
              prob: p,
              isCleared: cleared.contains(p.id),
              onTap: () => onTapProblem(p),
            )),
      ],
    );
  }
}

class _CastleHeader extends StatelessWidget {
  final String castle;
  const _CastleHeader({required this.castle});

  String get _description {
    switch (castle) {
      case '美濃':
        return '美濃囲いは端攻めや桂馬の跳ねが有効。急所の6二金を狙え！';
      case '矢倉':
        return '矢倉は4五歩や3五歩からの攻めが基本。角銀を活かそう！';
      case '穴熊':
        return '穴熊は桂頭攻めが急所。端から崩す攻めも効果的！';
      case '居飛車穴熊':
        return '居飛車穴熊は飛車と角の連携で崩す。桂香の活用も重要！';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3460).withAlpha(180),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$castle囲い崩し',
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _description,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ProblemCard extends StatelessWidget {
  final _CBProb prob;
  final bool isCleared;
  final VoidCallback onTap;

  const _ProblemCard({
    required this.prob,
    required this.isCleared,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F3460).withAlpha(200),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCleared
                  ? Colors.green.withAlpha(180)
                  : Colors.white.withAlpha(30),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prob.title,
                      style: const TextStyle(
                        color: Color(0xDEFFFFFF),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prob.description.split('\n').first,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isCleared)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '正解済',
                    style: TextStyle(
                      color: Color(0xDEFFFFFF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Solve Screen
// ──────────────────────────────────────────────
class _SolveScreen extends StatefulWidget {
  final _CBProb prob;
  final bool isCleared;
  final Future<void> Function() onCleared;

  const _SolveScreen({
    required this.prob,
    required this.isCleared,
    required this.onCleared,
  });

  @override
  State<_SolveScreen> createState() => _SolveScreenState();
}

class _SolveScreenState extends State<_SolveScreen> {
  static const _bg = Color(0xFF1A1A2E);
  static const _appBarColor = Color(0xFF16213E);

  (int, int)? _selectedFrom;
  int _lives = 3;
  bool _showHint = false;
  bool _solved = false;
  String? _feedback;

  // 盤面管理（詰みまで進行用）
  late List<List<Piece?>> _currentBoard;
  late Map<PieceType, int> _p1Hand;
  late Map<PieceType, int> _p2Hand;
  bool _p1Turn = true; // 先手番
  int _moveCount = 0;

  @override
  void initState() {
    super.initState();
    // 初期盤面をコピー
    _currentBoard = List.generate(9, (r) => List<Piece?>.from(widget.prob.board[r]));
    _p1Hand = Map<PieceType, int>.from(widget.prob.p1Hand);
    _p2Hand = {};
  }

  (int, int)? get _hintFrom =>
      _showHint ? (widget.prob.answer.fr, widget.prob.answer.fc) : null;
  (int, int)? get _hintTo =>
      _showHint ? (widget.prob.answer.tr, widget.prob.answer.tc) : null;

  void _onCellTap(int row, int col) {
    if (_solved) return;

    final board = _currentBoard;
    final piece = board[row][col];

    // Nothing selected: try to select a 先手 piece
    if (_selectedFrom == null) {
      if (piece != null && piece.isPlayer1 == _p1Turn) {
        setState(() {
          _selectedFrom = (row, col);
          _feedback = null;
        });
      }
      return;
    }

    final (fr, fc) = _selectedFrom!;

    // Tap same cell → deselect
    if (fr == row && fc == col) {
      setState(() => _selectedFrom = null);
      return;
    }

    // Tap another 先手 piece → reselect
    if (piece != null && piece.isPlayer1) {
      setState(() {
        _selectedFrom = (row, col);
        _feedback = null;
      });
      return;
    }

    // ゲーム開始時は正解判定、ゲーム進行中は任意の合法手を受け入れる
    if (_moveCount == 0) {
      // 最初の手のみ判定
      final ans = widget.prob.answer;
      final correct =
          ans.fr == fr && ans.fc == fc && ans.tr == row && ans.tc == col;

      if (correct) {
        _handleCorrect();
      } else {
        _handleWrong();
      }
    } else {
      // ゲーム進行中：合法手なら実行
      final legalMoves = GL.legal(_currentBoard, fr, fc);
      if (legalMoves.any((m) => m.$1 == row && m.$2 == col)) {
        // 盤面を更新
        _currentBoard[row][col] = _currentBoard[fr][fc];
        _currentBoard[fr][fc] = null;
        _p1Turn = false; // 後手の番に
        _moveCount++;

        setState(() {
          _selectedFrom = null;
          _feedback = '後手の応手を待っています...';
        });

        Future.delayed(const Duration(milliseconds: 600), () {
          _playDefenderMove();
        });
      } else {
        setState(() {
          _feedback = '違う移動です。合法手を指してください。';
          _selectedFrom = null;
        });
      }
    }
  }

  void _handleCorrect() async {
    HapticFeedback.mediumImpact();

    // 正解の手を盤面に適用
    final ans = widget.prob.answer;
    _currentBoard[ans.tr][ans.tc] = _currentBoard[ans.fr][ans.fc];
    _currentBoard[ans.fr][ans.fc] = null;
    _p1Turn = false; // 後手の番に
    _moveCount++;

    setState(() {
      _feedback = '正解！これは詰みに向かう手です。';
      _selectedFrom = null;
    });

    // 後手の応手を自動選択
    await Future.delayed(const Duration(milliseconds: 800));
    _playDefenderMove();
  }

  void _playDefenderMove() {
    // 後手が詰みに陥っているかチェック
    if (!GL.hasLegalMove(_currentBoard, false, _p2Hand, _p1Hand)) {
      setState(() {
        _solved = true;
        _feedback = '詰みました！問題完了！';
      });
      widget.onCleared();
      return;
    }

    // 後手の合法手をランダムに選択（簡単な実装）
    final moves = <(int, int, int, int)>[];
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = _currentBoard[r][c];
        if (piece != null && piece.isPlayer1 == false) {
          final legalMoves = GL.legal(_currentBoard, r, c);
          for (final (tr, tc) in legalMoves) {
            moves.add((r, c, tr, tc));
          }
        }
      }
    }

    if (moves.isEmpty) {
      setState(() {
        _solved = true;
        _feedback = '詰みました！問題完了！';
      });
      widget.onCleared();
      return;
    }

    // ランダムに応手を選択
    final move = moves[(moves.length * 0.5).toInt()]; // 中央値を選択（戦略的な応手）
    _currentBoard[move.$3][move.$4] = _currentBoard[move.$1][move.$2];
    _currentBoard[move.$1][move.$2] = null;
    _p1Turn = true;
    _moveCount++;

    setState(() {
      _feedback = '後手の応手...';
    });

    // 後手の応手後、ユーザーの次の手を待つ
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _feedback = 'さらに有効な手を指してください。';
        });
      }
    });
  }

  void _handleWrong() {
    HapticFeedback.vibrate();
    final newLives = _lives - 1;
    setState(() {
      _lives = newLives;
      _selectedFrom = null;
      _feedback = newLives > 0 ? '違います。もう一度試してみよう。' : 'ヒントを表示します！';
      if (newLives <= 0) _showHint = true;
    });
  }

  Widget _buildLives() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('残り: ', style: TextStyle(color: Colors.white70, fontSize: 14)),
        ...List.generate(3, (i) {
          return Text(
            i < _lives ? '❤️' : '🖤',
            style: const TextStyle(fontSize: 16),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final prob = widget.prob;
    final screenW = MediaQuery.of(context).size.width;
    final boardSize = screenW - 32.0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _appBarColor,
        title: Text(
          prob.title,
          style: const TextStyle(
            color: Color(0xDEFFFFFF),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xDEFFFFFF)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Problem description
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F3460).withAlpha(200),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withAlpha(60)),
              ),
              child: Text(
                prob.description,
                style: const TextStyle(color: Color(0xDEFFFFFF), fontSize: 14, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),

            // Lives
            if (!_solved && !widget.isCleared)
              Center(child: _buildLives()),

            const SizedBox(height: 12),

            // Board with tap detection
            GestureDetector(
              onTapUp: (details) {
                if (_solved) return;
                final labelFraction = 0.05;
                final labelSize = boardSize * labelFraction;
                final boardPixels = boardSize - labelSize;
                final cellSize = boardPixels / 9;
                final x = details.localPosition.dx - labelSize;
                final y = details.localPosition.dy - labelSize;
                if (x < 0 || y < 0) return;
                final col = (x / cellSize).floor();
                final row = (y / cellSize).floor();
                if (row >= 0 && row < 9 && col >= 0 && col < 9) {
                  _onCellTap(row, col);
                }
              },
              child: Center(
                child: SizedBox(
                  width: boardSize,
                  height: boardSize,
                  child: MiniBoardWidget(
                    board: _currentBoard,
                    size: boardSize,
                    showLabels: true,
                    currentIsP1: _solved ? null : _p1Turn,
                    lastMoveFrom: _selectedFrom,
                    lastMoveTo: _solved
                        ? (prob.answer.tr, prob.answer.tc)
                        : null,
                    hintFrom: _hintFrom,
                    hintTo: _hintTo,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Hint toggle button (visible after first wrong attempt)
            if (!_solved && _lives < 3)
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _showHint = !_showHint),
                  icon: Icon(
                    _showHint ? Icons.lightbulb : Icons.lightbulb_outline,
                    color: Colors.amber,
                  ),
                  label: Text(
                    _showHint ? 'ヒント非表示' : 'ヒントを見る',
                    style: const TextStyle(color: Colors.amber),
                  ),
                ),
              ),

            // Feedback message
            if (_feedback != null)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _solved
                        ? Colors.green.shade800.withAlpha(220)
                        : Colors.red.shade800.withAlpha(200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _feedback!,
                    style: const TextStyle(
                      color: Color(0xDEFFFFFF),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Already cleared badge
            if (widget.isCleared && !_solved)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700.withAlpha(200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '正解済みの問題です',
                    style: TextStyle(
                      color: Color(0xDEFFFFFF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Explanation (shown after solving or if already cleared)
            if (_solved || widget.isCleared) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F3460).withAlpha(220),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withAlpha(120)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '解説',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      prob.explanation,
                      style: const TextStyle(
                        color: Color(0xDEFFFFFF),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F3460),
                    foregroundColor: Colors.amber,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('問題一覧に戻る'),
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
