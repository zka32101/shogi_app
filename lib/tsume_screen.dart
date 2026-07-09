// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'purchase_service.dart';
import 'piece.dart';
import 'theme/app_theme.dart';
import 'logic.dart';
import 'mini_board_widget.dart';
import 'tsume_engine.dart';

// ===== 問題データ =====

class _TsumeProb {
  final String title;
  final int moves;
  final List<List<Piece?>> board;
  final Map<PieceType, int> p1Hand;
  final Map<PieceType, int> p2Hand;
  final bool p1Turn;
  // 手順: 偶数インデックス(0,2,4)=先手の手、奇数インデックス(1,3)=後手の応手
  final List<AMove> solution;
  final String explanation;

  const _TsumeProb({
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

// ===== 問題集 =====
// 座標: board[row][col], row=0=1段目(上端), col=0=9筋(右端)
// 先手(p1=true): 上向き、敵陣=row0付近
// 後手(p2=false): 下向き、敵陣=row8付近

List<_TsumeProb> _problems = _buildProblems();
bool _extraProblemsLoaded = false;

// 外部JSON問題を非同期ロード（アプリ初回起動時に一度だけ）
Future<void> _loadExtraProblems() async {
  if (_extraProblemsLoaded) return;
  _extraProblemsLoaded = true;
  try {
    final jsonStr = await rootBundle.loadString('assets/tsume_extra.json');
    final List<dynamic> data = json.decode(jsonStr) as List<dynamic>;
    final extras = data
        .map((e) => _tsumeFromJson(e as Map<String, dynamic>))
        .whereType<_TsumeProb>()
        // 開始局面で後手玉がすでに王手/詰みの問題を除外
        .where((p) =>
            !GL.inCheck(p.board, false) &&
            GL.hasLegalMove(p.board, false, p.p2Hand, p.p1Hand))
        .toList();
    _problems.addAll(extras);
  } catch (_) {
    // ファイルがない/パースエラーは無視して内蔵問題のみ使用
  }
}

// ── JSON → _TsumeProb 変換 ──
// board: 81要素の文字列リスト。空="", 先手="+XX", 後手="-XX"
// CSAコード: OU王 HI飛 KA角 KI金 GI銀 KE桂 KY香 FU歩 RY龍 UM馬 NG全 NK圭 NY杏 TO と
_TsumeProb? _tsumeFromJson(Map<String, dynamic> j) {
  try {
    final rawBoard = (j['board'] as List<dynamic>).cast<String>();
    if (rawBoard.length != 81) return null;
    final b = _empty();
    for (int i = 0; i < 81; i++) {
      final s = rawBoard[i];
      if (s.isEmpty) continue;
      final isP1 = s[0] == '+';
      final code = s.substring(1);
      final type = _csaToType(code);
      if (type != null) b[i ~/ 9][i % 9] = Piece(type, isP1);
    }
    Map<PieceType, int> parseHand(Map<String, dynamic>? m) {
      if (m == null) return {};
      return {
        for (final e in m.entries)
          if (_csaToType(e.key) != null) _csaToType(e.key)!: e.value as int
      };
    }
    // 王の数チェック（先手・後手各1枚必須）
    int p1Kings = 0, p2Kings = 0;
    for (final row in b) {
      for (final p in row) {
        if (p?.type == PieceType.king) {
          if (p!.isPlayer1) p1Kings++; else p2Kings++;
        }
      }
    }
    if (p1Kings != 1 || p2Kings != 1) return null;

    final sol = (j['solution'] as List<dynamic>).map((e) {
      final m = e as Map<String, dynamic>;
      final tr = m['tr'] as int;
      final tc = m['tc'] as int;
      final fr = m['fr'] as int? ?? -1;
      final fc = m['fc'] as int? ?? -1;
      // 座標範囲チェック
      if (tr < 0 || tr > 8 || tc < 0 || tc > 8) throw FormatException('out of bounds');
      if (fr != -1 && (fr < 0 || fr > 8 || fc < 0 || fc > 8)) throw FormatException('out of bounds');
      return AMove(
        fr: fr,
        fc: fc,
        tr: tr,
        tc: tc,
        drop: m['drop'] != null ? _csaToType(m['drop'] as String) : null,
        promote: m['promote'] as bool? ?? false,
      );
    }).toList();
    return _TsumeProb(
      title: j['title'] as String,
      moves: j['moves'] as int,
      board: b,
      p1Hand: parseHand(j['p1Hand'] as Map<String, dynamic>?),
      p2Hand: parseHand(j['p2Hand'] as Map<String, dynamic>?),
      solution: sol,
      explanation: j['explanation'] as String? ?? '',
    );
  } catch (_) {
    return null;
  }
}

PieceType? _csaToType(String code) => const {
  'OU': PieceType.king,
  'HI': PieceType.rook,
  'KA': PieceType.bishop,
  'KI': PieceType.gold,
  'GI': PieceType.silver,
  'KE': PieceType.knight,
  'KY': PieceType.lance,
  'FU': PieceType.pawn,
  'RY': PieceType.promotedRook,
  'UM': PieceType.promotedBishop,
  'NG': PieceType.promotedSilver,
  'NK': PieceType.promotedKnight,
  'NY': PieceType.promotedLance,
  'TO': PieceType.promotedPawn,
}[code];

List<_TsumeProb> _buildProblems() {
  final list = <_TsumeProb>[];

  // ===== 1手詰め ① =====
  // 後手玉 1一(0,0)、先手金 2三(2,1)→1二(1,0) 王手
  // 後手玉の逃げ場: 2一=銀あり×、1二=金打ちマス×、2二=飛(3,1)の縦効き×
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);   // 後手玉 1一(0,0)
    b[8][8] = Piece(PieceType.king, true);    // 先手玉 9九(8,8)
    b[2][1] = Piece(PieceType.gold, true);    // 先手金 2三(2,1) ← 解答手
    b[0][1] = Piece(PieceType.silver, true);  // 先手銀 2一(0,1) ← 逃げ場封鎖
    b[3][1] = Piece(PieceType.rook, true);    // 先手飛 2四(3,1) ← 2二封鎖
    list.add(_TsumeProb(
      title: '1手詰め ①',
      moves: 1,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 2, fc: 1, tr: 1, tc: 0), // 金 2三→1二(王手・詰み)
      ],
      explanation: '金を2三から1二に引いて後手玉に王手をかけます。銀と飛が逃げ道を塞いでいるため詰み。',
    ));
  }

  // ===== 1手詰め ② =====
  // 後手玉 9一(0,8)、先手銀 8一(0,7)、先手金 9三(2,8)
  // 手順: 金 8二(1,7)打ち → 詰み
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king,   false); // 後手玉 9一(0,8)
    b[8][4] = Piece(PieceType.king,   true);  // 先手玉 5九(8,4)
    b[0][7] = Piece(PieceType.silver, true);  // 先手銀 8一(0,7) ← 8一封鎖
    b[2][8] = Piece(PieceType.gold,   true);  // 先手金 9三(2,8) ← 9二封鎖・8二守備
    list.add(_TsumeProb(
      title: '1手詰め ②',
      moves: 1,
      board: b,
      p1Hand: {PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 1, tc: 7, drop: PieceType.gold), // 金 8二打ち(王手・詰み)
      ],
      explanation: '持ち駒の金を8二に打ちます。8一は銀が封鎖し、9二は9三の金が守り、打った金自身も8二を守るため詰み。',
    ));
  }

  // ===== 1手詰め ③ =====
  // 先手龍で王手・詰め
  // 後手玉 5一(0,4)、先手龍 5三(2,4) ← 逃げ場封鎖、先手金 4二(1,3)、先手金 6二(1,5)
  // 手順: 龍 5三→5二(1,4)で王手
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);          // 後手玉 5一(0,4)
    b[8][4] = Piece(PieceType.king, true);            // 先手玉 5九(8,4)
    b[2][4] = Piece(PieceType.promotedRook, true);   // 先手龍 5三(2,4)
    b[1][3] = Piece(PieceType.gold, true);            // 先手金 4二(1,3)
    b[1][5] = Piece(PieceType.gold, true);            // 先手金 6二(1,5)
    list.add(_TsumeProb(
      title: '1手詰め ③',
      moves: 1,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 2, fc: 4, tr: 1, tc: 4), // 龍 5三→5二(王手・詰み)
      ],
      explanation: '龍を5三から5二に進めて王手をかけます。4一は金が、6一は金が、4二・6二には金がいるため詰み。',
    ));
  }

  // ===== 1手詰め ④ =====
  // 後手玉 5一(0,4)、先手銀 4一(0,3)・6一(0,5)、先手龍 6三(2,5)
  // 手順: 龍 6三→5二(1,4)で王手・詰み
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king,         false); // 後手玉 5一(0,4)
    b[8][4] = Piece(PieceType.king,         true);  // 先手玉 5九(8,4)
    b[0][3] = Piece(PieceType.silver,       true);  // 先手銀 4一(0,3) ← 4一封鎖・5二守備
    b[0][5] = Piece(PieceType.silver,       true);  // 先手銀 6一(0,5) ← 6一封鎖
    b[2][5] = Piece(PieceType.promotedRook, true);  // 先手龍 6三(2,5)
    list.add(_TsumeProb(
      title: '1手詰め ④',
      moves: 1,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 2, fc: 5, tr: 1, tc: 4), // 龍 6三→5二(王手・詰み)
      ],
      explanation: '龍を6三から5二に移動させて5一の後手玉に王手。4一・6一は銀が塞ぎ、4二・5二・6二は龍が封鎖するため詰み。',
    ));
  }

  // ===== 1手詰め ⑤ =====
  // 持ち駒の銀を打って詰める
  // 後手玉 9一(0,8)、先手金 8一(0,7) ← 逃げ場封鎖、先手飛 9三(2,8) ← 9二封鎖
  // 手順: 銀 8二(1,7)打ち
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);   // 後手玉 9一(0,8)
    b[8][8] = Piece(PieceType.king, true);    // 先手玉 9九(8,8)
    b[0][7] = Piece(PieceType.gold, true);    // 先手金 8一(0,7)
    b[2][8] = Piece(PieceType.rook, true);    // 先手飛 9三(2,8)
    list.add(_TsumeProb(
      title: '1手詰め ⑤',
      moves: 1,
      board: b,
      p1Hand: {PieceType.silver: 1},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 1, tc: 7, drop: PieceType.silver), // 銀 8二打ち(王手・詰み)
      ],
      explanation: '持ち駒の銀を8二に打って王手をかけます。8一は金が、9二は飛が塞いでいるため詰み。',
    ));
  }

  // ===== 1手詰め ⑥ =====
  // 後手玉 5一(0,4)、先手馬 7三(2,6)、先手金 4一(0,3)、先手金 6一(0,5)、先手銀 4二(1,3)
  // 手順: 馬 7三→6二(1,5)で王手
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);           // 後手玉 5一(0,4)
    b[8][4] = Piece(PieceType.king, true);             // 先手玉 5九(8,4)
    b[2][6] = Piece(PieceType.promotedBishop, true);   // 先手馬 7三(2,6)
    b[0][3] = Piece(PieceType.gold, true);             // 先手金 4一(0,3)
    b[0][5] = Piece(PieceType.gold, true);             // 先手金 6一(0,5)
    b[1][3] = Piece(PieceType.silver, true);           // 先手銀 4二(1,3)
    list.add(_TsumeProb(
      title: '1手詰め ⑥',
      moves: 1,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 2, fc: 6, tr: 1, tc: 5), // 馬 7三→6二(王手・詰み)
      ],
      explanation: '馬を7三から6二に進めて斜めに王手をかけます。両金と銀が後手玉の逃げ道を全て塞いでいます。',
    ));
  }

  // ===== 1手詰め ⑦ =====
  // 持ち駒の金を打って端玉を詰める
  // 後手玉 1一(0,0)、先手金 2二(1,1) ← 2一封鎖、先手飛 1四(3,0) ← 1二・1三封鎖
  // 手順: 金 1二(1,0)打ち
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);   // 後手玉 1一(0,0)
    b[8][8] = Piece(PieceType.king, true);    // 先手玉 9九(8,8)
    b[1][1] = Piece(PieceType.gold, true);    // 先手金 2二(1,1)
    b[3][0] = Piece(PieceType.rook, true);    // 先手飛 1四(3,0)
    list.add(_TsumeProb(
      title: '1手詰め ⑦',
      moves: 1,
      board: b,
      p1Hand: {PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 1, tc: 0, drop: PieceType.gold), // 金 1二打ち(王手・詰み)
      ],
      explanation: '持ち駒の金を1二に打って王手をかけます。金が2一を、飛が1三を塞いでいるため詰み。',
    ));
  }

  // ===== 3手詰め ① =====
  // 飛で後手歩を取り王手→後手玉4一に逃げ→金5二打ち詰め
  // 後手玉 3一(0,2)、先手飛 3五(4,2)、先手銀 2二(1,1)、先手金 4一(0,3)、後手歩 3三(2,2)
  // 手順: 飛 3五→3三(後手歩取り、縦で王手)→後手玉4一(金取り)→金5二打ち詰み
  {
    final b = _empty();
    b[0][2] = Piece(PieceType.king, false);   // 後手玉 3一(0,2)
    b[8][8] = Piece(PieceType.king, true);    // 先手玉 9九(8,8)
    b[4][2] = Piece(PieceType.rook, true);    // 先手飛 3五(4,2)
    b[1][1] = Piece(PieceType.silver, true);  // 先手銀 2二(1,1)
    b[0][3] = Piece(PieceType.gold, true);    // 先手金 4一(0,3)
    b[2][2] = Piece(PieceType.pawn, false);   // 後手歩 3三(2,2) ← 飛の王手を遮断
    list.add(_TsumeProb(
      title: '3手詰め ①',
      moves: 3,
      board: b,
      p1Hand: {PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: 4, fc: 2, tr: 2, tc: 2),                           // 飛 3五→3三(後手歩取り、王手)
        AMove(fr: 0, fc: 2, tr: 0, tc: 3),                           // 後手玉 3一→4一(金取り、唯一の逃げ)
        AMove(fr: -1, fc: -1, tr: 1, tc: 4, drop: PieceType.gold),  // 金 5二打ち(詰み)
      ],
      explanation: '飛で後手歩を取りながら王手。後手玉は銀・飛に塞がれ4一(金取り)しか逃げられません。最後に金を5二に打って詰めます。',
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
    list.add(_TsumeProb(
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
      explanation: '龍で後手歩を取りながら王手。後手玉は2一に逃げるしかなく、角が3二に成って馬になると、金と龍の利きで全逃げ道が塞がれ詰みです。',
    ));
  }

  // ===== 3手詰め ③ =====
  // 馬を使った3手詰め
  // 後手玉 9一(0,8)、先手馬 7四(3,6)、先手香 9九(8,8) ← 9二を塞ぐ
  // 手順:
  //   1. 馬 7四→8二(1,7) 王手(馬の斜め1マス(0,8)=9一✓)
  //   2. 後手玉 9一→8一(0,7) 逃げ
  //   3. 馬 8二→8一(0,7) 後手玉取り(詰み)
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);           // 後手玉 9一(0,8)
    b[8][0] = Piece(PieceType.king, true);            // 先手玉 1九(8,0)
    b[3][6] = Piece(PieceType.promotedBishop, true);  // 先手馬 7四(3,6)
    b[8][8] = Piece(PieceType.lance, true);           // 先手香 9九(8,8)
    list.add(_TsumeProb(
      title: '3手詰め ③',
      moves: 3,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 3, fc: 6, tr: 1, tc: 7),  // 馬 7四→8二(王手)
        AMove(fr: 0, fc: 8, tr: 0, tc: 7),  // 後手玉 9一→8一(応手)
        AMove(fr: 1, fc: 7, tr: 0, tc: 7),  // 馬 8二→8一(詰み)
      ],
      explanation: '馬を8二に進めて斜めに王手し、後手玉が8一に逃げたところを馬で取って詰めます。香が9二への逃げを防いでいます。',
    ));
  }

  // ===== 3手詰め ④ =====
  // 飛で王手→後手玉6一逃げ→金打ち詰め
  // 後手玉 5一(0,4)、先手飛 2五(4,2)、先手金 4一(0,3)、先手銀 6二(1,5)
  // 手順:
  //   1. 飛 2五→2四(4,4)に横移動→5二へ(row1)に進める代わり、横に5二へ
  //   実際: 飛を横に動かして2五→2四経由で5二に進める
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);   // 後手玉 5一(0,4)
    b[8][4] = Piece(PieceType.king, true);    // 先手玉 5九(8,4)
    b[4][2] = Piece(PieceType.rook, true);    // 先手飛 2五(4,2)
    b[0][3] = Piece(PieceType.gold, true);    // 先手金 4一(0,3)
    b[1][5] = Piece(PieceType.silver, true);  // 先手銀 6二(1,5)
    list.add(_TsumeProb(
      title: '3手詰め ④',
      moves: 3,
      board: b,
      p1Hand: {PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: 4, fc: 2, tr: 1, tc: 4),                          // 飛 2五→2二の右(1,4)=5二(王手)
        AMove(fr: 0, fc: 4, tr: 0, tc: 5),                          // 後手玉 5一→6一(応手)
        AMove(fr: -1, fc: -1, tr: 0, tc: 6, drop: PieceType.gold), // 金 7一打ち(詰み)
      ],
      explanation: '飛で王手して後手玉を6一に追い込み、金を7一に打って詰めます。金と銀が周囲を固めています。',
    ));
  }

  // ===== 3手詰め ⑤ =====
  // 龍で横王手→後手玉1二逃げ→金で詰め
  // 後手玉 1一(0,0)、先手龍 3六(5,2)、先手金 2三(2,1)
  // 手順:
  //   1. 龍 3六→2一(0,1) 王手(横)
  //   2. 後手玉 1一→1二(1,0) 逃げ
  //   3. 金 2三→1二(1,0) 後手玉取り(詰み)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);          // 後手玉 1一(0,0)
    b[8][8] = Piece(PieceType.king, true);            // 先手玉 9九(8,8)
    b[5][2] = Piece(PieceType.promotedRook, true);   // 先手龍 3六(5,2)
    b[2][1] = Piece(PieceType.gold, true);            // 先手金 2三(2,1)
    list.add(_TsumeProb(
      title: '3手詰め ⑤',
      moves: 3,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 5, fc: 2, tr: 0, tc: 1),  // 龍 3六→2一(王手)
        AMove(fr: 0, fc: 0, tr: 1, tc: 0),  // 後手玉 1一→1二(応手)
        AMove(fr: 2, fc: 1, tr: 1, tc: 0),  // 金 2三→1二(詰み)
      ],
      explanation: '龍を横に動かして王手し、後手玉が1二に逃げたところを金で捕まえます。端への追い込みが決め手です。',
    ));
  }

  // ===== 3手詰め ⑥ =====
  // 馬で王手→後手玉9二逃げ→馬で詰め
  // 後手玉 9一(0,8)、先手馬 7四(3,6)、先手金 8三(2,7) ← 9三を塞ぐ
  // 手順:
  //   1. 馬 7四→8二(1,7) 王手(馬の斜め(0,8)=9一✓)
  //   2. 後手玉 9一→9二(1,8) 逃げ
  //   3. 馬 8二→9二(1,8) 後手玉取り(詰み)
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);           // 後手玉 9一(0,8)
    b[8][0] = Piece(PieceType.king, true);             // 先手玉 1九(8,0)
    b[3][6] = Piece(PieceType.promotedBishop, true);  // 先手馬 7四(3,6)
    b[2][7] = Piece(PieceType.gold, true);             // 先手金 8三(2,7)
    list.add(_TsumeProb(
      title: '3手詰め ⑥',
      moves: 3,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 3, fc: 6, tr: 1, tc: 7),  // 馬 7四→8二(王手)
        AMove(fr: 0, fc: 8, tr: 1, tc: 8),  // 後手玉 9一→9二(応手)
        AMove(fr: 1, fc: 7, tr: 1, tc: 8),  // 馬 8二→9二(詰み)
      ],
      explanation: '馬を8二に進めて斜めに王手し、後手玉が9二に逃げたところを馬で横に動いて詰めます。金が9三への逃げを防いでいます。',
    ));
  }

  // ===== 3手詰め ⑦ =====
  // 飛で王手→後手玉4一逃げ→銀打ち詰め
  // 後手玉 5一(0,4)、先手飛 2五(4,2)、先手金 4二(1,3)、先手銀 3一(0,2)
  // 持ち駒: 銀
  // 手順:
  //   1. 飛 2五→2二,5二(1,4) に横移動で王手
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);   // 後手玉 5一(0,4)
    b[8][4] = Piece(PieceType.king, true);    // 先手玉 5九(8,4)
    b[4][2] = Piece(PieceType.rook, true);    // 先手飛 2五(4,2)
    b[1][3] = Piece(PieceType.gold, true);    // 先手金 4二(1,3)
    b[0][2] = Piece(PieceType.silver, true);  // 先手銀 3一(0,2)
    list.add(_TsumeProb(
      title: '3手詰め ⑦',
      moves: 3,
      board: b,
      p1Hand: {PieceType.silver: 1},
      p2Hand: {},
      solution: [
        AMove(fr: 4, fc: 2, tr: 1, tc: 4),                            // 飛 2五→5二(1,4)(王手)
        AMove(fr: 0, fc: 4, tr: 0, tc: 3),                            // 後手玉 5一→4一(応手)
        AMove(fr: -1, fc: -1, tr: 1, tc: 4, drop: PieceType.silver), // 銀 5二打ち(詰み)
      ],
      explanation: '飛で王手して後手玉を4一に追い込み、持ち駒の銀を5二に打って詰めます。盤上の銀と金が逃げ道を封じています。',
    ));
  }

  // ===== 5手詰め ① =====
  // 後手玉を端に追い詰める飛車・金の5手詰め
  // 後手玉 1一(row0,col0)、先手飛 1五(row4,col0)、先手金 3二(row1,col2)
  // 先手金 2三(row2,col1)
  //
  // 手順:
  //   1. 飛 1五(4,0)→1二(1,0) 王手(後手玉に縦)
  //   2. 後手玉 1一(0,0)→2一(0,1) 逃げ
  //      (1二(1,0)=飛あり×)
  //   3. 金 2三(2,1)→2二(1,1) 王手
  //      金(1,1,fwd=-1)の効き: (0,1)=2一✓
  //   4. 後手玉 2一(0,1)→3一(0,2) 逃げ
  //      (1一(0,0)=飛の横効き✓×、2二(1,1)=金あり×、1二(1,0)=飛あり×)
  //   5. 金 3二(row1,col2)→3一(0,2) 後手玉取り(詰み)
  //      後手玉3一の逃げ場:
  //        2一(0,1)=金(1,1)の効き(0,1)✓ ×
  //        4一(0,3): 金(1,2)→(0,2)移動後の効き(0,3)? 金fwd=-1から(0,2): step(0,1)=(0,3)=4一✓ ×
  //        3二(1,2)=金が動いたので空き → 飛(1,0)の横効き(1,2)✓ ×
  //        2二(1,1)=金(2,1)→(1,1)があり ×
  //      → 詰み ✓
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);   // 後手玉 1一(0,0)
    b[8][8] = Piece(PieceType.king, true);    // 先手玉 9九(8,8)
    b[4][0] = Piece(PieceType.rook, true);    // 先手飛 1五(4,0)
    b[1][2] = Piece(PieceType.gold, true);    // 先手金 3二(1,2)
    b[2][1] = Piece(PieceType.gold, true);    // 先手金 2三(2,1)
    list.add(_TsumeProb(
      title: '5手詰め ①',
      moves: 5,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 4, fc: 0, tr: 1, tc: 0),  // 飛 1五→1二(王手)
        AMove(fr: 0, fc: 0, tr: 0, tc: 1),  // 後手玉 1一→2一(応手)
        AMove(fr: 2, fc: 1, tr: 1, tc: 1),  // 金 2三→2二(王手)
        AMove(fr: 0, fc: 1, tr: 0, tc: 2),  // 後手玉 2一→3一(応手)
        AMove(fr: 1, fc: 2, tr: 0, tc: 2),  // 金 3二→3一(詰み)
      ],
      explanation: '飛で縦に王手して後手玉を横に追い、金で二段階に追い詰めます。飛と金の連携で後手玉を端に追い込む典型的な手筋です。',
    ));
  }

  // ===== 5手詰め ② =====
  // 後手玉 9一(row0,col8)に龍と金で追い詰める
  // 後手玉 9一(row0,col8)、先手龍 7一(row0,col6)、先手金 8三(row2,col7)
  // 先手金 9四(row3,col8)
  //
  // 手順:
  //   1. 龍 7一(0,6)→8一(0,7) 王手(横)
  //      後手玉9一の逃げ場: 9二(1,8)=金(3,8)の縦効き? 金(3,8,fwd=-1)の縦効き→(2,8),(1,8)✓ → ×
  //        8一(0,7)=龍あり ×
  //   2. 後手玉 9一(0,8)→9二(1,8) 逃げ
  //      (9二(1,8)=金(3,8)の縦効き…確認: 金は縦には後ろ1マスのみ。fwd=-1で前は上)
  //      金(3,8,fwd=-1)の効き: (-1,-1)=2,7, (-1,0)=2,8, (-1,1)=2,9=out, (0,-1)=3,7, (0,1)=3,9=out, (1,0)=4,8
  //      → 金(3,8)は(2,8)=9三に効くが(1,8)=9二には直接効かない
  //      → 9二に逃げられる(次に別の王手が必要)
  //   3. 金 8三(2,7)→8二(1,7) 王手
  //      金(1,7,fwd=-1)の効き: (0,8)=9一? step(-1,1)=(0,8)✓ → 9二(1,8)に後手玉がいる場合:
  //      金(1,7)→後手玉(1,8): step(0,1)=(1,8)✓ ×
  //   4. 後手玉 9二(1,8)→9三(2,8) 逃げ
  //      (8二(1,7)=金あり×、9一(0,8)=龍(0,7)の横効き✓ ×)
  //   5. 金 9四(3,8)→9三(2,8) 後手玉取り(詰み)
  //      後手玉9三の逃げ場:
  //        8二(1,7)=金あり ×
  //        9二(1,8)=金(1,7)の効き step(0,1)=(1,8)=9二✓ → 金(1,7)の効き範囲なので ×
  //        8三(2,7)=金が動いたので空き → 金(3,8)→(2,8)の移動後: 龍(0,7)の縦効き下=(1,7),(2,7)=8三✓ ×
  //        9四(3,8)=金が動いたので空き → 後手玉が上(row小)に戻ろうとすれば9二は金の効き×
  //      → 詰み ✓
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);          // 後手玉 9一(0,8)
    b[8][0] = Piece(PieceType.king, true);            // 先手玉 1九(8,0)
    b[0][6] = Piece(PieceType.promotedRook, true);   // 先手龍 7一(0,6)
    b[2][7] = Piece(PieceType.gold, true);            // 先手金 8三(2,7)
    b[3][8] = Piece(PieceType.gold, true);            // 先手金 9四(3,8)
    list.add(_TsumeProb(
      title: '5手詰め ②',
      moves: 5,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 0, fc: 6, tr: 0, tc: 7),  // 龍 7一→8一(王手)
        AMove(fr: 0, fc: 8, tr: 1, tc: 8),  // 後手玉 9一→9二(応手)
        AMove(fr: 2, fc: 7, tr: 1, tc: 7),  // 金 8三→8二(王手)
        AMove(fr: 1, fc: 8, tr: 2, tc: 8),  // 後手玉 9二→9三(応手)
        AMove(fr: 3, fc: 8, tr: 2, tc: 8),  // 金 9四→9三(詰み)
      ],
      explanation: '龍と金を連携させて後手玉を9筋の端に追い込みます。龍が横から王手し、金が縦に追い詰める5手詰めです。',
    ));
  }

  // ===== 5手詰め ③ =====
  // 後手玉 5一(row0,col4)を中央から追い出す5手詰め
  // 後手玉 5一(row0,col4)、先手飛 5五(row4,col4)、先手金 4二(row1,col3)
  // 先手金 6二(row1,col5)、先手銀 4一(row0,col3) ← 配置調整
  //
  // 実際の配置:
  // 後手玉 5一(0,4)、先手飛 5五(4,4)、先手金 6三(2,5)、先手銀 4三(2,3)
  //
  // 手順:
  //   1. 飛 5五(4,4)→5二(1,4) 王手
  //   2. 後手玉 5一(0,4)→4一(0,3) 逃げ
  //      (5二(1,4)=飛あり×、6一(0,5): 飛の横効き(0,5)✓ ×)
  //   3. 銀 4三(2,3)→3二(1,2) 王手
  //      銀(1,2,fwd=-1)の効き: (-1,-1)=0,1, (-1,1)=0,3=4一✓
  //   4. 後手玉 4一(0,3)→3一(0,2) 逃げ
  //      (4二(1,3): 銀(1,2)の効き step(0,1)=(1,3)? 銀は斜めのみ → (1,3)には効かない
  //       先手金 6三(2,5)→3一に効く駒が必要 → 先手金 4一(row0,col3)は後手玉の邪魔なので配置変更
  //       先手金 3三(row2,col2)を追加)
  //   → 再構成: 先手金 3三(2,2) で3一を守る
  //   5. 金 3三(2,2)→3二(1,2) 後手玉3一を王手? 金(1,2)の効き(0,2)=3一✓
  //      後手玉3一の逃げ場:
  //        2一(0,1): 飛(1,4)の横効き(1,1),(1,0)... → row1の横, (0,1)は row0なので飛の横では届かない
  //          → 2一フリー? → 先手金追加か確認
  //        銀(1,2)は(2,2)に金が動いた後空き。銀の効き from(1,2): (0,1)=2一✓ → ×
  //        4一(0,3)=飛(1,4)の横効き(1,3)... 飛はrow1にいる→(0,3)には縦では届かない
  //          (0,3): 飛(1,4)の縦上効き(0,4)=5一, 横左(1,3),(1,2)...  → (0,3)は飛の縦上の途中ではない
  //          → 4一フリー? → 金3二の効き(0,3)=step(-1,1)? 金fwd=-1 from(1,2): (-1,1)=(0,3)=4一✓ ×
  //        3二(1,2)=金あり ×
  //      → 詰み ✓
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);   // 後手玉 5一(0,4)
    b[8][4] = Piece(PieceType.king, true);    // 先手玉 5九(8,4)
    b[4][4] = Piece(PieceType.rook, true);    // 先手飛 5五(4,4)
    b[2][3] = Piece(PieceType.silver, true);  // 先手銀 4三(2,3)
    b[2][2] = Piece(PieceType.gold, true);    // 先手金 3三(2,2)
    list.add(_TsumeProb(
      title: '5手詰め ③',
      moves: 5,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 4, fc: 4, tr: 1, tc: 4),  // 飛 5五→5二(王手)
        AMove(fr: 0, fc: 4, tr: 0, tc: 3),  // 後手玉 5一→4一(応手)
        AMove(fr: 2, fc: 3, tr: 1, tc: 2),  // 銀 4三→3二(王手)
        AMove(fr: 0, fc: 3, tr: 0, tc: 2),  // 後手玉 4一→3一(応手)
        AMove(fr: 2, fc: 2, tr: 1, tc: 2),  // 金 3三→3二(詰み)
      ],
      explanation: '飛で王手してから銀で斜めに追い、最後に金で仕留めます。中央から端へ追い込む流れが鮮やかな5手詰めです。',
    ));
  }

  // ===== 5手詰め ④ =====
  // 後手玉 1一(row0,col0)、先手龍 3三(row2,col2)、先手金 2一(row0,col1)
  // 先手香 1九(row8,col0)
  //
  // 手順:
  //   1. 龍 3三(2,2)→3一(0,2) 王手(縦)
  //   2. 後手玉 1一(0,0)→1二(1,0) 逃げ
  //      (2一(0,1)=金あり×、2二(1,1)=龍の斜め1マス効き(1,1)✓×)
  //   3. 龍 3一(0,2)→2二(1,1) 王手(斜め1マス)
  //      龍(1,1)の効き: (0,0)=1一, (0,1)=2一, (0,2)=3一, (1,0)=1二✓(後手玉がいる)
  //      → 1二の後手玉を龍で王手: (1,1)から step→(1,0)=横1マス✓
  //   4. 後手玉 1二(1,0)→1三(2,0) 逃げ
  //      (2二(1,1)=龍あり×、1一(0,0)=龍の縦効き✓×)
  //      香(8,0)の縦効き: row8→row2,1,0 → (7,0),(6,0),...,(1,0)=1二 → (2,0)=1三は香の効き外?(香は上方向=row小方向)
  //      香(isP1=true,fwd=-1)の効き: 前方のみ = fwd方向=row-1 → (7,0),(6,0),...,(1,0) → (2,0)=1三は(3,0)と(1,0)の間なので香の通り道✓ ×?
  //      香(8,0)→fwd=-1→ (7,0),(6,0),(5,0),(4,0),(3,0),(2,0)=1三✓ ×
  //      → 1三も香の効きで封鎖 → 詰み？ → 後手玉 1三に逃げられない
  //      → 後手玉は1三に逃げられない → 2三(2,1): 龍(1,1)の効き(2,1)=斜め1マス(1,0)→(2,1)? 龍は縦横スライド+斜め1マス
  //         龍(1,1)の斜め1マス: (0,0),(0,2),(2,0),(2,2) → (2,1)には効かない
  //         → 2三フリー → 先手金(0,1)の効き from(0,1): (1,0)=1二,(-1,0)=out,(-1,-1)=out,(-1,1)=out,(0,-1)=1一,(0,1)=3一,(1,-1)=out? 金fwd=-1 from(0,1): (-1,-1)=out,(-1,0)=out,(-1,1)=out,(0,-1)=(0,0),(0,1)=(0,2),(1,0)=(1,1)
  //         金(0,1)は(2,1)=2三に効かない → 2三に逃げられる
  //      → 手順を再検討 → 5手詰めとして単純化するため盤面を修正
  //   【修正版】先手金 2三(row2,col1) に変更
  //   金(2,1,fwd=-1)の効き: (1,0)=1二,(1,1)=2二,(1,2)=3二,(2,0)=1三,(2,2)=3三,(3,1)=2四
  //   → 1三(2,0)=金(2,1)の効き(2,0)✓ → 後手玉1三に逃げれない
  //   → 手順継続:
  //   5. 金 2三(2,1)→1二(1,0) 後手玉取り? → 後手玉は(2,0)に逃げた後だから金が(2,1)→(2,0)
  //      金(2,1,fwd=-1)の効き: (2,0)✓ → 金 2三→1三(2,0) 詰み
  //      後手玉1三の逃げ場:
  //        1二(1,0)=金(2,1)の効き(1,0)✓ ×
  //        2三(2,1)=金が動くので空き → 龍(1,1)の効き(2,2)=3三? 龍は(1,1)から縦横スライド+斜め1マス
  //          縦下: (2,1),(3,1)... → (2,1)は金が動いた後空き → 龍(1,1)の縦下効き(2,1)=2三✓ ×
  //        2四(3,1): 龍(1,1)の縦下効き(2,1),(3,1)=2四✓ ×
  //      → 詰み ✓
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);          // 後手玉 1一(0,0)
    b[8][8] = Piece(PieceType.king, true);            // 先手玉 9九(8,8)
    b[2][2] = Piece(PieceType.promotedRook, true);   // 先手龍 3三(2,2)
    b[0][1] = Piece(PieceType.gold, true);            // 先手金 2一(0,1)
    b[2][1] = Piece(PieceType.gold, true);            // 先手金 2三(2,1)
    list.add(_TsumeProb(
      title: '5手詰め ④',
      moves: 5,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 2, fc: 2, tr: 0, tc: 2),  // 龍 3三→3一(王手)
        AMove(fr: 0, fc: 0, tr: 1, tc: 0),  // 後手玉 1一→1二(応手)
        AMove(fr: 0, fc: 2, tr: 1, tc: 1),  // 龍 3一→2二(王手)
        AMove(fr: 1, fc: 0, tr: 2, tc: 0),  // 後手玉 1二→1三(応手)
        AMove(fr: 2, fc: 1, tr: 2, tc: 0),  // 金 2三→1三(詰み)
      ],
      explanation: '龍で連続王手して後手玉を1筋の奥に追い込み、金で詰めます。龍の縦横と斜めの動きをフルに活用した5手詰めです。',
    ));
  }

  // ===== 5手詰め ⑤ =====
  // 後手玉 9一(row0,col8)、先手飛 7一(row0,col6)、先手金 8三(row2,col7)
  // 先手銀 9三(row2,col8)
  //
  // 手順:
  //   1. 飛 7一(0,6)→9一(0,8) 後手玉取り王手(横)
  //      → 後手玉は9一にいるので飛が来ると取られる → 逃げる
  //   2. 後手玉 9一(0,8)→8一(0,7) 逃げ
  //      (9二(1,8)=銀(2,8)の効き? 銀(2,8,fwd=-1)の効き: (-1,-1)=(1,7),(-1,1)=(1,9)=out,(1,-1)=(3,7),(1,1)=(3,9)=out
  //        → 銀(2,8)の効き(1,8)=9二? step (-1,-1)=(2-1,8-1)=(1,7)=8二, (-1,0)=銀は(-1,0)に効かない
  //        銀の効き: fwd=-1なので前=上=row-1。銀の動き: (fwd-1,fwd-1),(fwd-1,0)?
  //        実際の銀の効き(isP1=true,fwd=-1): (-1,-1),(-1,0),(-1,1),(1,-1),(1,1) = 斜め4方向+前縦
  //        銀(2,8)の効き: (1,7)=8二,(1,8)=9二? step(-1,0)=(2-1,8)=(1,8)=9二✓ ×
  //        → 9二(1,8)も銀の効き → 8一のみ逃げ場)
  //   3. 金 8三(2,7)→8二(1,7) 王手
  //      金(1,7,fwd=-1)の効き: (0,7)=8一✓(後手玉)
  //   4. 後手玉 8一(0,7)→7一(0,6) 逃げ
  //      (8二(1,7)=金あり×、9一(0,8)=飛(0,8)がいるので× → 飛は(0,8)に移動済み)
  //      飛(0,8,isP1)の横効き左: (0,7),(0,6),(0,5)... → (0,7)=8一(金の効き内)→ 7一(0,6)は飛の効き ×
  //      → 後手玉7一に逃げると飛の効き内 → 7一もだめ
  //      → 後手玉の逃げ場: 8一でも7一でも飛の効き内...
  //      → 7二(1,6): 金(1,7)の効き(1,6)=step(0,-1)=(1,6)=7二✓ ×
  //      → 後手玉8一の逃げ場なし → 3手で詰み → 手順修正
  //   【修正】銀を使って5手に延ばす構成:
  //   後手玉 9一(row0,col8)、先手飛 7三(row2,col6)、先手金 9四(row3,col8)
  //   先手銀 8三(row2,col7)
  //
  //   手順:
  //   1. 銀 8三(2,7)→8二(1,7) 王手
  //      銀(1,7,fwd=-1)の効き: (-1,-1)=(0,6),(−1,0)=(0,7),(−1,1)=(0,8)=9一✓
  //   2. 後手玉 9一(0,8)→9二(1,8) 逃げ
  //      (8一(0,7)=銀の前縦効き(-1,0)=(0,7)✓ →後手玉が8一に行くと銀に取られる ×)
  //   3. 飛 7三(2,6)→9三(2,8) 王手(横)
  //      飛(2,8)の縦効き上: (1,8)=9二✓(後手玉)
  //   4. 後手玉 9二(1,8)→8二(1,7) 逃げ(飛の縦効きから逃げる)
  //      (9三(2,8)=飛あり×、9一(0,8)=銀(1,7)の斜め効き(0,8)✓ → 取りに行けるが先手銀取り → 合法だが詰みを解く)
  //      → 後手玉が8二(1,7)の銀を取る → 逆王手? 先手玉は安全ならok
  //      後手玉(1,7)の位置で次手:
  //   5. 金 9四(3,8)→9三(2,8) でなく、飛(2,8)の縦効き(1,8)は8二に後手玉がいないので有効
  //      飛(2,8)の縦効き上: (1,8)=空, (0,8)=空
  //      → 後手玉は8二(1,7)にいる(銀を取った)
  //      金 9四(3,8)→8四(3,7) 王手? 金(3,7,fwd=-1)の効き(2,7)=8三... 後手玉は(1,7)
  //        金(3,7)→後手玉(1,7)まで2マス離れているので届かない
  //      → 手順が複雑すぎるため別の5手詰め構成に変更
  //
  //   【最終版】後手玉 1一(row0,col0)、先手飛 3一(row0,col2)、先手金 2三(row2,col1)
  //   先手銀 1三(row2,col0)
  //
  //   手順:
  //   1. 飛 3一(0,2)→2一(0,1) 王手(横)
  //   2. 後手玉 1一(0,0)→1二(1,0) 逃げ
  //      (2一(0,1)=飛あり×)
  //   3. 金 2三(2,1)→2二(1,1) 王手
  //      金(1,1,fwd=-1)の効き: (0,1)=2一, step(0,-1)=(1,0)=1二✓(後手玉)
  //      → 1二の後手玉に王手 ✓
  //   4. 後手玉 1二(1,0)→1三(2,0) 逃げ
  //      (2二(1,1)=金あり×、1一(0,0)=飛(0,1)の横効き(0,0)✓ ×)
  //      銀(2,0)がいる → 1三に銀がいるので後手玉は1三に行けない
  //      → 先手銀 1三 → 2四(row3,col0)に変更
  //      先手銀 2四(3,0):
  //   4'. 後手玉 1二(1,0)→1三(2,0) 逃げ(1三がフリーになった)
  //   5. 銀 2四(3,0)→1三(2,0) 後手玉取り? 銀(3,0,fwd=-1)の効き: (-1,-1)=(2,-1)=out, (-1,0)=(2,0)=1三✓
  //      後手玉1三の逃げ場:
  //        1二(1,0)=金(1,1)の効き(1,0)✓ ×
  //        2三(2,1)=金が動いた後空き → 飛(0,1)の縦効き下(1,1),(2,1)=2三✓ ×
  //        2四(3,0)=銀が動くので空き → 後手玉が2三に逃げようとすると飛の効き内
  //        1四(3,0)=銀が動くので空き: 後手玉(2,0)から(3,0)に逃げる
  //          → 銀(3,0)→(2,0)に動いた後、(3,0)は空き
  //          → 後手玉1三(2,0)に銀が来る → 後手玉取られる
  //          後手玉が1三で詰まるには(3,0)への逃げも封じる必要
  //          先手金 2三(2,1)の効き from(1,1)の移動後: 金は(2,1)→(1,1)に動いたので(2,1)は空き
  //          (3,0)=1四: 誰も利いていない → 逃げられる可能性
  //          → 先手香 1九(8,0)の縦効き: (7,0),...,(3,0)=1四✓ → 香追加
  //   先手香 1九(8,0) 追加:
  //      後手玉1三(2,0)の逃げ場:
  //        1二(1,0)=金(1,1)の効き ×
  //        2三(2,1)=飛(0,1)縦効き ×
  //        1四(3,0)=香(8,0)の縦効き ×
  //      → 詰み ✓
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);   // 後手玉 1一(0,0)
    b[8][8] = Piece(PieceType.king, true);    // 先手玉 9九(8,8)
    b[0][2] = Piece(PieceType.rook, true);    // 先手飛 3一(0,2)
    b[2][1] = Piece(PieceType.gold, true);    // 先手金 2三(2,1)
    b[3][0] = Piece(PieceType.silver, true);  // 先手銀 2四(3,0)
    b[8][0] = Piece(PieceType.lance, true);   // 先手香 1九(8,0)
    list.add(_TsumeProb(
      title: '5手詰め ⑤',
      moves: 5,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 0, fc: 2, tr: 0, tc: 1),  // 飛 3一→2一(王手)
        AMove(fr: 0, fc: 0, tr: 1, tc: 0),  // 後手玉 1一→1二(応手)
        AMove(fr: 2, fc: 1, tr: 1, tc: 1),  // 金 2三→2二(王手)
        AMove(fr: 1, fc: 0, tr: 2, tc: 0),  // 後手玉 1二→1三(応手)
        AMove(fr: 3, fc: 0, tr: 2, tc: 0),  // 銀 2四→1三(詰み)
      ],
      explanation: '飛で横に王手してから金で追い、銀で仕留めます。飛・金・銀の連携で後手玉を端に追い込む5手詰めです。',
    ));
  }

  // ===== 5手詰め ⑥ =====
  // 後手玉 5一(row0,col4)、先手飛 5六(row5,col4)、先手金 4一(row0,col3)
  // 先手金 6三(row2,col5)、先手銀 4三(row2,col3)
  //
  // 手順:
  //   1. 飛 5六(5,4)→5二(1,4) 王手
  //   2. 後手玉 5一(0,4)→6一(0,5) 逃げ
  //      (4一(0,3)=金あり×、5二(1,4)=飛あり×)
  //   3. 金 6三(2,5)→6二(1,5) 王手
  //      金(1,5,fwd=-1)の効き: (0,5)=6一✓(後手玉)
  //   4. 後手玉 6一(0,5)→7一(0,6) 逃げ
  //      (5一(0,4)=飛(1,4)縦効き×、6二(1,5)=金あり×)
  //   5. 銀 4三(2,3)→5二(1,4)? 銀fwd=-1 from(2,3): (-1,1)=(1,4)=5二=飛あり
  //      → 飛がいるので置けない
  //      → 別手順: 金 4一(0,3)→5一(0,4) 後手玉7一に効く?
  //      金(0,4)の効き: (0,5)=6一✓, step(-1,1)=out... 後手玉は(0,6)=7一
  //      金(0,4)から(0,6)まで2マス → 届かない
  //      → 飛 5二(1,4)→7二(1,6) 王手? 飛の横効き(1,4)→(1,6)=2マス → (1,5)=金を通過できない
  //      → 飛(1,4)→(1,6): 途中(1,5)=金がいる → 不可
  //      → 銀 4三(2,3)→6一(0,5)? 銀の移動範囲外
  //      → 飛 5二(1,4)→7一(0,4)? 移動先の座標ミス
  //      → 飛 5二(1,4)→(0,4)=5一? 縦上1マス → 5一は空き(後手玉が移動済み) ✓
  //        飛(0,4)の横効き: (0,5)=6一,(0,6)=7一✓(後手玉) → 王手 ✓
  //   5. 飛 5二(1,4)→5一(0,4) 横利きで7一の後手玉に王手
  //      後手玉7一(0,6)の逃げ場:
  //        6一(0,5)=飛(0,4)の横効き(0,5)✓ ×
  //        8一(0,7): 飛(0,4)の横効き(0,7)? (0,5),(0,6),(0,7)... → (0,6)=7一を通過するのでその先(0,7)は利かない
  //          → 8一フリー? → 先手金(1,5)の効き from(1,5): (0,5)=6一,(0,6)=7一✓,(0,7)=8一? step(-1,1)=(0,6)✓ のみ
  //          金(1,5,fwd=-1)の効き: (-1,-1)=(0,4),(-1,0)=(0,5),(-1,1)=(0,6),(0,-1)=(1,4),(0,1)=(1,6),(1,0)=(2,5)
  //          → 8一(0,7)は金の効き外 → 逃げられる
  //      → 手順が5手詰めとして不完全 → 盤面を再調整
  //
  //   【最終版⑥】後手玉 9一(row0,col8)で端に追い詰める構成
  //   後手玉 9一(row0,col8)、先手龍 7三(row2,col6)、先手金 8二(row1,col7)
  //   先手金 9三(row2,col8)
  //
  //   手順:
  //   1. 龍 7三(2,6)→7一(0,6) 王手(縦)
  //   2. 後手玉 9一(0,8)→9二(1,8) 逃げ
  //      (8一(0,7)=金(1,7)の効き(-1,0)=(0,7)✓ ×)
  //   3. 金 8二(1,7)→8三(2,7) 王手? 金fwd=-1 from(1,7): (-1,-1)=(0,6),(−1,0)=(0,7),(−1,1)=(0,8),(0,-1)=(1,6),(0,1)=(1,8)=9二✓(後手玉),(1,0)=(2,7)
  //      (1,7)から後手玉(1,8): step(0,1)=(1,8)✓ → 王手 ✓
  //   4. 後手玉 9二(1,8)→9三(2,8) 逃げ
  //      (8二(1,7)が動いたので(1,7)空き、8三(2,7)=金が動いたか? 3手で金(1,7)→?
  //      3手: 金 8二(1,7)は(1,7)にいてstep(0,1)=(1,8)=後手玉に王手 → 金は(1,7)のまま王手をかけている)
  //      (9三(2,8)=金(2,8)?→ 先手金 9三(2,8)がいる → 後手玉は9三に行けない)
  //      → 先手金 9三 → 後手玉9三に逃げれない → 8三(2,7)への逃げ検討
  //        龍(0,6)の縦効き下(1,6),(2,6)... → (2,7)=8三は縦ではなく横 → 龍の横効き(0,6)→... (0,7)先手金(0,7)がいる → 横には(0,7)まで
  //        → 8三(2,7): 龍の効きなし → 金(1,7)の効き(2,7)=step(1,0)=(2,7)✓ ×
  //      → 詰み ✓ (4手で終わってしまう → 3手詰めになる)
  //      → 後手玉9二の逃げ先に8三も金の効き内なので3手詰め
  //   → 1手増やすために初手を調整: 龍を遠くから持ってくる
  //
  //   1. 龍 7三(2,6)→9三(2,8)? → 先手金9三とぶつかる
  //   → 先手金を9四(3,8)に変更
  //
  //   後手玉 9一(0,8)、先手龍 7三(2,6)、先手金 8二(1,7)、先手金 9四(3,8)
  //
  //   手順:
  //   1. 龍 7三(2,6)→9三(2,8) 王手(横)
  //      龍(2,8)の縦効き上: (1,8),(0,8)=9一✓(後手玉) → 王手
  //   2. 後手玉 9一(0,8)→8一(0,7) 逃げ
  //      (9二(1,8)=龍縦効き(1,8)✓ ×)
  //   3. 金 8二(1,7)→8一(0,7) 後手玉取り? → 後手玉が(0,7)=8一に逃げている → 金(1,7)→(0,7): step(-1,0)=(0,7)✓ → 詰み？
  //      後手玉8一の逃げ場:
  //        7一(0,6)=龍(2,8)の斜め効き? 龍は縦横スライド+斜め1マス → (2,8)から斜め(1,7),(1,9)=out,(3,7),(3,9)=out → 7一(0,6)には効かない
  //        → 7一フリー → 3手詰め成立せず(後手玉が7一に逃げられる)
  //      → 先手銀 7一(0,6)追加で封鎖
  //
  //   後手玉 9一(0,8)、先手龍 7三(2,6)、先手金 8二(1,7)、先手金 9四(3,8)、先手銀 7一(0,6)
  //   1. 龍 7三→9三(2,8) 王手
  //   2. 後手玉→8一(0,7) 逃げ (9二=龍縦効き×)
  //   3. 金 8二(1,7)→8一(0,7) 後手玉取り
  //      後手玉8一の逃げ場:
  //        7一(0,6)=先手銀あり ×
  //        9一(0,8)=龍(2,8)縦効き ×
  //        8二(1,7)=金が動くので空き → 龍(2,8)の斜め(1,7)✓ ×
  //        7二(1,6)=銀(0,6)の効き step(1,0)=(1,6)✓? 銀fwd=-1 from(0,6): (1,5),(1,7) → (1,6)には効かない
  //           銀の効き: (-1,-1),(-1,0),(-1,1),(1,-1),(1,1) → (0,6)から: (-1,5)=out,(-1,6)=out,(-1,7)=out,(1,5)=7二✓? (1,5)=7二,(1,7)=8二
  //           → 銀(0,6)の効き(1,5)=7二✓ ×
  //      → 詰み ✓ でもこれは3手詰め
  //
  //   → 5手にするため: 龍の初手王手を1回増やす構成
  //   後手玉 9一(0,8)、先手龍 5三(row2,col4)、先手金 8二(1,7)、先手金 9四(3,8)、先手銀 7一(0,6)
  //
  //   手順:
  //   1. 龍 5三(2,4)→9三(2,8) 王手(横移動)
  //   2. 後手玉 9一(0,8)→8一(0,7) 逃げ (9二=龍縦効き×)
  //   3. 金 8二(1,7)→8一(0,7) 後手玉取り? → 3手詰め成立
  //   → 後手玉に別の逃げ場を作って5手にする
  //
  //   【決定版⑥】後手玉 9一(0,8)、先手龍 5三(2,4)、先手金 9四(3,8)、先手銀 7一(0,6)
  //
  //   手順:
  //   1. 龍 5三(2,4)→9三(2,8) 王手
  //   2. 後手玉 9一(0,8)→8一(0,7) 逃げ (9二=龍縦×)
  //   3. 龍 9三(2,8)→8三(2,7) 王手? → 龍の横移動(2,8)→(2,7)=8三 → 後手玉(0,7)=8一に効く? 龍(2,7)縦上(1,7),(0,7)=8一✓ → 王手
  //   4. 後手玉 8一(0,7)→7一(0,6) 逃げ? 銀(0,6)がいる → 取れる?後手が先手銀を取る → 合法
  //      後手玉7一(0,6)=先手銀 → 後手玉が銀を取る → 後手玉(0,6)
  //   5. 金 9四(3,8)→8四(3,7)? → 後手玉(0,6)まで遠い → 龍で追うべき
  //      龍 8三(2,7)→7二(1,6) 後手玉(0,6)=7一に効く? 龍(1,6)のstep(-1,0)=(0,6)=7一✓ → 王手
  //      しかし後手玉は銀を取ったので(0,6)にいる。龍(1,6)→後手玉(0,6): 縦1マス✓ → 詰み?
  //      後手玉7一(0,6)の逃げ場:
  //        8一(0,7)=龍(1,6)の斜め(-1,1)=(0,7)✓ ×? → 龍は縦横スライド+斜め1マス → (1,6)から(-1,1)=(0,7)✓ ×
  //        7二(1,6)=龍がいる ×
  //        6一(0,5)=龍(1,6)縦上(0,6)=7一に王手しているが(0,5)への効き? 龍(1,6)から(0,5): step(-1,-1)=(0,5)✓ ×
  //        6二(1,5)=龍(1,6)の横(1,5)✓ ×
  //      → 詰み ✓
  //   これで5手詰め成立 ✓
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);          // 後手玉 9一(0,8)
    b[8][0] = Piece(PieceType.king, true);            // 先手玉 1九(8,0)
    b[2][4] = Piece(PieceType.promotedRook, true);   // 先手龍 5三(2,4)
    b[3][8] = Piece(PieceType.gold, true);            // 先手金 9四(3,8)
    b[0][6] = Piece(PieceType.silver, true);          // 先手銀 7一(0,6)
    list.add(_TsumeProb(
      title: '5手詰め ⑥',
      moves: 5,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 2, fc: 4, tr: 2, tc: 8),  // 龍 5三→9三(王手)
        AMove(fr: 0, fc: 8, tr: 0, tc: 7),  // 後手玉 9一→8一(応手)
        AMove(fr: 2, fc: 8, tr: 2, tc: 7),  // 龍 9三→8三(王手)
        AMove(fr: 0, fc: 7, tr: 0, tc: 6),  // 後手玉 8一→7一(銀取り・応手)
        AMove(fr: 2, fc: 7, tr: 1, tc: 6),  // 龍 8三→7二(詰み)
      ],
      explanation: '龍で横に連続王手して後手玉を端から追い出し、最後に龍が7二に入って詰めます。金が9四から逃げ道を塞いでいます。',
    ));
  }


  // ===== 追加問題 (⑧以降) =====
  _buildExtraProblems(list);

  // 開始局面で後手玉がすでに王手または詰みの問題を除外
  list.retainWhere((p) =>
      !GL.inCheck(p.board, false) &&
      GL.hasLegalMove(p.board, false, p.p2Hand, p.p1Hand));
  return list;
}

