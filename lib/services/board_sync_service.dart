// lib/services/board_sync_service.dart — Realtime Database版（スケーリング対応）
// Firestore → RTDB に移行して書き込み頻度・コストを大幅削減
import 'package:firebase_database/firebase_database.dart';
import '../piece.dart';
import '../logic.dart';

// ── 盤面状態コンテナ ─────────────────────────────────────────────
class NetworkBoardState {
  final List<List<Piece?>> board;
  final Map<PieceType, int> p1Hand;
  final Map<PieceType, int> p2Hand;
  final int currentTurn; // 1=先手, 2=後手
  final List<KifuMove> moves;
  final String? winnerId;
  final String? result;
  final String status; // 'active' | 'finished' | 'abandoned'

  // 時計情報（ミリ秒）
  final int p1Ms;
  final int p2Ms;
  final int lastTickMs;
  final int lastTurn;

  const NetworkBoardState({
    required this.board,
    required this.p1Hand,
    required this.p2Hand,
    required this.currentTurn,
    required this.moves,
    this.winnerId,
    this.result,
    this.status = 'active',
    this.p1Ms = 600000,
    this.p2Ms = 600000,
    this.lastTickMs = 0,
    this.lastTurn = 1,
  });
}

// ── BoardSyncService ────────────────────────────────────────────
class BoardSyncService {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  DatabaseReference _gameRef(String matchId) =>
      _rtdb.ref('games/$matchId');

  // ──────────────── シリアライズ ────────────────────────────────

  static List<List<Piece?>> boardFromJson(dynamic data) {
    if (data == null) return _emptyBoard();
    try {
      final rows = data as List;
      return List.generate(9, (r) {
        final row = r < rows.length ? rows[r] as List? : null;
        if (row == null) return List<Piece?>.filled(9, null);
        return List.generate(9, (c) {
          final cell = c < row.length ? row[c] : null;
          if (cell == null) return null;
          final t  = cell['t']  as int?  ?? 0;
          final p1 = cell['p1'] as bool? ?? true;
          if (t < 0 || t >= PieceType.values.length) return null;
          return Piece(PieceType.values[t], p1);
        });
      });
    } catch (_) {
      return _emptyBoard();
    }
  }

  static List<List<Piece?>> _emptyBoard() =>
      List.generate(9, (_) => List<Piece?>.filled(9, null));

  static List<List<dynamic>> boardToJson(List<List<Piece?>> board) =>
      board.map((row) => row.map((p) {
        if (p == null) return null;
        return {'t': p.type.index, 'p1': p.isPlayer1};
      }).toList()).toList();

  static Map<String, int> handToJson(Map<PieceType, int> hand) =>
      hand.map((k, v) => MapEntry(k.index.toString(), v));

