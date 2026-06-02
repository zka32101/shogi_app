// lib/logic.dart — 将棋ロジック & AI

import 'dart:math';
import 'piece.dart';

// ===== GL: ゲームロジック =====
class GL {
  static bool ok(int r, int c) => r >= 0 && r < 9 && c >= 0 && c < 9;

  static List<List<Piece?>> copy(List<List<Piece?>> b) =>
      List.generate(9, (r) => List<Piece?>.from(b[r]));

  // 疑似合法手（王手放置を除外しない）
  static List<(int, int)> pseudo(List<List<Piece?>> b, int row, int col) {
    final piece = b[row][col];
    if (piece == null) return [];
    final p1 = piece.isPlayer1;
    final fwd = p1 ? -1 : 1;
    final moves = <(int, int)>[];

    bool can(int r, int c) =>
        ok(r, c) && (b[r][c] == null || b[r][c]!.isPlayer1 != p1);

    void step(int dr, int dc) {
      if (can(row + dr, col + dc)) moves.add((row + dr, col + dc));
    }

    void slide(int dr, int dc) {
      int r = row + dr, c = col + dc;
      while (ok(r, c)) {
        if (b[r][c] != null && b[r][c]!.isPlayer1 == p1) break;
        moves.add((r, c));
        if (b[r][c] != null) break;
        r += dr;
        c += dc;
      }
    }

    void gold() {
      step(fwd, -1);
      step(fwd, 0);
      step(fwd, 1);
      step(0, -1);
      step(0, 1);
      step(-fwd, 0);
    }

    switch (piece.type) {
      case PieceType.king:
        for (int dr = -1; dr <= 1; dr++)
          for (int dc = -1; dc <= 1; dc++) if (dr != 0 || dc != 0) step(dr, dc);
      case PieceType.rook:
        slide(-1, 0);
        slide(1, 0);
        slide(0, -1);
        slide(0, 1);
      case PieceType.bishop:
        slide(-1, -1);
        slide(-1, 1);
        slide(1, -1);
        slide(1, 1);
      case PieceType.gold:
        gold();
      case PieceType.silver:
        step(fwd, -1);
        step(fwd, 0);
        step(fwd, 1);
        step(-fwd, -1);
        step(-fwd, 1);
      case PieceType.knight:
        step(fwd * 2, -1);
        step(fwd * 2, 1);
      case PieceType.lance:
        slide(fwd, 0);
      case PieceType.pawn:
        step(fwd, 0);
      case PieceType.promotedRook:
        slide(-1, 0);
        slide(1, 0);
        slide(0, -1);
        slide(0, 1);
        step(-1, -1);
        step(-1, 1);
        step(1, -1);
        step(1, 1);
      case PieceType.promotedBishop:
        slide(-1, -1);
        slide(-1, 1);
        slide(1, -1);
        slide(1, 1);
        step(-1, 0);
        step(1, 0);
        step(0, -1);
        step(0, 1);
      default:
        gold(); // 成銀・成桂・成香・と金
    }
    return moves;
  }