/// 追加の詰将棋問題（21問→33問）
void _buildExtraProblems(List<_TsumeProb> list) {
  // ── 1手詰め ⑧ ─────────────────────────────
  // 後手玉9一(0,8), 先手金7二(1,6), 持ち駒:金1
  // 手順: 金8二(1,7)打ち → step(-1,1)=(0,8)=9一✓
  // 逃げ場: 8一→金(1,6)step(-1,1)=(0,7)✓封鎖 / 9二→打った金step(0,1)=(1,8)✓封鎖 / 8二→打った金を取ると金(1,6)step(0,1)=(1,7)✓違法手
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king,  false); // 後手玉 9一
    b[8][0] = Piece(PieceType.king,  true);  // 先手玉 1九
    b[1][6] = Piece(PieceType.gold,  true);  // 先手金 7二
    list.add(_TsumeProb(
      title: '1手詰め ⑧', moves: 1, board: b,
      p1Hand: {PieceType.gold: 1}, p2Hand: {},
      solution: [AMove(fr: -1, fc: -1, tr: 1, tc: 7, drop: PieceType.gold)],
      explanation: '金を8二に打って9一に王手。8一は7二の金が、9二と8二は打った金が封鎖しています。',
    ));
  }

  // ── 1手詰め ⑨ ─────────────────────────────
  // 後手玉1一(0,0), 先手龍3二(1,2), 持ち駒:銀1
  // 手順: 銀1二(1,0)打ち → step(-1,0)=(0,0)=1一✓
  // 逃げ場: 2一→龍step(-1,-1)=(0,1)✓ / 1二→取ると龍slide(0,-1)=(1,1),(1,0)✓違法手 / 2二→龍slide(0,-1)=(1,1)✓
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king,         false); // 後手玉 1一
    b[8][8] = Piece(PieceType.king,         true);  // 先手玉 9九
    b[1][2] = Piece(PieceType.promotedRook, true);  // 先手龍 3二
    list.add(_TsumeProb(
      title: '1手詰め ⑨', moves: 1, board: b,
      p1Hand: {PieceType.silver: 1}, p2Hand: {},
      solution: [AMove(fr: -1, fc: -1, tr: 1, tc: 0, drop: PieceType.silver)],
      explanation: '銀を1二に打って1一に王手。2一は龍の斜め効き、1二は銀を取ると龍の横効き、2二は龍の横効きで封鎖されています。',
    ));
  }

  // ── 1手詰め ⑩ ─────────────────────────────
  // 後手玉1一(0,0), 後手歩1二(1,0), 先手香1四(3,0), 先手角4三(2,3), 先手金2三(2,1)
  // 手順: 角3三(2,2)打ち → slide(-1,-1)=(1,1),(0,0)✓
  // 逃げ場: 1二→後手歩で移動不可 / 2一→既存角slide(-1,-1)=(1,2),(0,1)✓ / 2二→金step(-1,0)=(1,1)✓
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king,   false); // 後手玉 1一
    b[1][0] = Piece(PieceType.pawn,   false); // 後手歩 1二(1二封鎖)
    b[8][8] = Piece(PieceType.king,   true);  // 先手玉 9九
    b[3][0] = Piece(PieceType.lance,  true);  // 先手香 1四(後手歩で止)
    b[2][3] = Piece(PieceType.bishop, true);  // 先手角 4三(2一封鎖)
    b[2][1] = Piece(PieceType.gold,   true);  // 先手金 2三(2二封鎖)
    list.add(_TsumeProb(
      title: '1手詰め ⑩', moves: 1, board: b,
      p1Hand: {PieceType.bishop: 1}, p2Hand: {},
      solution: [AMove(fr: -1, fc: -1, tr: 2, tc: 2, drop: PieceType.bishop)],
      explanation: '角を3三に打って斜めに1一へ王手。2一は既存の角が、2二は金が、1二は後手歩で移動不可のため詰み。',
    ));
  }

  // ── 3手詰め ⑧ ─────────────────────────────
  // 飛成り→後手玉4一逃げ→金打ち詰め
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king,   false); // 後手玉 5一
    b[1][4] = Piece(PieceType.silver, false); // 後手銀 5二(飛縦を止める)
    b[3][4] = Piece(PieceType.rook,   true);  // 先手飛 5四
    b[2][2] = Piece(PieceType.gold,   true);  // 先手金 3三(3二・4二封鎖)
    b[8][8] = Piece(PieceType.king,   true);  // 先手玉 9九
    list.add(_TsumeProb(
      title: '3手詰め ⑧', moves: 3, board: b,
      p1Hand: {PieceType.gold: 1}, p2Hand: {},
      solution: [
        AMove(fr: 3, fc: 4, tr: 1, tc: 4, promote: true), // 飛→5二成(後手銀取り龍) 王手
        AMove(fr: 0, fc: 4, tr: 0, tc: 3),                // 後手玉 5一→4一逃げ
        AMove(fr: -1, fc: -1, tr: 1, tc: 3, drop: PieceType.gold), // 金4二打ち 詰み
      ],
      explanation: '飛が後手銀を取りながら成って龍に。後手玉は4一に逃げるしかなく、金を4二に打って詰み。龍・金の協力が鍵。',
    ));
  }

  // ── 3手詰め ⑨ ─────────────────────────────
  // 角打ち→玉逃げ→飛で追い詰め
  {
    final b = _empty();
    b[0][2] = Piece(PieceType.king,   false); // 後手玉 3一
    b[0][0] = Piece(PieceType.gold,   false); // 後手金 1一(逃げ先)
    b[8][8] = Piece(PieceType.king,   true);  // 先手玉 9九
    b[2][0] = Piece(PieceType.rook,   true);  // 先手飛 1三(縦に1二・1一効く)
    b[2][4] = Piece(PieceType.gold,   true);  // 先手金 5三(4二・5二封鎖)
    b[0][4] = Piece(PieceType.silver, true);  // 先手銀 5一(4一封鎖)
    list.add(_TsumeProb(
      title: '3手詰め ⑨', moves: 3, board: b,
      p1Hand: {PieceType.bishop: 1}, p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 1, tc: 1, drop: PieceType.bishop), // 角2二打ち 王手
        AMove(fr: 0, fc: 2, tr: 0, tc: 1),                            // 後手玉 3一→2一
        AMove(fr: 2, fc: 0, tr: 0, tc: 0),                            // 飛 1三→1一 詰み
      ],
      explanation: '角を2二に打ち3一の後手玉に斜め王手。後手玉は2一に逃げるしかなく、飛を1一に進めて詰み。',
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
    list.add(_TsumeProb(
      title: '3手詰め ⑩', moves: 3, board: b,
      p1Hand: {PieceType.lance: 1}, p2Hand: {},
      solution: [
        AMove(fr: 0, fc: 3, tr: 0, tc: 2),                            // 龍 4一→3一(後手銀取り) 王手
        AMove(fr: 0, fc: 1, tr: 0, tc: 0),                            // 後手玉 2一→1一逃げ
        AMove(fr: -1, fc: -1, tr: 2, tc: 0, drop: PieceType.lance),   // 香 1三打ち 詰み
      ],
      explanation: '龍が後手銀を取りながら2一の後手玉に横王手。玉は1一に逃げるしかなく、香を1三に打って詰み。龍の横効きと香の縦効きの合わせ技。',
    ));
  }


  // ── 9手詰め ① ─────────────────────────────
  // 飛角銀金を使った9手詰め
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king,   false); // 後手玉 1一
    b[0][1] = Piece(PieceType.gold,   false); // 後手金 2一
    b[1][0] = Piece(PieceType.silver, false); // 後手銀 1二
    b[8][8] = Piece(PieceType.king,   true);  // 先手玉 9九
    b[2][2] = Piece(PieceType.gold,   true);  // 先手金 3三
    b[2][0] = Piece(PieceType.lance,  true);  // 先手香 1三
    list.add(_TsumeProb(
      title: '9手詰め ①', moves: 9, board: b,
      p1Hand: {PieceType.rook: 1, PieceType.bishop: 1, PieceType.gold: 1}, p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 1, tc: 1, drop: PieceType.bishop), // 角2二打ち 王手
        AMove(fr: 0, fc: 0, tr: 0, tc: 1),                            // 後手玉1一→2一(後手金取り)
        AMove(fr: -1, fc: -1, tr: 2, tc: 1, drop: PieceType.rook),   // 飛2三打ち 王手
        AMove(fr: 0, fc: 1, tr: 0, tc: 0),                            // 後手玉2一→1一
        AMove(fr: 2, fc: 0, tr: 1, tc: 0),                            // 香 1三→1二(後手銀取り) 王手
        AMove(fr: 0, fc: 0, tr: 0, tc: 1),                            // 後手玉1一→2一
        AMove(fr: 2, fc: 2, tr: 1, tc: 1),                            // 金 3三→2二 王手
        AMove(fr: 0, fc: 1, tr: 0, tc: 0),                            // 後手玉2一→1一
        AMove(fr: 2, fc: 1, tr: 0, tc: 1),                            // 飛 2三→2一 詰み
      ],
      explanation: '角打ちから始まる9手詰め。飛・角・金・香の総力戦で後手玉を1筋コーナーに封じ込める長手数の詰将棋。',
    ));
  }

  // ── 1手詰め ⑪ ─────────────────────────────
  // 後手玉9一(0,8), 先手飛9二(1,8), 先手金8一(0,7)
  // 手順: 飛成り9二→9一(0,8) 王手 ... 龍で詰み
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);  // 後手玉 9一
    b[8][0] = Piece(PieceType.king, true);   // 先手玉 1九
    b[1][8] = Piece(PieceType.rook, true);   // 先手飛 9二
    b[0][7] = Piece(PieceType.gold, true);   // 先手金 8一(8一封鎖)
    list.add(_TsumeProb(
      title: '1手詰め ⑪', moves: 1, board: b,
      p1Hand: {}, p2Hand: {},
      solution: [AMove(fr: 1, fc: 8, tr: 0, tc: 8, promote: true)], // 飛→9一成
      explanation: '飛車を9二から9一に進めて成り、龍王にして後手玉に王手。8一に金があり詰み。',
    ));
  }

  // ── 1手詰め ⑫ ─────────────────────────────
  // 後手玉5一(0,4), 先手馬4二(1,3), 先手金6一(0,5)
  // 手順: 馬 4二→5二(1,4) 王手 後手玉逃げ場なし
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);           // 後手玉 5一
    b[8][4] = Piece(PieceType.king, true);            // 先手玉 5九
    b[1][3] = Piece(PieceType.promotedBishop, true);  // 先手馬 4二
    b[0][5] = Piece(PieceType.gold, true);            // 先手金 6一(6一封鎖)
    b[0][3] = Piece(PieceType.gold, true);            // 先手金 4一(4一封鎖)
    list.add(_TsumeProb(
      title: '1手詰め ⑫', moves: 1, board: b,
      p1Hand: {}, p2Hand: {},
      solution: [AMove(fr: 1, fc: 3, tr: 1, tc: 4)], // 馬 4二→5二 王手
      explanation: '馬を5二に進めて5一の後手玉に斜め王手。4一・6一は金で封鎖され詰み。',
    ));
  }

  // ── 3手詰め ⑪ ─────────────────────────────
  // 先手金打ち→玉逃げ→金打ち詰め
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);  // 後手玉 1一
    b[8][8] = Piece(PieceType.king, true);   // 先手玉 9九
    b[0][2] = Piece(PieceType.silver, true); // 先手銀 3一(2一封鎖)
    list.add(_TsumeProb(
      title: '3手詰め ⑪', moves: 3, board: b,
      p1Hand: {PieceType.gold: 2}, p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 1, tc: 1, drop: PieceType.gold), // 金2二打ち 王手
        AMove(fr: 0, fc: 0, tr: 0, tc: 1),                          // 玉1一→2一
        AMove(fr: -1, fc: -1, tr: 0, tc: 0, drop: PieceType.gold), // 金1一打ち 詰み
      ],
      explanation: '金を2二に打って1一の後手玉に王手。玉は2一に逃げるが、1一に金を打って詰み。',
    ));
  }

  // ── 3手詰め ⑫ ─────────────────────────────
  // 桂打ち王手→玉9二逃げ→金8二打ち詰め
  // 後手玉 9一(0,8)、先手龍 7三(2,6)、先手金 7二(1,6)、先手金 9四(3,8)
  // 手順: 桂8三打ち(9一に効く)→後手玉9二→金7二→8二(横で王手+詰み)
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king,         false); // 後手玉 9一(0,8)
    b[8][0] = Piece(PieceType.king,         true);  // 先手玉 1九(8,0)
    b[2][6] = Piece(PieceType.promotedRook, true);  // 先手龍 7三(2,6)
    b[1][6] = Piece(PieceType.gold,         true);  // 先手金 7二(1,6)
    b[3][8] = Piece(PieceType.gold,         true);  // 先手金 9四(3,8) ← 9三逃げ封鎖
    list.add(_TsumeProb(
      title: '3手詰め ⑫', moves: 3, board: b,
      p1Hand: {PieceType.knight: 1}, p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 2, tc: 7, drop: PieceType.knight), // 桂8三打ち(9一に跳ね王手)
        AMove(fr: 0, fc: 8, tr: 1, tc: 8),                            // 後手玉 9一→9二(唯一の逃げ)
        AMove(fr: 1, fc: 6, tr: 1, tc: 7),                            // 金 7二→8二(横で王手=詰み)
      ],
      explanation: '桂を8三に打って9一の後手玉に王手。9二に逃げるしかないところを金が8二に寄って詰み。龍と金が逃げ道を完全封鎖します。',
    ));
  }

  // ── 5手詰め ⑦ ─────────────────────────────
  // 飛打ち→取り→龍成り→逃げ→金打ち
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king,   false); // 後手玉 1一
    b[1][0] = Piece(PieceType.gold,   false); // 後手金 1二(盾)
    b[0][1] = Piece(PieceType.silver, false); // 後手銀 2一(横逃げ封鎖)
    b[8][8] = Piece(PieceType.king,   true);  // 先手玉 9九
    b[0][2] = Piece(PieceType.gold,   true);  // 先手金 3一(2一取りで2一封鎖)
    list.add(_TsumeProb(
      title: '5手詰め ⑦', moves: 5, board: b,
      p1Hand: {PieceType.rook: 1, PieceType.gold: 1}, p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 2, tc: 0, drop: PieceType.rook),  // 飛1三打ち 王手
        AMove(fr: 1, fc: 0, tr: 2, tc: 0),                           // 後手金 1二→1三(飛取り)
        AMove(fr: -1, fc: -1, tr: 1, tc: 0, drop: PieceType.rook),  // 飛1二打ち 王手
        AMove(fr: 0, fc: 0, tr: 1, tc: 0),                           // 後手玉 1一→1二(飛取り)
        AMove(fr: -1, fc: -1, tr: 0, tc: 0, drop: PieceType.gold),  // 金1一打ち 詰み
      ],
      explanation: '飛打ちで後手金を誘い出してから再度飛打ち。後手玉を1二に引き上げて1一に金を打ち詰み。捨て駒が鍵。',
    ));
  }

  // ── 5手詰め ⑧ ─────────────────────────────
  // 角打ち王手→玉逃げ→金打ち→玉逃げ→飛成り詰め
  {
    final b = _empty();
    b[0][2] = Piece(PieceType.king,   false); // 後手玉 3一
    b[8][8] = Piece(PieceType.king,   true);  // 先手玉 9九
    b[1][1] = Piece(PieceType.rook,   true);  // 先手飛 2二(横効き)
    b[0][0] = Piece(PieceType.silver, true);  // 先手銀 1一(1一封鎖)
    list.add(_TsumeProb(
      title: '5手詰め ⑧', moves: 5, board: b,
      p1Hand: {PieceType.bishop: 1, PieceType.gold: 1}, p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 1, tc: 3, drop: PieceType.bishop), // 角4二打ち 王手(斜め3一に効く)
        AMove(fr: 0, fc: 2, tr: 0, tc: 1),                            // 後手玉 3一→2一
        AMove(fr: -1, fc: -1, tr: 1, tc: 0, drop: PieceType.gold),   // 金1二打ち 王手
        AMove(fr: 0, fc: 1, tr: 0, tc: 2),                            // 後手玉 2一→3一
        AMove(fr: 1, fc: 1, tr: 0, tc: 1, promote: true),             // 飛 2二→2一成(龍) 詰み
      ],
      explanation: '角打ちで後手玉を2一に誘い、金打ちで3一に戻らせる。最後に飛を成って2一に龍を作り詰み。',
    ));
  }

  // ── 1手詰め ⑬ ─────────────────────────────
  // 後手玉3一(0,2), 持ち駒金、先手銀2二(1,1), 先手飛4二(1,3)
  {
    final b = _empty();
    b[0][2] = Piece(PieceType.king,   false); // 後手玉 3一
    b[8][8] = Piece(PieceType.king,   true);  // 先手玉 9九
    b[1][1] = Piece(PieceType.silver, true);  // 先手銀 2二(2二→3一の王手封鎖+2一封鎖)
    b[1][3] = Piece(PieceType.rook,   true);  // 先手飛 4二(縦4一・横効き)
    list.add(_TsumeProb(
      title: '1手詰め ⑬', moves: 1, board: b,
      p1Hand: {PieceType.gold: 1}, p2Hand: {},
      solution: [AMove(fr: -1, fc: -1, tr: 0, tc: 1, drop: PieceType.gold)], // 金2一打ち
      explanation: '金を2一に打って3一の後手玉に王手。4一は飛の縦効き、4二は飛、2二は銀、2一は今打った金で詰み。',
    ));
  }

  // ── 3手詰め ⑬ ─────────────────────────────
  // 角で王手→逃げ→金打ち詰め（3筋玉の詰め）
  {
    final b = _empty();
    b[0][6] = Piece(PieceType.king,   false); // 後手玉 7一
    b[8][8] = Piece(PieceType.king,   true);  // 先手玉 9九
    b[2][8] = Piece(PieceType.bishop, true);  // 先手角 9三(斜め7一に効く)
    b[0][5] = Piece(PieceType.gold,   true);  // 先手金 6一(6一封鎖)
    b[0][7] = Piece(PieceType.gold,   true);  // 先手金 8一(8一封鎖)
    list.add(_TsumeProb(
      title: '3手詰め ⑬', moves: 3, board: b,
      p1Hand: {PieceType.gold: 1}, p2Hand: {},
      solution: [
        AMove(fr: 2, fc: 8, tr: 1, tc: 7),                           // 角 9三→8二 王手(斜め7一に効く)
        AMove(fr: 0, fc: 6, tr: 0, tc: 5),                           // 後手玉 7一→6一(先手金取り)
        AMove(fr: -1, fc: -1, tr: 0, tc: 6, drop: PieceType.gold),  // 金7一打ち 詰み
      ],
      explanation: '角を8二に進めて7一の後手玉に斜め王手。玉は6一に逃げるが、7一に金を打って詰み。金の捨て手が伏線。',
    ));
  }

  // ── 5手詰め ⑨ ─────────────────────────────
  // 銀捨て→龍引き→銀打ち→逃げ→金打ち詰め
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king,         false); // 後手玉 1一
    b[1][1] = Piece(PieceType.silver,       false); // 後手銀 2二(盾)
    b[8][8] = Piece(PieceType.king,         true);  // 先手玉 9九
    b[2][0] = Piece(PieceType.promotedRook, true);  // 先手龍 1三
    b[0][2] = Piece(PieceType.gold,         true);  // 先手金 3一(2一封鎖)
    list.add(_TsumeProb(
      title: '5手詰め ⑨', moves: 5, board: b,
      p1Hand: {PieceType.silver: 1, PieceType.gold: 1}, p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 1, tc: 0, drop: PieceType.silver), // 銀1二打ち 王手
        AMove(fr: 1, fc: 1, tr: 1, tc: 0),                            // 後手銀 2二→1二(先手銀取り)
        AMove(fr: 2, fc: 0, tr: 1, tc: 0),                            // 龍 1三→1二(後手銀取り) 王手
        AMove(fr: 0, fc: 0, tr: 0, tc: 1),                            // 後手玉 1一→2一
        AMove(fr: -1, fc: -1, tr: 1, tc: 1, drop: PieceType.gold),   // 金2二打ち 詰み
      ],
      explanation: '銀を捨てて後手銀を1二へ誘い出し、龍で取りながら王手。後手玉は2一に逃げるが金打ちで詰み。',
    ));
  }


  // ── 1手詰め ⑭ ─────────────────────────────
  // 後手玉9九(8,8), 先手金8八(7,7), 先手飛1九(8,0)
  {
    final b = _empty();
    b[8][8] = Piece(PieceType.king,  false); // 後手玉 9九
    b[0][0] = Piece(PieceType.king,  true);  // 先手玉 1一
    b[7][7] = Piece(PieceType.gold,  true);  // 先手金 8八(斜め封鎖)
    b[8][0] = Piece(PieceType.rook,  true);  // 先手飛 1九(横王手)
    b[7][8] = Piece(PieceType.silver,true);  // 先手銀 9八(8九封鎖)
    list.add(_TsumeProb(
      title: '1手詰め ⑭', moves: 1, board: b,
      p1Hand: {PieceType.gold: 1}, p2Hand: {},
      solution: [AMove(fr: -1, fc: -1, tr: 7, tc: 8, drop: PieceType.gold)], // 金9八打ち
      explanation: '金を9八に打って9九の後手玉に王手。8八は金、9八は今打った金、8九は銀で封鎖され詰み。',
    ));
  }

  // ── 3手詰め ⑭ ─────────────────────────────
  // と金+金の連携
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king,          false); // 後手玉 5一
    b[8][4] = Piece(PieceType.king,          true);  // 先手玉 5九
    b[1][4] = Piece(PieceType.promotedPawn,  true);  // 先手と 5二(直下で王手可)
    b[0][5] = Piece(PieceType.gold,          true);  // 先手金 6一(6一封鎖)
    list.add(_TsumeProb(
      title: '3手詰め ⑭', moves: 3, board: b,
      p1Hand: {PieceType.gold: 1}, p2Hand: {},
      solution: [
        AMove(fr: 1, fc: 4, tr: 0, tc: 4),                          // と 5二→5一 王手
        AMove(fr: 0, fc: 4, tr: 0, tc: 3),                          // 後手玉 5一→4一
        AMove(fr: -1, fc: -1, tr: 1, tc: 3, drop: PieceType.gold), // 金4二打ち 詰み
      ],
      explanation: 'と金で5一に王手して後手玉を4一に誘い、4二に金を打って詰み。と金と金の連携。',
    ));
  }
}