  static Map<PieceType, int> handFromJson(dynamic data) {
    if (data == null) return {};
    try {
      final map = Map<String, dynamic>.from(data as Map);
      final result = <PieceType, int>{};
      map.forEach((k, v) {
        final idx = int.tryParse(k) ?? -1;
        if (idx >= 0 && idx < PieceType.values.length) {
          result[PieceType.values[idx]] = (v as int?) ?? 0;
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  static Map<String, dynamic> moveToJson(KifuMove m) => {
    'n':       m.num,
    'p1':      m.p1,
    'note':    m.note,
    'fr':      m.fr,
    'fc':      m.fc,
    'tr':      m.tr,
    'tc':      m.tc,
    'drop':    m.drop?.index,
    'promote': m.promote,
  };

  static KifuMove? moveFromJson(dynamic data) {
    if (data == null) return null;
    try {
      final m       = Map<String, dynamic>.from(data as Map);
      final dropIdx = m['drop'] as int?;
      return KifuMove(
        m['n']    as int?    ?? 0,
        m['p1']   as bool?   ?? true,
        m['note'] as String? ?? '',
        fr:      m['fr'] as int? ?? -1,
        fc:      m['fc'] as int? ?? -1,
        tr:      m['tr'] as int? ?? -1,
        tc:      m['tc'] as int? ?? -1,
        drop:    dropIdx != null && dropIdx >= 0 && dropIdx < PieceType.values.length
                   ? PieceType.values[dropIdx] : null,
        promote: m['promote'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  // ──────────────── RTDB書き込み ────────────────────────────────

  /// 対局開始時: 初期盤面をRTDBに書き込む
  Future<void> initMatchBoard(
    String matchId, {
    List<List<Piece?>>? board,
    Map<PieceType, int>? p1Hand,
    Map<PieceType, int>? p2Hand,
    String? player1Id,
    String? player2Id,
    int timeLimitSec = 600,
  }) async {
    final b  = board  ?? List.generate(9, (_) => List<Piece?>.filled(9, null));
    final h1 = p1Hand ?? <PieceType, int>{};
    final h2 = p2Hand ?? <PieceType, int>{};
    final timeMs = timeLimitSec * 1000;
    await _gameRef(matchId).set({
      'board':        boardToJson(b),
      'p1_hand':      handToJson(h1),
      'p2_hand':      handToJson(h2),
      'current_turn': 1,
      'status':       'active',
      'player1_id':   player1Id ?? '',
      'player2_id':   player2Id ?? '',
      'last_activity_ms': ServerValue.timestamp,
      'clock': {
        'p1_ms':       timeMs,
        'p2_ms':       timeMs,
        'last_tick_ms': ServerValue.timestamp,
        'last_turn':   1,
      },
    });
  }

  /// 指し手適用: マルチパス更新でアトミックに書き込む（Firestoreトランザクション不要）
  Future<void> applyMove({
    required String matchId,
    required List<List<Piece?>> newBoard,
    required Map<PieceType, int> newP1Hand,
    required Map<PieceType, int> newP2Hand,
    required int nextTurn,
    required KifuMove move,
    int remainingMsForCurrentPlayer = 600000,
  }) async {
    final moveRef = _gameRef(matchId).child('moves').push();
    // 直前に指したプレイヤーのクロックキーを更新
    final clockKey = nextTurn == 1 ? 'p2_ms' : 'p1_ms';

    await _rtdb.ref().update({
      'games/$matchId/board':              boardToJson(newBoard),
      'games/$matchId/p1_hand':            handToJson(newP1Hand),
      'games/$matchId/p2_hand':            handToJson(newP2Hand),
      'games/$matchId/current_turn':       nextTurn,
      'games/$matchId/last_activity_ms':   ServerValue.timestamp,
      moveRef.path:                        moveToJson(move),
      'games/$matchId/clock/$clockKey':    remainingMsForCurrentPlayer,
      'games/$matchId/clock/last_tick_ms': ServerValue.timestamp,
      'games/$matchId/clock/last_turn':    nextTurn,
    });
  }

  /// 持ち時間を定期同期（30秒毎 — 1秒毎のFirestore書き込みを廃止）
  Future<void> syncClock({
    required String matchId,
    required int p1Ms,
    required int p2Ms,
    required int currentTurn,
  }) async {
    await _gameRef(matchId).child('clock').update({
      'p1_ms':        p1Ms,
      'p2_ms':        p2Ms,
      'last_tick_ms': ServerValue.timestamp,
      'last_turn':    currentTurn,
    });
  }

  /// 試合終了をRTDBに書き込み（Firestoreトリガー経由でELO更新）
  Future<void> finishGame({
    required String matchId,
    required String? winnerId,
    required String result,
  }) async {
    await _gameRef(matchId).update({
      'status':      'finished',
      'result':      result,
      'winner_id':   winnerId,
      'finished_at': ServerValue.timestamp,
    });
  }

  // ──────────────── ストリーム ──────────────────────────────────

  /// 盤面状態をリアルタイムストリームで取得（RTDB版）
  Stream<NetworkBoardState?> watchBoardState(String matchId) {
    return _gameRef(matchId).onValue.map((event) {
      try {
        final raw = event.snapshot.value;
        if (raw == null) return null;
        final data = Map<String, dynamic>.from(raw as Map);

        final board       = boardFromJson(data['board']);
        final p1Hand      = handFromJson(data['p1_hand']);
        final p2Hand      = handFromJson(data['p2_hand']);
        final currentTurn = data['current_turn'] as int? ?? 1;
        final status      = data['status']       as String? ?? 'active';
        final winnerId    = data['winner_id']    as String?;
        final result      = data['result']       as String?;

        // 時計
        final clock      = data['clock'] != null
            ? Map<String, dynamic>.from(data['clock'] as Map) : <String, dynamic>{};
        final p1Ms       = clock['p1_ms']       as int? ?? 600000;
        final p2Ms       = clock['p2_ms']       as int? ?? 600000;
        final lastTickMs = clock['last_tick_ms'] as int? ?? 0;
        final lastTurn   = clock['last_turn']   as int? ?? 1;

        // 指し手履歴（pushキー順でソート）
        final moves = <KifuMove>[];
        final movesRaw = data['moves'];
        if (movesRaw != null) {
          final movesMap = Map<String, dynamic>.from(movesRaw as Map);
          final entries = movesMap.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));
          for (final e in entries) {
            final m = moveFromJson(e.value);
            if (m != null) moves.add(m);
          }
        }

        return NetworkBoardState(
          board:       board,
          p1Hand:      p1Hand,
          p2Hand:      p2Hand,
          currentTurn: currentTurn,
          moves:       moves,
          winnerId:    winnerId,
          result:      result,
          status:      status,
          p1Ms:        p1Ms,
          p2Ms:        p2Ms,
          lastTickMs:  lastTickMs,
          lastTurn:    lastTurn,
        );
      } catch (_) {
        return null;
      }
    });
  }

  // ──────────────── ゲームロジック補助 ─────────────────────────

  bool isCheckmate(
    List<List<Piece?>> board,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
    bool opponentIsP1,
  ) {
    final hand    = opponentIsP1 ? p1Hand : p2Hand;
    final oppHand = opponentIsP1 ? p2Hand : p1Hand;
    return GL.inCheck(board, opponentIsP1) &&
        !GL.hasLegalMove(board, opponentIsP1, hand, oppHand);
  }
}