  static (int, int)? kingPos(List<List<Piece?>> b, bool p1) {
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p != null && p.type == PieceType.king && p.isPlayer1 == p1)
          return (r, c);
      }
    return null;
  }

  static bool inCheck(List<List<Piece?>> b, bool p1) {
    final k = kingPos(b, p1);
    if (k == null) return false;
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p == null || p.isPlayer1 == p1) continue;
        if (pseudo(b, r, c).any((m) => m.$1 == k.$1 && m.$2 == k.$2))
          return true;
      }
    return false;
  }

  // 合法手（王手放置除外）
  static List<(int, int)> legal(List<List<Piece?>> b, int row, int col) {
    final piece = b[row][col];
    if (piece == null) return [];
    return pseudo(b, row, col).where((dest) {
      final nb = copy(b);
      nb[dest.$1][dest.$2] = piece;
      nb[row][col] = null;
      return !inCheck(nb, piece.isPlayer1);
    }).toList();
  }

  // 打てるマス
  static List<(int, int)> dropSquares(
    List<List<Piece?>> b,
    PieceType type,
    bool p1,
    Map<PieceType, int> hand,
    Map<PieceType, int> oppHand,
  ) {
    if ((hand[type] ?? 0) <= 0) return [];
    final squares = <(int, int)>[];
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++) {
        if (b[r][c] != null) continue;
        if (type == PieceType.pawn || type == PieceType.lance) {
          if (p1 && r == 0) continue;
          if (!p1 && r == 8) continue;
        }
        if (type == PieceType.knight) {
          if (p1 && r <= 1) continue;
          if (!p1 && r >= 7) continue;
        }
        // 二歩
        if (type == PieceType.pawn) {
          bool nifu = false;
          for (int rr = 0; rr < 9; rr++) {
            final p = b[rr][c];
            if (p != null && p.type == PieceType.pawn && p.isPlayer1 == p1) {
              nifu = true;
              break;
            }
          }
          if (nifu) continue;
        }
        final nb = copy(b);
        nb[r][c] = Piece(type, p1);
        if (inCheck(nb, p1)) continue;
        // 打ち歩詰め
        if (type == PieceType.pawn && _isPawnMate(nb, p1, oppHand)) continue;
        squares.add((r, c));
      }
    return squares;
  }

  static bool _isPawnMate(
    List<List<Piece?>> b,
    bool droppedByP1,
    Map<PieceType, int> oppHand,
  ) {
    final opp = !droppedByP1;
    if (!inCheck(b, opp)) return false;
    return !hasLegalMove(b, opp, oppHand);
  }

  // 駒が「効いている」マス（自駒のいるマスも含む・純粋な攻撃範囲）
  static List<(int, int)> threatens(List<List<Piece?>> b, int row, int col) {
    final piece = b[row][col];
    if (piece == null) return [];
    final p1 = piece.isPlayer1;
    final fwd = p1 ? -1 : 1;
    final sq = <(int, int)>[];

    void step(int dr, int dc) {
      final r = row + dr, c = col + dc;
      if (ok(r, c)) sq.add((r, c));
    }

    void slide(int dr, int dc) {
      int r = row + dr, c = col + dc;
      while (ok(r, c)) {
        sq.add((r, c));
        if (b[r][c] != null) break; // 駒があれば止まる（自駒でも敵駒でも）
        r += dr;
        c += dc;
      }
    }

    void gold() {
      step(fwd, -1);
      step(fwd, 0);
      step(fwd, 1);
      step(0, -1);
      step(0, 1);
      step(-fwd, 0);
    }

    switch (piece.type) {
      case PieceType.king:
        for (int dr = -1; dr <= 1; dr++)
          for (int dc = -1; dc <= 1; dc++) if (dr != 0 || dc != 0) step(dr, dc);
      case PieceType.rook:
        slide(-1, 0);
        slide(1, 0);
        slide(0, -1);
        slide(0, 1);
      case PieceType.bishop:
        slide(-1, -1);
        slide(-1, 1);
        slide(1, -1);
        slide(1, 1);
      case PieceType.gold:
        gold();
      case PieceType.silver:
        step(fwd, -1);
        step(fwd, 0);
        step(fwd, 1);
        step(-fwd, -1);
        step(-fwd, 1);
      case PieceType.knight:
        step(fwd * 2, -1);
        step(fwd * 2, 1);
      case PieceType.lance:
        slide(fwd, 0);
      case PieceType.pawn:
        step(fwd, 0);
      case PieceType.promotedRook:
        slide(-1, 0);
        slide(1, 0);
        slide(0, -1);
        slide(0, 1);
        step(-1, -1);
        step(-1, 1);
        step(1, -1);
        step(1, 1);
      case PieceType.promotedBishop:
        slide(-1, -1);
        slide(-1, 1);
        slide(1, -1);
        slide(1, 1);
        step(-1, 0);
        step(1, 0);
        step(0, -1);
        step(0, 1);
      default:
        gold();
    }
    return sq;
  }

  // 指定プレイヤーの全駒の効きマップ
  static List<List<int>> attackMap(List<List<Piece?>> b, bool p1) {
    final map = List.generate(9, (_) => List.filled(9, 0));
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++) {
        final piece = b[r][c];
        if (piece == null || piece.isPlayer1 != p1) continue;
        for (final dest in threatens(b, r, c)) map[dest.$1][dest.$2]++;
      }
    return map;
  }

  static bool hasLegalMove(
    List<List<Piece?>> b,
    bool p1,
    Map<PieceType, int> hand,
  ) {
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p == null || p.isPlayer1 != p1) continue;
        if (legal(b, r, c).isNotEmpty) return true;
      }
    for (final type in hand.keys) {
      if ((hand[type] ?? 0) <= 0) continue;
      if (dropSquares(b, type, p1, hand, {}).isNotEmpty) return true;
    }
    return false;
  }

  /// KifuMove を盤面・持ち駒に破壊的に適用する（感想戦・棋譜再生用）
  static void applyKifuMove(
    List<List<Piece?>> b,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
    KifuMove move,
  ) {
    final isP1 = move.p1;
    final myHand = isP1 ? p1Hand : p2Hand;
    final oppHand = isP1 ? p2Hand : p1Hand;

    if (move.drop != null) {
      b[move.tr][move.tc] = Piece(move.drop!, isP1);
      myHand[move.drop!] = (myHand[move.drop!] ?? 1) - 1;
      if ((myHand[move.drop!] ?? 0) <= 0) myHand.remove(move.drop!);
    } else {
      if (move.fr < 0 || move.fc < 0) return;
      final piece = b[move.fr][move.fc];
      if (piece == null) return;
      final cap = b[move.tr][move.tc];
      if (cap != null) {
        final bt = cap.baseType;
        oppHand[bt] = (oppHand[bt] ?? 0) + 1;
      }
      b[move.tr][move.tc] = move.promote
          ? Piece(piece.promotedType, isP1)
          : piece;
      b[move.fr][move.fc] = null;
    }
  }
}