// ===== タイムアタック画面 =====

enum _TaMode { threeMin, perProblem }
enum _TaDiff { mix, one, three, five }

class TsumeTimeAttackScreen extends StatefulWidget {
  const TsumeTimeAttackScreen({super.key});

  @override
  State<TsumeTimeAttackScreen> createState() => _TsumeTimeAttackScreenState();
}

class _TsumeTimeAttackScreenState extends State<TsumeTimeAttackScreen> {
  static const _bg = AppTheme.bg;
  static const _totalSec = 180;
  static const _perProbSec = 30;
  static const _prefBest3 = 'ta_best_3min';
  static const _prefBestPp = 'ta_best_perproblem';

  _TaMode _mode = _TaMode.threeMin;
  _TaDiff _diff = _TaDiff.mix;

  List<(int, _TsumeProb)> _pool = [];

  int _score = 0;
  int _skipped = 0;
  int _remaining = _totalSec;
  int _problemRemaining = _perProbSec;
  Timer? _sessionTimer;
  Timer? _problemTimer;
  bool _started = false;
  bool _finished = false;
  int _currentIdx = 0;
  final _random = _Rng();

  int _best3min = 0;
  int _bestPerproblem = 0;

  @override
  void initState() {
    super.initState();
    _buildPool();
    _loadBest();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _problemTimer?.cancel();
    super.dispose();
  }

  void _buildPool() {
    final all = <(int, _TsumeProb)>[];
    for (int i = 0; i < _problems.length; i++) {
      final p = _problems[i];
      if (GL.inCheck(p.board, false)) continue;
      final ok = switch (_diff) {
        _TaDiff.mix   => true,
        _TaDiff.one   => p.moves == 1,
        _TaDiff.three => p.moves == 3,
        _TaDiff.five  => p.moves >= 5,
      };
      if (ok) all.add((i, p));
    }
    _pool = all;
    if (_pool.isNotEmpty) _currentIdx = _random.nextInt(_pool.length);
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _best3min = prefs.getInt(_prefBest3) ?? 0;
      _bestPerproblem = prefs.getInt(_prefBestPp) ?? 0;
    });
  }

  Future<void> _saveBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (_mode == _TaMode.threeMin && _score > _best3min) {
      await prefs.setInt(_prefBest3, _score);
      if (mounted) setState(() => _best3min = _score);
    } else if (_mode == _TaMode.perProblem && _score > _bestPerproblem) {
      await prefs.setInt(_prefBestPp, _score);
      if (mounted) setState(() => _bestPerproblem = _score);
    }
  }

  void _start() {
    _sessionTimer?.cancel();
    _problemTimer?.cancel();
    setState(() {
      _started = true;
      _remaining = _totalSec;
      _problemRemaining = _perProbSec;
    });
    if (_mode == _TaMode.threeMin) {
      _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _remaining--;
          if (_remaining <= 0) {
            _remaining = 0;
            _sessionTimer?.cancel();
            _finished = true;
            _saveBest();
          }
        });
      });
    } else {
      _startProblemTimer();
    }
  }

  void _startProblemTimer() {
    _problemTimer?.cancel();
    setState(() => _problemRemaining = _perProbSec);
    _problemTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _problemRemaining--;
        if (_problemRemaining <= 0) {
          _problemRemaining = 0;
          _problemTimer?.cancel();
          _skipped++;
          if (_skipped >= 3) {
            _finished = true;
            _saveBest();
          } else {
            _nextProblem();
          }
        }
      });
    });
  }

  void _nextProblem() {
    if (_pool.isEmpty) return;
    setState(() => _currentIdx = _random.nextInt(_pool.length));
    if (_mode == _TaMode.perProblem) _startProblemTimer();
  }

  void _onSolved() {
    _problemTimer?.cancel();
    setState(() => _score++);
    _nextProblem();
  }

  String _fmtTime(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_finished) return _buildResult();
    if (!_started) return _buildStartScreen();

    final timerColor = _mode == _TaMode.threeMin
        ? (_remaining <= 30 ? Colors.red : _remaining <= 60 ? Colors.orange : AppTheme.accent)
        : (_problemRemaining <= 10 ? Colors.red : _problemRemaining <= 20 ? Colors.orange : Colors.green);

    final (origIdx, prob) = _pool[_currentIdx];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('タイムアタック', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_mode == _TaMode.perProblem)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                ...List.generate(3, (i) => Icon(
                  i < (3 - _skipped) ? Icons.favorite : Icons.favorite_border,
                  color: i < (3 - _skipped) ? Colors.redAccent : Colors.grey.shade700,
                  size: 20,
                )),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.timer, color: timerColor, size: 18),
              const SizedBox(width: 4),
              Text(
                _mode == _TaMode.threeMin ? _fmtTime(_remaining) : '$_problemRemaining秒',
                style: TextStyle(color: timerColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ]),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(40),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withAlpha(120)),
            ),
            child: Text(
              '$_score問',
              style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_mode == _TaMode.perProblem) _buildProblemTimerBar(),
          Expanded(
            child: _SolvePage(
              key: ValueKey((_currentIdx, _score, _skipped)),
              prob: prob,
              index: origIdx,
              timeAttackMode: true,
              onSolvedInTimeAttack: _onSolved,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemTimerBar() {
    final fraction = (_problemRemaining / _perProbSec).clamp(0.0, 1.0);
    final color = fraction > 0.5 ? Colors.green : fraction > 0.25 ? Colors.orange : Colors.red;
    return SizedBox(
      height: 6,
      child: LayoutBuilder(builder: (_, c) {
        return Stack(children: [
          Container(color: AppTheme.surface),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: c.maxWidth * fraction,
            color: color,
          ),
        ]);
      }),
    );
  }

  Widget _buildStartScreen() {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('タイムアタック', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Center(
              child: Icon(Icons.timer, color: AppTheme.accent, size: 64),
            ),
            const SizedBox(height: 20),

            // Mode
            const Text('モード', style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _TaModeButton(
                label: '3分チャレンジ',
                sub: '3分間で何問解けるか',
                icon: Icons.hourglass_bottom,
                selected: _mode == _TaMode.threeMin,
                onTap: () => setState(() { _mode = _TaMode.threeMin; }),
              )),
              const SizedBox(width: 10),
              Expanded(child: _TaModeButton(
                label: '1問30秒',
                sub: 'ミス3回でゲームオーバー',
                icon: Icons.flash_on,
                selected: _mode == _TaMode.perProblem,
                onTap: () => setState(() { _mode = _TaMode.perProblem; }),
              )),
            ]),
            const SizedBox(height: 20),

            // Difficulty
            const Text('難易度', style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              _TaDiffButton(label: 'ミックス', selected: _diff == _TaDiff.mix,
                onTap: () => setState(() { _diff = _TaDiff.mix; _buildPool(); })),
              const SizedBox(width: 8),
              _TaDiffButton(label: '1手詰め', selected: _diff == _TaDiff.one,
                onTap: () => setState(() { _diff = _TaDiff.one; _buildPool(); })),
              const SizedBox(width: 8),
              _TaDiffButton(label: '3手詰め', selected: _diff == _TaDiff.three,
                onTap: () => setState(() { _diff = _TaDiff.three; _buildPool(); })),
              const SizedBox(width: 8),
              _TaDiffButton(label: '5手+', selected: _diff == _TaDiff.five,
                onTap: () => setState(() { _diff = _TaDiff.five; _buildPool(); })),
            ]),
            const SizedBox(height: 6),
            Text('問題数: ${_pool.length}問', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 20),

            // Best scores
            if (_best3min > 0 || _bestPerproblem > 0)
              Wrap(spacing: 10, runSpacing: 8, children: [
                if (_best3min > 0)
                  _TaBestChip(label: '3分ベスト', score: _best3min),
                if (_bestPerproblem > 0)
                  _TaBestChip(label: '30秒ベスト', score: _bestPerproblem),
              ]),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pool.isEmpty ? null : _start,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  _pool.isEmpty ? '問題がありません' : 'スタート',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final isNewBest = (_mode == _TaMode.threeMin && _score > 0 && _score >= _best3min) ||
        (_mode == _TaMode.perProblem && _score > 0 && _score >= _bestPerproblem);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _score >= 15 ? '🏆' : _score >= 8 ? '🥈' : _score >= 3 ? '🎯' : '😤',
                  style: const TextStyle(fontSize: 72),
                ),
                const SizedBox(height: 16),
                const Text('終了！', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                if (isNewBest) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(30),
                      border: Border.all(color: Colors.amber),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('🌟 新記録！', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    const Text('正解数', style: TextStyle(color: Colors.white54, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      '$_score問',
                      style: const TextStyle(color: Colors.amber, fontSize: 52, fontWeight: FontWeight.bold),
                    ),
                    if (_mode == _TaMode.perProblem && _skipped > 0) ...[
                      const SizedBox(height: 4),
                      Text('タイムアウト: $_skipped回', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _score >= 15 ? '驚異的！詰将棋マスターです'
                        : _score >= 8 ? '素晴らしい！将棋の達人です'
                        : _score >= 3 ? 'よくできました！'
                        : 'もう少し！次は速く解けるよ',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ]),
                ),
                const SizedBox(height: 32),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      _sessionTimer?.cancel();
                      _problemTimer?.cancel();
                      setState(() {
                        _score = 0;
                        _skipped = 0;
                        _remaining = _totalSec;
                        _problemRemaining = _perProbSec;
                        _started = false;
                        _finished = false;
                        _buildPool();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('もう一度'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('戻る'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaModeButton extends StatelessWidget {
  final String label, sub;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TaModeButton({required this.label, required this.sub, required this.icon, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent.withAlpha(40) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppTheme.accent : Colors.white24, width: selected ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? AppTheme.accent : Colors.white54, size: 28),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _TaDiffButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TaDiffButton({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.amber.withAlpha(30) : AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? Colors.amber : Colors.white24),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.amber : Colors.white54,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _TaBestChip extends StatelessWidget {
  final String label;
  final int score;
  const _TaBestChip({required this.label, required this.score});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(20),
        border: Border.all(color: Colors.amber.withAlpha(100)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.emoji_events, color: Colors.amber, size: 14),
        const SizedBox(width: 4),
        Text('$label: $score問', style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ランダム整数ヘルパー（dart:math Random のラッパー）
class _Rng {
  final _r = Random();
  int nextInt(int max) => _r.nextInt(max);
}

// ===== デイリー詰将棋（Wordle式）=====

class DailyTsumeScreen extends StatefulWidget {
  const DailyTsumeScreen({super.key});
  @override
  State<DailyTsumeScreen> createState() => _DailyTsumeScreenState();
}

class _DailyTsumeScreenState extends State<DailyTsumeScreen> {
  static const _bg = AppTheme.bg;
  static const _maxAttempts = 999;  // 無制限（実質上限）

  late final _TsumeProb _prob;
  late final int _probIdx;
  late final String _dateKey;

  late List<String> _attempts;
  int _currentAttempt = 0;
  bool _done = false;
  bool _solved = false;
  int _solveKey = 0;
  bool _loaded = false;
  bool _freezeAvailable = true;
  bool _streakFrozenToday = false;

  @override
  void initState() {
    super.initState();
    _attempts = List<String>.filled(_maxAttempts, 'pending');
    final now = DateTime.now();
    _dateKey = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    // 日付シードで全ユーザー共通の問題を選択
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final valid = <(int, _TsumeProb)>[];
    for (int i = 0; i < _problems.length; i++) {
      if (!GL.inCheck(_problems[i].board, false)) valid.add((i, _problems[i]));
    }
    final idx = seed % valid.length;
    final picked = valid[idx];
    _probIdx = picked.$1;
    _prob = picked.$2;

    _loadState();
  }

  String get _prefBase => 'daily_wordle_$_dateKey';

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }

  String get _weekKey {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2,'0')}-${monday.day.toString().padLeft(2,'0')}';
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('${_prefBase}_attempts');
    final savedSolved = prefs.getBool('${_prefBase}_solved') ?? false;
    final lastFreezeDate = prefs.getString('tsume_freeze_used_date') ?? '';
    final frozenToday = prefs.getString('tsume_frozen_date') == _todayKey;
    if (!mounted) return;
    setState(() {
      if (saved != null && saved.length == _maxAttempts) {
        _attempts = saved;
      }
      _solved = savedSolved;
      final pending = _attempts.indexOf('pending');
      _currentAttempt = pending == -1 ? _maxAttempts : pending;
      _done = _solved || _currentAttempt >= _maxAttempts;
      _loaded = true;
      _freezeAvailable = lastFreezeDate != _weekKey;
      _streakFrozenToday = frozenToday;
    });
  }

  Future<void> _useFreeze() async {
    final prefs = await SharedPreferences.getInstance();
    final sub = PurchaseService.isPremium;
    if (!_freezeAvailable && !sub) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('今週のフリーズは使用済みです（サブスクで無制限）')),
        );
      }
      return;
    }
    final today = _todayKey;
    await prefs.setString('tsume_frozen_date', today);
    if (!sub) {
      await prefs.setString('tsume_freeze_used_date', _weekKey);
    }
    if (mounted) {
      setState(() {
        _streakFrozenToday = true;
        if (!sub) _freezeAvailable = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ストリークを保護しました ❄️')),
        );
      }
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('${_prefBase}_attempts', _attempts);
    await prefs.setBool('${_prefBase}_solved', _solved);
  }

  void _onSolved() {
    if (!mounted) return;
    setState(() {
      if (_currentAttempt < _maxAttempts) _attempts[_currentAttempt] = 'solved';
      _solved = true;
      _done = true;
    });
    _saveState();
  }

  void _onReset() {
    if (_done || !mounted) return;
    setState(() {
      if (_currentAttempt < _maxAttempts) _attempts[_currentAttempt] = 'failed';
      _currentAttempt++;
      if (_currentAttempt >= _maxAttempts) _done = true;
      _solveKey++;
    });
    _saveState();
  }

  String _buildShareText() {
    final now = DateTime.now();
    final dateStr = '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    final emojis = _attempts.map((a) => a == 'solved' ? '🟩' : a == 'failed' ? '🟥' : '⬜').join('');
    return '効棋 デイリー詰将棋 $dateStr\n$emojis ${_prob.moves}手詰め';
  }

  Widget _buildAttemptBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_maxAttempts, (i) {
        final status = _attempts[i];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: status == 'solved'
                ? Colors.green.shade700
                : status == 'failed'
                    ? Colors.red.shade800
                    : i == _currentAttempt
                        ? AppTheme.surface
                        : Colors.grey.shade900,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: i == _currentAttempt && !_done
                  ? Colors.amber
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              status == 'solved'
                  ? '🟩'
                  : status == 'failed'
                      ? '🟥'
                      : '${i + 1}',
              style: TextStyle(
                fontSize: status == 'pending' ? 16 : 20,
                color: Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('デイリー詰将棋', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _done
              ? _buildResult()
              : _buildGame(),
    );
  }

  Widget _buildGame() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: const Color(0xFF0F1729),
          child: Column(
            children: [
              _buildAttemptBar(),
              const SizedBox(height: 8),
              Text(
                '残り ${_maxAttempts - _currentAttempt} 回',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: _SolvePage(
            key: ValueKey(_solveKey),
            prob: _prob,
            index: _probIdx,
            onSolvedCallback: _onSolved,
            onResetRequested: _onReset,
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final shareText = _buildShareText();
    final solveAttempt = _attempts.indexWhere((a) => a == 'solved');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_solved ? '🎉' : '😔', style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            Text(
              _solved ? '正解！' : '残念…',
              style: TextStyle(
                color: _solved ? Colors.amber : Colors.white70,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _solved
                  ? '${solveAttempt + 1}回目で解けました！'
                  : '明日また挑戦してください',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _attempts
                  .map((a) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          a == 'solved' ? '🟩' : a == 'failed' ? '🟥' : '⬜',
                          style: const TextStyle(fontSize: 32),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              '${_prob.moves}手詰め',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 28),
            if (_solved)
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: shareText));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('クリップボードにコピーしました'),
                        backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('結果をコピー'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _useFreeze,
                icon: const Icon(Icons.shield),
                label: const Text('ストリーク保護'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('戻る'),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== ローグライト タイムアタック =====

class TsumeRogueliteScreen extends StatefulWidget {
  const TsumeRogueliteScreen({super.key});
  @override
  State<TsumeRogueliteScreen> createState() => _TsumeRogueliteScreenState();
}

class _TsumeRogueliteScreenState extends State<TsumeRogueliteScreen> {
  static const _bg = AppTheme.bg;
  static const _maxLives = 3;
  static const _prefBestKey = 'roguelite_best_score';

  late final List<(int, _TsumeProb)> _sortedProblems;
  int _lives = _maxLives;
  int _score = 0;
  int _currentProbIdx = 0;
  bool _finished = false;
  bool _started = false;
  int _bestScore = 0;
  int _solveKey = 0;

  @override
  void initState() {
    super.initState();
    final valid = <(int, _TsumeProb)>[];
    for (int i = 0; i < _problems.length; i++) {
      if (!GL.inCheck(_problems[i].board, false)) valid.add((i, _problems[i]));
    }
    valid.sort((a, b) => a.$2.moves.compareTo(b.$2.moves));
    _sortedProblems = valid;
    _loadBest();
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _bestScore = prefs.getInt(_prefBestKey) ?? 0);
  }

  Future<void> _saveBest() async {
    if (_score > _bestScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefBestKey, _score);
      if (mounted) setState(() => _bestScore = _score);
    }
  }

  void _onSolved() {
    if (!mounted) return;
    if (_currentProbIdx + 1 >= _sortedProblems.length) {
      setState(() { _score++; _finished = true; });
    } else {
      setState(() { _score++; _currentProbIdx++; _solveKey++; });
    }
    _saveBest();
  }

  void _onWrongAttempt() {
    if (!mounted) return;
    setState(() {
      _lives--;
      _solveKey++;
      if (_lives <= 0) _finished = true;
    });
    if (_lives <= 0) _saveBest();
  }

  Widget _buildLivesBar() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(_maxLives, (i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            i < _lives ? Icons.favorite : Icons.favorite_border,
            color: i < _lives ? Colors.redAccent : Colors.grey.shade700,
            size: 22,
          ),
        )),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return _buildResult();
    if (!_started) return _buildStart();

    final (origIdx, prob) = _sortedProblems[_currentProbIdx];
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('ローグライト', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: _buildLivesBar(),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(40),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withAlpha(120)),
            ),
            child: Text(
              '$_score問',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _SolvePage(
        key: ValueKey(_solveKey),
        prob: prob,
        index: origIdx,
        onSolvedCallback: _onSolved,
        onResetRequested: _onWrongAttempt,
      ),
    );
  }

  Widget _buildStart() {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('ローグライト', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('❤️❤️❤️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 20),
              const Text(
                'ローグライト',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'ライフ3つで詰将棋に挑戦！\n間違えるとライフが減る。\n難易度は1手詰めから徐々に上がる。',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              if (_bestScore > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withAlpha(80)),
                  ),
                  child: Text(
                    '自己ベスト: $_bestScore問',
                    style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => setState(() => _started = true),
                icon: const Icon(Icons.play_arrow),
                label: const Text('スタート', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    final isNewBest = _score > 0 && _score >= _bestScore;
    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _lives > 0 ? '🏆' : _score >= 5 ? '⚔️' : '💀',
              style: const TextStyle(fontSize: 72),
            ),
            const SizedBox(height: 16),
            Text(
              _lives > 0 ? '全問クリア！' : 'ゲームオーバー',
              style: TextStyle(
                color: _lives > 0 ? Colors.amber : Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('正解数', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    '$_score問',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isNewBest) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(40),
                        border: Border.all(color: Colors.amber),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('🏆 自己ベスト更新！', style: TextStyle(color: Colors.amber, fontSize: 12)),
                    ),
                  ] else if (_bestScore > 0) ...[
                    const SizedBox(height: 4),
                    Text('自己ベスト: $_bestScore問', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _lives = _maxLives;
                      _score = 0;
                      _currentProbIdx = 0;
                      _finished = false;
                      _started = true;
                      _solveKey++;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('もう一度'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('戻る'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===== 問題一覧画面 =====

class TsumeScreen extends StatefulWidget {
  const TsumeScreen({super.key});

  @override
  State<TsumeScreen> createState() => _TsumeScreenState();
}

class _TsumeScreenState extends State<TsumeScreen>
    with SingleTickerProviderStateMixin {
  static const _bg = AppTheme.bg;
  static const _card = AppTheme.surface;

  // 0=全て, 1=1手, 3=3手, 5=5手, 7=7手, 9=9手
  int _filterMoves = 0;
  late TabController _tabController;

  List<bool> _cleared = [];

  // ── デイリー＆ストリーク ──
  int _streak = 0;
  bool _dailySolved = false;
  bool _freezeAvailable = true;  // 週1回無料フリーズ使用可
  bool _streakFrozenToday = false;
  int get _dailyIdx {
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    return seed % _problems.length;
  }
  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        switch (_tabController.index) {
          case 0: _filterMoves = 0; break;
          case 1: _filterMoves = 1; break;
          case 2: _filterMoves = 3; break;
          case 3: _filterMoves = 5; break;
          case 4: _filterMoves = 7; break;
          case 5: _filterMoves = 9; break;
        }
      });
    });
    _cleared = List.filled(_problems.length, false);
    _loadCleared();
    _loadStreak();
    // 外部JSON問題を非同期ロード（初回のみ）
    _loadExtraProblems().then((_) {
      if (mounted) {
        setState(() {
          // 外部問題追加後に _cleared を拡張
          if (_cleared.length < _problems.length) {
            _cleared = List.filled(_problems.length, false);
            _loadCleared();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── タイムランキング表示 ──
  Future<void> _showTimeRanking() async {
    final prefs = await SharedPreferences.getInstance();
    // 解決済み問題のベストタイムを収集
    final entries = <({String title, int moves, int bestSec, int idx})>[];
    for (int i = 0; i < _problems.length; i++) {
      final best = prefs.getInt('tsume_best_time_$i');
      if (best != null) {
        entries.add((title: _problems[i].title, moves: _problems[i].moves, bestSec: best, idx: i));
      }
    }
    // ベストタイム昇順でソート
    entries.sort((a, b) {
      if (a.moves != b.moves) return a.moves.compareTo(b.moves);
      return a.bestSec.compareTo(b.bestSec);
    });

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(children: [
          Icon(Icons.emoji_events, color: Colors.amber, size: 22),
          SizedBox(width: 8),
          Text('タイムランキング', style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: SizedBox(
          width: 320,
          child: entries.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('まだ解いた問題がありません', style: TextStyle(color: Colors.white54), textAlign: TextAlign.center),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 8),
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    final fmtTime = e.bestSec < 60
                        ? '${e.bestSec}秒'
                        : '${e.bestSec ~/ 60}分${e.bestSec % 60}秒';
                    final medals = ['🥇', '🥈', '🥉'];
                    final medal = i < 3 ? medals[i] : '${i + 1}.';
                    return Row(children: [
                      Text(medal, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.title,
                            style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(fmtTime,
                            style: TextStyle(
                              color: i == 0 ? Colors.amber : Colors.white70,
                              fontSize: 12,
                              fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
                            )),
                      ),
                    ]);
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  // ── ストリーク読み込み ──
  Future<void> _loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString('tsume_last_solve_date') ?? '';
    final streak = prefs.getInt('tsume_streak') ?? 0;
    final dailySolvedToday = prefs.getString('tsume_daily_solved') == _todayKey;

    // フリーズ状態を確認（週単位でリセット）
    final lastFreezeDate = prefs.getString('tsume_freeze_used_date') ?? '';
    final freezeAvailable = lastFreezeDate != _getWeekKey;
    final frozenToday = prefs.getString('tsume_frozen_date') == _todayKey;

    if (mounted) setState(() {
      _streak = streak;
      _dailySolved = dailySolvedToday;
      _freezeAvailable = freezeAvailable;
      _streakFrozenToday = frozenToday;
    });
  }

  String get _getWeekKey {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return '${weekStart.year}-${weekStart.month.toString().padLeft(2,'0')}-${weekStart.day.toString().padLeft(2,'0')}';
  }

  // ── 正解時のストリーク更新 ──
  Future<void> _recordSolve({required bool isDaily}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey;
    final lastDate = prefs.getString('tsume_last_solve_date') ?? '';

    // ストリーク更新
    int newStreak = _streak;
    if (lastDate == today) {
      // 今日すでに解いていた → 変わらず
    } else {
      // 昨日解いたか判定
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayKey =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2,'0')}-${yesterday.day.toString().padLeft(2,'0')}';
      if (lastDate == yesterdayKey) {
        newStreak = _streak + 1;
      } else {
        newStreak = 1; // リセット
      }
      await prefs.setString('tsume_last_solve_date', today);
      await prefs.setInt('tsume_streak', newStreak);
    }

    // デイリー問題の完了記録
    if (isDaily) {
      await prefs.setString('tsume_daily_solved', today);
    }

    if (mounted) setState(() {
      _streak = newStreak;
      if (isDaily) _dailySolved = true;
    });
  }

  // ── ストリーク保険（フリーズ） ──
  Future<void> _useFreeze() async {
    final prefs = await SharedPreferences.getInstance();
    final sub = PurchaseService.isPremium;

    // サブスク無制限、未加入は週1回
    if (!_freezeAvailable && !sub) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('フリーズは週1回までです。サブスク加入で無制限に！'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // フリーズ使用
    await prefs.setString('tsume_frozen_date', _todayKey);
    if (!sub) {
      await prefs.setString('tsume_freeze_used_date', _getWeekKey);
    }

    // ストリークを継続（昨日解いた扱いにする）
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayKey = '${yesterday.year}-${yesterday.month.toString().padLeft(2,'0')}-${yesterday.day.toString().padLeft(2,'0')}';
    await prefs.setString('tsume_last_solve_date', yesterdayKey);

    if (mounted) {
      setState(() {
        _freezeAvailable = false;
        _streakFrozenToday = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ストリークが保護されました！'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadCleared() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _cleared = List.generate(
        _problems.length,
        (i) => prefs.getBool('tsume_clear_$i') ?? false,
      );
    });
  }

  Future<void> _saveCleared(int idx) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tsume_clear_$idx', true);
    setState(() => _cleared[idx] = true);
  }

  // ── デイリー問題カード ──
  Widget _timeAttackCard(BuildContext ctx) {
    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.deepOrange.withAlpha(100), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Colors.deepOrange.shade900.withAlpha(120),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.timer, color: Colors.deepOrange, size: 26),
        ),
        title: const Text('タイムアタック',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        subtitle: const Text('3分間で何問解けるか挑戦！',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
        onTap: () => Navigator.push(
          ctx, MaterialPageRoute(builder: (_) => const TsumeTimeAttackScreen())),
      ),
    );
  }

  Widget _dailyCard() {
    final idx = _dailyIdx;
    final prob = _problems[idx];
    final now = DateTime.now();
    final dateStr = '${now.month}月${now.day}日';

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<dynamic>(
          context,
          MaterialPageRoute(
            builder: (_) => _SolvePage(prob: prob, index: idx),
          ),
        );
        if (result == true) {
          await _saveCleared(idx);
          await _recordSolve(isDaily: true);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _dailySolved
                ? [Colors.green.shade900, Colors.green.shade800]
                : [const Color(0xFF2D1B69), const Color(0xFF1A1054)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _dailySolved ? Colors.green.shade400 : Colors.deepPurpleAccent.withAlpha(180),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (_dailySolved ? Colors.green : Colors.deepPurple).withAlpha(60),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _dailySolved ? Colors.green.shade700 : Colors.deepPurple.shade700,
            ),
            child: Center(
              child: _dailySolved
                  ? const Icon(Icons.check_circle, color: Colors.white, size: 28)
                  : const Icon(Icons.calendar_today, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📅 デイリー問題 $dateStr',
                  style: TextStyle(
                    color: _dailySolved ? Colors.green.shade300 : Colors.amber.shade200,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  prob.title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  _dailySolved ? '✓ クリア済み' : '${prob.moves}手詰め  タップして挑戦！',
                  style: TextStyle(
                    color: _dailySolved ? Colors.green.shade300 : Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_streak > 0)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 22)),
                Text(
                  '$_streak日',
                  style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
        ]),
      ),
    );
  }

  String _clearCountLabel(int moves) {
    final idxs = <int>[];
    for (int i = 0; i < _problems.length; i++) {
      if (_problems[i].moves == moves && !GL.inCheck(_problems[i].board, false)) {
        idxs.add(i);
      }
    }
    final total = idxs.length;
    final done = idxs.where((i) => i < _cleared.length && _cleared[i]).length;
    return '$done/$total';
  }

  Tab _tabItem(String title, String sub) => Tab(
    height: 52,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 1),
        Text(sub, style: const TextStyle(fontSize: 9)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    // フィルタ後の問題リスト(元インデックス付き) ※開始局面で王手の問題は除外
    final filtered = <(int, _TsumeProb)>[];
    for (int i = 0; i < _problems.length; i++) {
      if (_filterMoves == 0 || _problems[i].moves == _filterMoves) {
        if (!GL.inCheck(_problems[i].board, false)) {
          filtered.add((i, _problems[i]));
        }
      }
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        title: const Text('詰将棋', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // タイムランキング
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined, color: Colors.amber),
            tooltip: 'タイムランキング',
            onPressed: _showTimeRanking,
          ),
          // ストリークバッジ
          if (_streak > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade800.withAlpha(200),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade400, width: 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🔥', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    '$_streak日連続',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Colors.amber,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.white54,
            labelPadding: const EdgeInsets.symmetric(horizontal: 10),
            tabs: [
              const Tab(height: 52, text: '全て'),
              _tabItem('1手詰め', _clearCountLabel(1)),
              _tabItem('3手詰め', _clearCountLabel(3)),
              _tabItem('5手詰め', _clearCountLabel(5)),
              _tabItem('7手詰め', _clearCountLabel(7)),
              _tabItem('9手詰め', _clearCountLabel(9)),
            ],
          ),
        ),
      ),
      body: filtered.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.construction, color: Colors.white38, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    '問題を準備中です',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '近日公開予定',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length + (_filterMoves == 0 ? 2 : 0), // +2 for daily + time attack cards
        itemBuilder: (context, listIdx) {
          // デイリー問題カード（全てタブのみ・先頭）
          if (_filterMoves == 0 && listIdx == 0) {
            return _dailyCard();
          }
          if (_filterMoves == 0 && listIdx == 1) {
            return _timeAttackCard(context);
          }
          final realIdx = _filterMoves == 0 ? listIdx - 2 : listIdx;
          final (origIdx, prob) = filtered[realIdx];
          final cleared = origIdx < _cleared.length && _cleared[origIdx];
          return Card(
            color: _card,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: cleared ? Colors.amber.shade400 : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: CircleAvatar(
                backgroundColor: cleared
                    ? Colors.amber.shade700
                    : Colors.blueGrey.shade800,
                child: Text(
                  '${origIdx + 1}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                prob.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${prob.moves}手詰め',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              trailing: cleared
                  ? Icon(Icons.check_circle, color: Colors.amber.shade400)
                  : const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () async {
                final result = await Navigator.push<dynamic>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _SolvePage(prob: prob, index: origIdx),
                  ),
                );
                if (result == true) {
                  await _saveCleared(origIdx);
                  await _recordSolve(isDaily: origIdx == _dailyIdx);
                }
                // 'skip' が返った場合は問題に誤りがあるため何もしない
              },
            ),
          );
        },
      ),
    );
  }
}

// ===== 解答画面 =====

class _SolvePage extends StatefulWidget {
  final _TsumeProb prob;
  final int index;
  final bool timeAttackMode;
  final VoidCallback? onSolvedInTimeAttack;
  final VoidCallback? onSolvedCallback;   // generic: skips dialog, shows snackbar
  final VoidCallback? onResetRequested;   // intercept reset button
  const _SolvePage({
    super.key,
    required this.prob,
    required this.index,
    this.timeAttackMode = false,
    this.onSolvedInTimeAttack,
    this.onSolvedCallback,
    this.onResetRequested,
  });

  @override
  State<_SolvePage> createState() => _SolvePageState();
}

class _SolvePageState extends State<_SolvePage> {
  static const _bg = AppTheme.bg;
  static const _card = AppTheme.surface;

  late List<List<Piece?>> _board;
  late Map<PieceType, int> _p1Hand;
  late Map<PieceType, int> _p2Hand;

  // solution のインデックス: 偶数=先手の手、奇数=後手の応手
  int _solutionIdx = 0;
  bool _solved = false;
  bool _startInCheck = false; // 開始局面で後手玉がすでに王手されている場合は問題に誤りあり

  (int, int)? _selected;
  Set<(int, int)> _legalDots = {};
  (int, int)? _lastFrom;
  (int, int)? _lastTo;
  PieceType? _selectedHandPiece;
  int _hintLevel = 0;

  // ── タイマー ──
  final _stopwatch = Stopwatch();
  Timer? _ticker;
  int _elapsedSec = 0;
  int? _bestTimeSec;

  // ── 詰み探索エンジン ──
  final _engine = TsumeEngine();
  bool _verifying = false; // 検証中フラグ

  bool get _p1Turn => _solutionIdx % 2 == 0; // 偶数=先手番

  // 残り手数（この手番から詰みまで）
  int get _remainingMoves => widget.prob.moves - _solutionIdx;

  @override
  void initState() {
    super.initState();
    _resetState();
    _loadBestTime();
    // 1秒ごとに画面更新
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_solved && mounted) {
        setState(() => _elapsedSec = _stopwatch.elapsed.inSeconds);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadBestTime() async {
    final prefs = await SharedPreferences.getInstance();
    final best = prefs.getInt('tsume_best_time_${widget.index}');
    if (mounted) setState(() => _bestTimeSec = best);
  }

  Future<void> _saveBestTime(int sec) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('tsume_best_time_${widget.index}');
    if (current == null || sec < current) {
      await prefs.setInt('tsume_best_time_${widget.index}', sec);
      if (mounted) setState(() => _bestTimeSec = sec);
    }
  }

  String _fmtTime(int sec) {
    if (sec < 60) return '${sec}秒';
    return '${sec ~/ 60}分${sec % 60}秒';
  }

  void _resetState() {
    final prob = widget.prob;
    _board = List.generate(9, (r) => List<Piece?>.from(prob.board[r]));
    _p1Hand = Map<PieceType, int>.from(prob.p1Hand);
    _p2Hand = Map<PieceType, int>.from(prob.p2Hand);
    _solutionIdx = 0;
    _solved = false;
    _selected = null;
    _legalDots = {};
    _lastFrom = null;
    _lastTo = null;
    _selectedHandPiece = null;
    _stopwatch.reset();
    _stopwatch.start();
    _elapsedSec = 0;
    // 安全チェック: 開始局面で後手玉がすでに王手されていないか確認
    _startInCheck = GL.inCheck(_board, false);
  }

  AMove? get _currentSol {
    final sol = widget.prob.solution;
    return _solutionIdx < sol.length ? sol[_solutionIdx] : null;
  }

  // ===== 盤面タップ =====

  void _onBoardTap(int row, int col) {
    if (_solved || !_p1Turn || _verifying) return;

    if (_selectedHandPiece != null) {
      _tryDrop(row, col); // async - fire and forget OK
      return;
    }

    final tapped = _board[row][col];

    if (_selected == null) {
      if (tapped != null && tapped.isPlayer1) {
        setState(() {
          _selected = (row, col);
          _legalDots = GL.legal(_board, row, col).toSet();
        });
      }
    } else {
      final sel = _selected!;
      if (sel == (row, col)) {
        setState(() {
          _selected = null;
          _legalDots = {};
        });
        return;
      }
      if (tapped != null && tapped.isPlayer1) {
        setState(() {
          _selected = (row, col);
          _legalDots = GL.legal(_board, row, col).toSet();
        });
        return;
      }
      if (_legalDots.contains((row, col))) {
        _tryMove(sel.$1, sel.$2, row, col);
      } else {
        setState(() {
          _selected = null;
          _legalDots = {};
        });
      }
    }
  }

  // ── 動的詰み検証 ──────────────────────────────────────
  // 固定手順との一致ではなく「詰みに向かう有効手か」を判定する。

  Future<void> _tryMove(int fr, int fc, int tr, int tc) async {
    if (_verifying) return;
    final piece = _board[fr][fc];
    if (piece == null) return;

    setState(() {
      _selected = null;
      _legalDots = {};
    });

    // 成り判定: 詰み探索で成りと不成りを両方試す（自動で良い方を選ぶ）
    // 必須成り
    bool forcedPromote = piece.canPromote && piece.mustPromote(tr);

    // 成り・不成りの候補を構築
    final candidates = <AMove>[];
    if (forcedPromote) {
      candidates.add(AMove(fr: fr, fc: fc, tr: tr, tc: tc, promote: true));
    } else if (piece.canPromote) {
      // 成りゾーンなら両方試す（詰みに繋がる方を優先）
      bool inZ(int row) => piece.isPlayer1 ? row <= 2 : row >= 6;
      if (inZ(fr) || inZ(tr)) {
        candidates.add(AMove(fr: fr, fc: fc, tr: tr, tc: tc, promote: true));
        candidates.add(AMove(fr: fr, fc: fc, tr: tr, tc: tc, promote: false));
      } else {
        candidates.add(AMove(fr: fr, fc: fc, tr: tr, tc: tc, promote: false));
      }
    } else {
      candidates.add(AMove(fr: fr, fc: fc, tr: tr, tc: tc, promote: false));
    }

    await _verifyAndApplyMove(candidates);
  }

  Future<void> _tryDrop(int tr, int tc) async {
    if (_verifying) return;
    final type = _selectedHandPiece;
    if (type == null) return;

    // 打てるマスでなければ選択解除のみ
    if (!_legalDots.contains((tr, tc))) {
      setState(() {
        _selectedHandPiece = null;
        _legalDots = {};
      });
      return;
    }

    setState(() {
      _selectedHandPiece = null;
      _selected = null;
      _legalDots = {};
    });

    final mv = AMove(fr: -1, fc: -1, tr: tr, tc: tc, drop: type);
    await _verifyAndApplyMove([mv]);
  }

  /// 手を適用し、後手の最善防御を自動実行してから
  /// 残り手数内に詰みが存在するか確認する。
  /// 詰みが存在しなければ初期局面に戻す。
  Future<void> _verifyAndApplyMove(List<AMove> candidates) async {
    if (_verifying) return;
    setState(() => _verifying = true);

    // ── 1. 王手になる候補を選んで適用 ──────────────────────────
    AMove? mv;
    for (final c in candidates) {
      final tmp = AI.apply(_board, _p1Hand, _p2Hand, c, true);
      if (GL.inCheck(tmp.b, false)) { mv = c; break; }
    }
    mv ??= candidates.first; // 王手にならない場合も視覚表示のために適用

    if (mv.drop != null) {
      _execDrop(mv.drop!, mv.tr, mv.tc, isP1: true);
    } else {
      _execMove(mv.fr, mv.fc, mv.tr, mv.tc, mv.promote);
    }
    setState(() {
      _selected = null;
      _legalDots = {};
      _selectedHandPiece = null;
    });

    // ── 2. 詰将棋ルール: 攻め方の手は必ず王手 ──────────────────
    if (!GL.inCheck(_board, false)) {
      await _handleWrongAttempt();
      return;
    }

    // ── 3. 即詰み（後手に合法手なし）→ 正解 ────────────────────
    if (!GL.hasLegalMove(_board, false, _p2Hand, _p1Hand)) {
      setState(() => _verifying = false);
      _onSolved();
      return;
    }

    // ── 4. 後手の最善防御手を自動実行 ───────────────────────────
    _solutionIdx++;
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    final defMove = await Future(
      () => AI.bestMove(_board, _p1Hand, _p2Hand, false, 2),
    );
    if (!mounted) return;

    if (defMove == null) {
      setState(() => _verifying = false);
      _onSolved();
      return;
    }

    if (defMove.drop != null) {
      _execDrop(defMove.drop!, defMove.tr, defMove.tc, isP1: false);
    } else {
      _execMove(defMove.fr, defMove.fc, defMove.tr, defMove.tc, defMove.promote);
    }
    _solutionIdx++;
    setState(() {});

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    // ── 5. 残り手数内に詰みが存在するか確認 ─────────────────────
    final remaining = widget.prob.moves - _solutionIdx;

    if (remaining <= 0) {
      // 手数を全て使ったが詰んでいない
      await _handleWrongAttempt(delayMs: 700);
      return;
    }

    final mateResult = await _engine.findMate(
      board: _board,
      p1Hand: _p1Hand,
      p2Hand: _p2Hand,
      attackerIsP1: true,
      depth: remaining,
    );
    if (!mounted) return;

    if (!mateResult.isMate) {
      // 残り手数内に詰み経路なし → 最初の局面に戻す
      await _handleWrongAttempt(delayMs: 700);
      return;
    }

    // ── 6. まだ詰み経路あり → 継続 ─────────────────────────────
    setState(() => _verifying = false);
  }

  void _execMove(int fr, int fc, int tr, int tc, bool promote) {
    final piece = _board[fr][fc]!;
    final cap = _board[tr][tc];
    if (cap != null) {
      final hand = piece.isPlayer1 ? _p1Hand : _p2Hand;
      hand[cap.baseType] = (hand[cap.baseType] ?? 0) + 1;
    }
    _board[tr][tc] = promote ? Piece(piece.promotedType, piece.isPlayer1) : piece;
    _board[fr][fc] = null;
    _lastFrom = (fr, fc);
    _lastTo = (tr, tc);
  }

  void _execDrop(PieceType type, int tr, int tc, {required bool isP1}) {
    final hand = isP1 ? _p1Hand : _p2Hand;
    _board[tr][tc] = Piece(type, isP1);
    hand[type] = (hand[type] ?? 1) - 1;
    if ((hand[type] ?? 0) <= 0) hand.remove(type);
    _lastFrom = null;
    _lastTo = (tr, tc);
  }

  void _onSolved() {
    _stopwatch.stop();
    final elapsed = _stopwatch.elapsed.inSeconds;
    _saveBestTime(elapsed);
    setState(() {
      _solved = true;
      _elapsedSec = elapsed;
    });

    // タイムアタックモード: ダイアログなしで次の問題へ
    if (widget.timeAttackMode) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
          content: Text('正解！次の問題へ'),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 800),
        ),
        );
      }
      Future.delayed(const Duration(milliseconds: 900), () {
        widget.onSolvedInTimeAttack?.call();
      });
      return;
    }

    // 汎用コールバックモード（デイリー・ローグライト）
    if (widget.onSolvedCallback != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正解！'),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 800),
          ),
        );
      }
      Future.delayed(const Duration(milliseconds: 900), () {
        widget.onSolvedCallback?.call();
      });
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('詰みました！',
            style: TextStyle(
                color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('正解です！おめでとうございます。',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.timer_outlined, color: AppTheme.accent, size: 16),
              const SizedBox(width: 6),
              Text(
                '解答時間: ${_fmtTime(elapsed)}',
                style: const TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              if (_bestTimeSec != null && elapsed <= _bestTimeSec!) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(40),
                    border: Border.all(color: Colors.amber),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('🏆 自己ベスト！', style: TextStyle(color: Colors.amber, fontSize: 11)),
                ),
              ],
            ]),
            if (widget.prob.explanation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withAlpha(60)),
                ),
                child: Text(
                  widget.prob.explanation,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);       // ダイアログ閉じる
              Navigator.pop(context, true); // 一覧に戻り(クリア通知)
            },
            child: const Text('戻る', style: TextStyle(color: Colors.amber)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _resetState());
            },
            child:
                const Text('もう一度', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _showWrong() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✗ その手では詰みません'),
        duration: Duration(milliseconds: 700),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // 誤答時の共通処理。onResetRequested が渡されている場合
  // （デイリー詰将棋・ローグライトモード）は親側の残機/回数管理を
  // 必ず経由させる。以前は _resetState() を直接呼んでいたため、
  // ローグライトで間違えてもライフが減らないバグがあった。
  Future<void> _handleWrongAttempt({int delayMs = 800}) async {
    _showWrong();
    await Future.delayed(Duration(milliseconds: delayMs));
    if (!mounted) return;
    if (widget.onResetRequested != null) {
      widget.onResetRequested!();
    } else {
      setState(() {
        _resetState();
        _verifying = false;
      });
    }
  }

  // ===== 持ち駒ウィジェット =====

  Widget _handWidget(Map<PieceType, int> hand, {required bool isP1}) {
    if (hand.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text('なし', style: TextStyle(color: Colors.white38, fontSize: 12)),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: hand.entries.map((e) {
        final selected = isP1 && _selectedHandPiece == e.key;
        return GestureDetector(
          onTap: isP1 && _p1Turn && !_solved && !_verifying
              ? () {
                  setState(() {
                    final tapping = e.key;
                    if (_selectedHandPiece == tapping) {
                      // 同じ駒を再タップ → 選択解除
                      _selectedHandPiece = null;
                      _legalDots = {};
                    } else {
                      _selectedHandPiece = tapping;
                      _selected = null;
                      // 打てるマスをハイライト表示
                      _legalDots = GL
                          .dropSquares(_board, tapping, true, _p1Hand, _p2Hand)
                          .toSet();
                    }
                  });
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.amber.shade700
                  : Colors.blueGrey.shade800,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected
                    ? Colors.amber.shade300
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Text(
              '${pieceLabel(e.key)}×${e.value}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ===== ビルド =====

  @override
  Widget build(BuildContext context) {
    final prob = widget.prob;
    final sol = _currentSol;

    final turnText = _verifying
        ? '検証中...'
        : _p1Turn ? '▲先手番' : '△後手番(自動応手中...)';
    final moveNum = (_solutionIdx ~/ 2) + 1;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        title: Text(prob.title,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // タイマー表示
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accent.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accent.withAlpha(100)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.timer_outlined, color: AppTheme.accent, size: 14),
                const SizedBox(width: 4),
                Text(
                  _solved ? _fmtTime(_elapsedSec) : _fmtTime(_elapsedSec),
                  style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ]),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              if (widget.onResetRequested != null) {
                widget.onResetRequested!();
              } else {
                setState(() => _resetState());
              }
            },
            icon: const Icon(Icons.refresh, color: Colors.white54, size: 18),
            label: const Text('リセット',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final boardSize = (maxW * 0.92).clamp(200.0, 440.0);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 開始局面エラー警告
                if (_startInCheck)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withAlpha(200),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'この問題は修正中です。\n開始局面に誤りがある可能性があります。',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('戻る', style: TextStyle(color: Colors.amber, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                // 状態表示
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text('${prob.moves}手詰め',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13)),
                    if (_verifying) ...[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                    Text('第$moveNum手  $turnText',
                        style: TextStyle(
                            color: _verifying
                                ? AppTheme.accent
                                : _p1Turn
                                    ? Colors.lightBlue.shade300
                                    : Colors.orange.shade300,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),

                // 後手持ち駒(上)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('後手持ち駒:',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 11)),
                      _handWidget(_p2Hand, isP1: false),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 盤面
                Center(
                  child: GestureDetector(
                    onTapUp: (details) {
                      final labelSize = boardSize * 0.05;
                      final cellSize = (boardSize - labelSize) / 9;
                      final x = details.localPosition.dx - labelSize;
                      final y = details.localPosition.dy - labelSize;
                      final col = (x / cellSize).floor();
                      final row = (y / cellSize).floor();
                      if (row >= 0 && row < 9 && col >= 0 && col < 9) {
                        _onBoardTap(row, col);
                      }
                    },
                    child: SizedBox(
                      width: boardSize,
                      child: MiniBoardWidget(
                        board: _board,
                        moveDots: _legalDots,
                        lastMoveFrom: _lastFrom,
                        lastMoveTo: _lastTo,
                        highlightSquares:
                            _selected != null ? {_selected!} : {},
                        showLabels: true,
                        size: boardSize,
                        boardFlipped: false,
                        currentIsP1: _p1Turn,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 先手持ち駒(下)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('先手持ち駒:',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 11)),
                      _handWidget(_p1Hand, isP1: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ヒントボタン
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      icon: Icon(
                        _hintLevel == 0 ? Icons.lightbulb_outline : Icons.lightbulb,
                        color: _hintLevel > 0 ? Colors.amber : Colors.white54,
                        size: 16,
                      ),
                      label: Text(
                        _hintLevel == 0 ? 'ヒント' : _hintLevel == 1 ? 'ヒント (駒種)' : 'ヒント (移動先)',
                        style: TextStyle(
                          color: _hintLevel > 0 ? Colors.amber : Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: !_solved ? () {
                        setState(() => _hintLevel = (_hintLevel + 1) % 3);
                      } : null,
                    ),
                    if (_hintLevel > 0)
                      TextButton(
                        onPressed: () => setState(() => _hintLevel = 0),
                        child: const Text('リセット', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      ),
                  ],
                ),
                if (_hintLevel > 0 && !_solved) Builder(builder: (ctx) {
                  final sol = widget.prob.solution;
                  if (sol.isEmpty) return const SizedBox.shrink();
                  final firstMove = sol[0];

                  if (_hintLevel == 1) {
                    // Level 1: 駒の種類のみ
                    Piece? piece;
                    if (firstMove.drop != null) {
                      piece = Piece(firstMove.drop!, true);
                    } else if (firstMove.fr >= 0 && firstMove.fr < 9) {
                      piece = _board[firstMove.fr][firstMove.fc];
                    }
                    final pieceName = piece?.label ?? '?';
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withAlpha(80)),
                      ),
                      child: Text('ヒント: $pieceName を動かす',
                          style: const TextStyle(color: Colors.amber, fontSize: 12),
                          textAlign: TextAlign.center),
                    );
                  } else {
                    // Level 2: 移動先も表示
                    Piece? piece;
                    if (firstMove.drop != null) {
                      piece = Piece(firstMove.drop!, true);
                    } else if (firstMove.fr >= 0 && firstMove.fr < 9) {
                      piece = _board[firstMove.fr][firstMove.fc];
                    }
                    final pieceName = piece?.label ?? '?';
                    const cols = ['9','8','7','6','5','4','3','2','1'];
                    const rows = ['一','二','三','四','五','六','七','八','九'];
                    final tr = firstMove.tr;
                    final tc = firstMove.tc;
                    final dest = (tr >= 0 && tr < 9 && tc >= 0 && tc < 9)
                        ? '${cols[tc]}${rows[tr]}' : '?';
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withAlpha(120)),
                      ),
                      child: Text('ヒント: $pieceName → $dest',
                          style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                    );
                  }
                }),
                const SizedBox(height: 8),
                // 操作ガイド
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F3460),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '駒をタップして選択し、移動先をタップしてください。\n'
                    '持ち駒は「先手持ち駒」からタップして選択して打てます。',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