// ===== AI =====

// 駒の評価値（B: より正確なシステム値に改善）
const _val = {
  PieceType.pawn:             100,
  PieceType.lance:            250,
  PieceType.knight:           280,
  PieceType.silver:           440,
  PieceType.gold:             510,
  PieceType.bishop:           740,
  PieceType.rook:             880,
  PieceType.king:           10000,
  PieceType.promotedPawn:     530,
  PieceType.promotedLance:    530,
  PieceType.promotedKnight:   530,
  PieceType.promotedSilver:   530,
  PieceType.promotedBishop:   940,
  PieceType.promotedRook:    1040,
};

// ===== 千日手・持将棋判定 =====
class RepetitionChecker {
  // 局面ハッシュ → 出現回数
  final Map<String, int> _posCount = {};

  /// 現局面のハッシュを生成して記録し、千日手かどうかを返す
  bool record(List<List<Piece?>> board, Map<PieceType, int> p1Hand,
      Map<PieceType, int> p2Hand, bool p1Turn) {
    final hash = _hash(board, p1Hand, p2Hand, p1Turn);
    final count = (_posCount[hash] ?? 0) + 1;
    _posCount[hash] = count;
    return count >= 4; // 4回同一局面 = 千日手
  }

  void reset() => _posCount.clear();

  static String _hash(List<List<Piece?>> board, Map<PieceType, int> p1Hand,
      Map<PieceType, int> p2Hand, bool p1Turn) {
    final buf = StringBuffer();
    buf.write(p1Turn ? '1' : '0');
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = board[r][c];
        buf.write(p == null ? '.' : '${p.isPlayer1 ? "P" : "p"}${p.type.index}');
      }
    }
    // 持ち駒
    for (final e in p1Hand.entries) buf.write('H${e.key.index}=${e.value}');
    buf.write('|');
    for (final e in p2Hand.entries) buf.write('h${e.key.index}=${e.value}');
    return buf.toString();
  }
}

/// 持将棋判定: 入玉点数計算
class NyugyokuChecker {
  /// 先手・後手それぞれの点数を返す（大駒=5点、小駒=1点）
  static (int p1Score, int p2Score) calcScores(
      List<List<Piece?>> board, Map<PieceType, int> p1Hand, Map<PieceType, int> p2Hand) {
    int p1 = 0, p2 = 0;
    // 持ち駒
    for (final e in p1Hand.entries) {
      p1 += _piecePoint(e.key) * e.value;
    }
    for (final e in p2Hand.entries) {
      p2 += _piecePoint(e.key) * e.value;
    }
    // 盤上の駒
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = board[r][c];
        if (p == null || p.type == PieceType.king) continue;
        if (p.isPlayer1) p1 += _piecePoint(p.baseType);
        else             p2 += _piecePoint(p.baseType);
      }
    }
    return (p1, p2);
  }

  static int _piecePoint(PieceType t) {
    switch (t) {
      case PieceType.rook:
      case PieceType.bishop: return 5;
      default:               return 1;
    }
  }

  /// 入玉条件チェック（玉が敵陣3段目以内にいるか）
  static bool isNyugyoku(List<List<Piece?>> board, bool p1Turn) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = board[r][c];
        if (p == null || p.type != PieceType.king) continue;
        if (p.isPlayer1 && r <= 2) return true;
        if (!p.isPlayer1 && r >= 6) return true;
      }
    }
    return false;
  }
}

class AI {
  static final _rand = Random();

  // ===== A. ムーブオーダリング =====
  // MVV-LVA: 取る手 > 成り > 打ち駒 > 静かな手 の順で探索
  static int _moveOrderScore(List<List<Piece?>> b, AMove mv) {
    if (mv.drop != null) {
      // 打ち駒: 価値の高い駒の打ちを優先
      return 200 + ((_val[mv.drop] ?? 0) ~/ 10);
    }
    final captured = b[mv.tr][mv.tc];
    if (captured != null) {
      // 取る手: MVV-LVA (取られる駒価値 高 - 取る駒価値 低) を優先
      final victimVal  = _val[captured.type] ?? 0;
      final piece      = b[mv.fr][mv.fc];
      final attackerVal = piece != null ? (_val[piece.type] ?? 0) : 0;
      return 10000 + victimVal * 10 - attackerVal;
    }
    if (mv.promote) return 800; // 成り手
    return 0;                   // 静かな手（最後に探索）
  }

  // 手をムーブオーダリングスコアでソート
  static List<AMove> _sortMoves(List<List<Piece?>> b, List<AMove> moves) {
    if (moves.length <= 1) return moves;
    final scored = moves.map((m) => (m, _moveOrderScore(b, m))).toList();
    scored.sort((a, z) => z.$2.compareTo(a.$2));
    return scored.map((e) => e.$1).toList();
  }

  // ===== B. 強化された評価関数 =====

  // 位置ボーナス（先手視点）
  static int _posBonus(PieceType t, int row, bool p1) {
    final rank = p1 ? (8 - row) : row; // 自陣=0, 敵陣=8
    switch (t) {
      case PieceType.pawn:
        return rank * 7; // 歩の前進を重視
      case PieceType.lance:
        return rank * 4;
      case PieceType.knight:
        return rank >= 2 ? rank * 5 : 0; // 桂は2段以上進んで価値あり
      case PieceType.silver:
        return rank * 3 + (rank >= 3 ? 10 : 0); // 敵陣侵入ボーナス
      case PieceType.gold:
        return rank * 2;
      case PieceType.bishop:
        return rank >= 3 ? (rank - 2) * 8 : 0; // 角は前線で強い
      case PieceType.rook:
        return rank >= 3 ? (rank - 2) * 8 : 0; // 飛は前線で強い
      case PieceType.king:
        return rank < 3 ? 25 : -(rank - 2) * 15; // 玉は自陣に留まる
      default:
        return rank * 3; // 成り駒の前進ボーナス
    }
  }

  // 玉の安全度（周囲の味方駒数 × 12点）
  static int _kingShield(List<List<Piece?>> b, bool p1) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p == null || p.type != PieceType.king || p.isPlayer1 != p1) continue;
        int shield = 0;
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            final r2 = r + dr, c2 = c + dc;
            if (r2 >= 0 && r2 < 9 && c2 >= 0 && c2 < 9) {
              final nb = b[r2][c2];
              if (nb != null && nb.isPlayer1 == p1) shield++;
            }
          }
        }
        return shield * 12;
      }
    }
    return -5000; // 玉がいない（詰み状態）
  }

  // 強化版盤面評価（先手視点、正=先手有利）
  static int eval(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
  ) {
    int score = 0;

    // 駒の価値 + 位置ボーナス
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p == null) continue;
        final base = _val[p.type] ?? 0;
        final pos  = _posBonus(p.type, r, p.isPlayer1);
        score += (p.isPlayer1 ? 1 : -1) * (base + pos);
      }
    }

    // 持ち駒の価値（盤上の85%）
    for (final e in p1h.entries)
      score += e.value * ((_val[e.key] ?? 0) * 0.85).round();
    for (final e in p2h.entries)
      score -= e.value * ((_val[e.key] ?? 0) * 0.85).round();

    // 玉の安全度（高速: O(1)で計算）
    score += _kingShield(b, true);
    score -= _kingShield(b, false);

    return score;
  }

  // ===== D. クワイエッサンス探索 =====
  // depth=0の時、取り合いが続く場合は延長探索して地平線効果を防ぐ
  static int _qSearch(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    int alpha,
    int beta,
    bool maximizing,
    bool aiIsP1,
    int qDepth,
  ) {
    // stand-pat: 現在の静的評価（取り合いを強制しない権利）
    final standPat = eval(b, p1h, p2h);

    if (maximizing) {
      if (standPat >= beta) return standPat; // β枝刈り
      if (standPat > alpha) alpha = standPat;
    } else {
      if (standPat <= alpha) return standPat; // α枝刈り
      if (standPat < beta)  beta  = standPat;
    }

    if (qDepth <= 0) return standPat;

    // 取る手と成り手のみ生成
    final currP1 = maximizing == aiIsP1 ? aiIsP1 : !aiIsP1;
    final tactical = allMoves(b, currP1, p1h, p2h).where((mv) =>
      mv.drop == null && (b[mv.tr][mv.tc] != null || mv.promote)
    ).toList();
    if (tactical.isEmpty) return standPat;

    // MVV-LVAで探索順をソート
    final sorted = _sortMoves(b, tactical);
    int val = standPat;

    for (final mv in sorted) {
      final next = apply(b, p1h, p2h, mv, currP1);
      final score = _qSearch(
        next.b, next.p1h, next.p2h,
        alpha, beta, !maximizing, aiIsP1, qDepth - 1,
      );
      if (maximizing) {
        val = max(val, score);
        alpha = max(alpha, val);
      } else {
        val = min(val, score);
        beta  = min(beta,  val);
      }
      if (beta <= alpha) break; // α-β枝刈り
    }
    return val;
  }

  // 全合法手を生成
  static List<AMove> allMoves(
    List<List<Piece?>> b,
    bool p1,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
  ) {
    final moves = <AMove>[];
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++) {
        final piece = b[r][c];
        if (piece == null || piece.isPlayer1 != p1) continue;
        for (final dest in GL.legal(b, r, c)) {
          bool inZ(int row) => p1 ? row <= 2 : row >= 6;
          final canPro = piece.canPromote && (inZ(r) || inZ(dest.$1));
          if (canPro && !piece.mustPromote(dest.$1)) {
            moves.add(AMove(fr: r, fc: c, tr: dest.$1, tc: dest.$2, promote: false));
            moves.add(AMove(fr: r, fc: c, tr: dest.$1, tc: dest.$2, promote: true));
          } else {
            moves.add(AMove(
              fr: r, fc: c, tr: dest.$1, tc: dest.$2,
              promote: piece.mustPromote(dest.$1),
            ));
          }
        }
      }
    final hand    = p1 ? p1h : p2h;
    final oppHand = p1 ? p2h : p1h;
    for (final type in hand.keys) {
      for (final sq in GL.dropSquares(b, type, p1, hand, oppHand)) {
        moves.add(AMove(fr: -1, fc: -1, tr: sq.$1, tc: sq.$2, drop: type));
      }
    }
    return moves;
  }

  // ムーブを適用してコピーを返す
  static ({
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
  }) apply(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    AMove mv,
    bool p1,
  ) {
    final nb   = GL.copy(b);
    final np1h = Map<PieceType, int>.from(p1h);
    final np2h = Map<PieceType, int>.from(p2h);
    if (mv.drop != null) {
      nb[mv.tr][mv.tc] = Piece(mv.drop!, p1);
      final h = p1 ? np1h : np2h;
      h[mv.drop!] = (h[mv.drop!] ?? 1) - 1;
      if (h[mv.drop!] == 0) h.remove(mv.drop!);
    } else {
      final piece = nb[mv.fr][mv.fc]!;
      final cap   = nb[mv.tr][mv.tc];
      if (cap != null) {
        final h  = p1 ? np1h : np2h;
        final bt = cap.baseType;
        h[bt] = (h[bt] ?? 0) + 1;
      }
      nb[mv.tr][mv.tc] = mv.promote
          ? Piece(piece.promotedType, piece.isPlayer1)
          : piece;
      nb[mv.fr][mv.fc] = null;
    }
    return (b: nb, p1h: np1h, p2h: np2h);
  }

  // メインエントリ: 最善手を返す（depth=0でランダム）
  static AMove? bestMove(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    bool aiIsP1,
    int depth,
  ) {
    final moves = allMoves(b, aiIsP1, p1h, p2h);
    if (moves.isEmpty) return null;
    if (depth == 0) {
      moves.shuffle(_rand);
      return moves.first;
    }

    // A: ムーブオーダリング適用（取る手・成り手を優先探索）
    final sortedMoves = _sortMoves(b, moves);

    AMove? best;
    int bestScore = aiIsP1 ? -999999 : 999999;

    for (final mv in sortedMoves) {
      final next  = apply(b, p1h, p2h, mv, aiIsP1);
      final score = _mm(
        next.b, next.p1h, next.p2h,
        depth - 1, -999999, 999999,
        !aiIsP1, aiIsP1,
      );
      final improved = aiIsP1 ? score > bestScore : score < bestScore;
      if (improved) {
        bestScore = score;
        best      = mv;
      } else if (score == bestScore && _rand.nextDouble() < 0.05) {
        // 同スコア時に5%の確率で差し替え（微小なランダム性）
        best = mv;
      }
    }
    return best;
  }

  // 上位 N 手を (move, score) のリストで返す
  static List<(AMove, int)> topMoves(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    bool aiIsP1,
    int depth, {
    int n = 3,
  }) {
    final moves = allMoves(b, aiIsP1, p1h, p2h);
    if (moves.isEmpty) return [];
    if (depth == 0) {
      moves.shuffle(_rand);
      return moves.take(n).map((m) => (m, 0)).toList();
    }
    final scored      = <(AMove, int)>[];
    final sortedMoves = _sortMoves(b, moves); // A: ムーブオーダリング
    for (final mv in sortedMoves) {
      final next  = apply(b, p1h, p2h, mv, aiIsP1);
      final score = _mm(next.b, next.p1h, next.p2h,
          depth - 1, -999999, 999999, !aiIsP1, aiIsP1);
      scored.add((mv, score));
    }
    scored.sort((a, b) => aiIsP1 ? b.$2 - a.$2 : a.$2 - b.$2);
    return scored.take(n).toList();
  }

  // A + D: ムーブオーダリング + クワイエッサンス統合ミニマックス
  static int _mm(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    int depth,
    int alpha,
    int beta,
    bool maximizing,
    bool aiIsP1,
  ) {
    if (depth == 0) {
      // D: クワイエッサンス探索（最大2手で速度改善・品質はほぼ維持）
      return _qSearch(b, p1h, p2h, alpha, beta, maximizing, aiIsP1, 2);
    }

    final currP1 = maximizing == aiIsP1 ? aiIsP1 : !aiIsP1;
    final moves  = allMoves(b, currP1, p1h, p2h);
    if (moves.isEmpty) {
      return GL.inCheck(b, currP1) ? (maximizing ? -99999 : 99999) : 0;
    }

    // A: ムーブオーダリング（枝刈り効率を2〜4倍向上）
    final sortedMoves = _sortMoves(b, moves);

    int val = maximizing ? -999999 : 999999;
    for (final mv in sortedMoves) {
      final next  = apply(b, p1h, p2h, mv, currP1);
      final child = _mm(
        next.b, next.p1h, next.p2h,
        depth - 1, alpha, beta,
        !maximizing, aiIsP1,
      );
      if (maximizing) {
        val   = max(val, child);
        alpha = max(alpha, val);
      } else {
        val  = min(val, child);
        beta = min(beta,  val);
      }
      if (beta <= alpha) break; // α-β枝刈り
    }
    return val;
  }
}
