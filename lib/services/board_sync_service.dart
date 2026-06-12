// lib/services/board_sync_service.dart
// 盤面状態の Firestore 同期・シリアライズ

import 'package:cloud_firestore/cloud_firestore.dart';
import '../piece.dart';
import '../logic.dart';
import 'fcm_service.dart';

/// Firestore 上の盤面状態フォーマット
/// board: List<List<Map?>> — 9×9, 各セルは null or {"t":int,"p":bool}
/// p1_hand / p2_hand: Map<String,int> — 持ち駒（"0"=pawn... など PieceType index）
/// move: {"fr":int,"fc":int,"tr":int,"tc":int,"drop":int?,"promote":bool}

class BoardSyncService {
  static final BoardSyncService _instance = BoardSyncService._internal();
  factory BoardSyncService() => _instance;
  BoardSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FcmService _fcmService = FcmService();

  // ── シリアライズ ──────────────────────────────────────────

  /// 盤面 → JSON (Firestore 保存用)
  static List<List<Map<String, dynamic>?>> boardToJson(
      List<List<Piece?>> board) {
    return board.map((row) {
      return row.map((piece) {
        if (piece == null) return null;
        return {'t': piece.type.index, 'p': piece.isPlayer1};
      }).toList();
    }).toList();
  }

  /// JSON → 盤面
  static List<List<Piece?>> boardFromJson(List<dynamic> json) {
    return json.map<List<Piece?>>((row) {
      return (row as List<dynamic>).map<Piece?>((cell) {
        if (cell == null) return null;
        final map = cell as Map<String, dynamic>;
        return Piece(
          PieceType.values[map['t'] as int],
          map['p'] as bool,
        );
      }).toList();
    }).toList();
  }

  /// 持ち駒 → JSON
  static Map<String, int> handToJson(Map<PieceType, int> hand) {
    return hand.map((k, v) => MapEntry(k.index.toString(), v));
  }

  /// JSON → 持ち駒
  static Map<PieceType, int> handFromJson(Map<String, dynamic>? json) {
    if (json == null) return {};
    return Map.fromEntries(
      json.entries.map((e) =>
          MapEntry(PieceType.values[int.parse(e.key)], e.value as int)),
    );
  }

  /// KifuMove → JSON (指し手ログ用)
  static Map<String, dynamic> moveToJson(KifuMove move) {
    return {
      'n': move.num,
      'p1': move.p1,
      'fr': move.fr,
      'fc': move.fc,
      'tr': move.tr,
      'tc': move.tc,
      'drop': move.drop?.index,
      'promote': move.promote,
      'note': move.note,
    };
  }

  /// JSON → KifuMove
  static KifuMove moveFromJson(Map<String, dynamic> json) {
    return KifuMove(
      json['n'] as int,
      json['p1'] as bool,
      json['note'] as String? ?? '',
      fr: json['fr'] as int? ?? -1,
      fc: json['fc'] as int? ?? -1,
      tr: json['tr'] as int,
      tc: json['tc'] as int,
      drop: json['drop'] != null
          ? PieceType.values[json['drop'] as int]
          : null,
      promote: json['promote'] as bool? ?? false,
    );
  }

  // ── Firestore 操作 ──────────────────────────────────────────

  /// 初期盤面を Firestore に書き込む
  Future<void> initMatchBoard(String matchId) async {
    try {
      final board = GL.initialBoard();
      final boardJson = boardToJson(board);

      await _firestore.collection('matches').doc(matchId).update({
        'board': boardJson,
        'p1_hand': {},
        'p2_hand': {},
        'moves': [],
        'current_turn': 1, // 先手
      });
    } catch (e) {
      print('Init match board error: $e');
    }
  }

  /// 指し手を適用して Firestore に保存
  Future<void> applyMove({
    required String matchId,
    required List<List<Piece?>> currentBoard,
    required Map<PieceType, int> p1Hand,
    required Map<PieceType, int> p2Hand,
    required KifuMove move,
    required bool isPlayer1Turn,
  }) async {
    try {
      // ローカルで盤面更新
      final newBoard = GL.copy(currentBoard);
      final newP1Hand = Map<PieceType, int>.from(p1Hand);
      final newP2Hand = Map<PieceType, int>.from(p2Hand);
      GL.applyKifuMove(newBoard, newP1Hand, newP2Hand, move);

      final boardJson = boardToJson(newBoard);
      final moveJson = moveToJson(move);

      // Firestore に保存 (トランザクション)
      await _firestore.runTransaction((tx) async {
        final doc =
            await tx.get(_firestore.collection('matches').doc(matchId));
        if (!doc.exists) throw Exception('Match not found');

        final moves = (doc['moves'] as List? ?? []);
        moves.add(moveJson);

        tx.update(_firestore.collection('matches').doc(matchId), {
          'board': boardJson,
          'p1_hand': handToJson(newP1Hand),
          'p2_hand': handToJson(newP2Hand),
          'moves': moves,
          'current_turn': isPlayer1Turn ? 2 : 1, // ターン交代
        });
      });

      // ✅ FCM通知：相手のターンになったことを通知
      Future.microtask(() async {
        try {
          final matchDoc = await _firestore.collection('matches').doc(matchId).get();
          if (!matchDoc.exists) return;
          final data = matchDoc.data()!;
          // 次のプレイヤー（今動かしたのと逆）に通知
          final recipientId = isPlayer1Turn
              ? data['player2_id'] as String?
              : data['player1_id'] as String?;
          final senderName = isPlayer1Turn
              ? data['player1_name'] as String? ?? '相手'
              : data['player2_name'] as String? ?? '相手';
          if (recipientId != null) {
            await _fcmService.notifyOpponentMoved(
              recipientId: recipientId,
              opponentName: senderName,
              matchId: matchId,
              moveNotation: '${isPlayer1Turn ? "▲" : "△"}${move.tr + 1}${move.tc + 1}',
            );
          }
        } catch (_) {}
      });
    } catch (e) {
      print('Apply move error: $e');
      rethrow;
    }
  }

  /// 盤面状態をリアルタイム監視
  Stream<NetworkBoardState?> watchBoardState(String matchId) {
    return _firestore
        .collection('matches')
        .doc(matchId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()!;

      try {
        final boardRaw = data['board'] as List?;
        if (boardRaw == null) return null;

        final board = boardFromJson(boardRaw);
        final p1Hand = handFromJson(
            (data['p1_hand'] as Map?)?.cast<String, dynamic>());
        final p2Hand = handFromJson(
            (data['p2_hand'] as Map?)?.cast<String, dynamic>());
        final currentTurn = data['current_turn'] as int? ?? 1;
        final status = data['status'] as String? ?? 'playing';
        final winner = data['winner'] as String?;
        final movesRaw = data['moves'] as List? ?? [];
        final moves = movesRaw
            .map((m) => moveFromJson((m as Map).cast<String, dynamic>()))
            .toList();

        return NetworkBoardState(
          board: board,
          p1Hand: p1Hand,
          p2Hand: p2Hand,
          currentTurn: currentTurn,
          status: status,
          winner: winner,
          moves: moves,
        );
      } catch (e) {
        print('Parse board state error: $e');
        return null;
      }
    });
  }

  // ── 詰み判定 ──────────────────────────────────────────

  /// 詰みかどうかをチェック
  bool isCheckmate(
    List<List<Piece?>> board,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
    bool isCurrentPlayerP1,
  ) {
    if (!GL.inCheck(board, isCurrentPlayerP1)) return false;
    return !GL.hasLegalMove(board, isCurrentPlayerP1,
        isCurrentPlayerP1 ? p1Hand : p2Hand);
  }
}

/// ネットワーク対局の盤面状態
class NetworkBoardState {
  final List<List<Piece?>> board;
  final Map<PieceType, int> p1Hand;
  final Map<PieceType, int> p2Hand;
  final int currentTurn; // 1=先手, 2=後手
  final String status; // playing, finished, cancelled
  final String? winner;
  final List<KifuMove> moves;

  NetworkBoardState({
    required this.board,
    required this.p1Hand,
    required this.p2Hand,
    required this.currentTurn,
    required this.status,
    this.winner,
    this.moves = const [],
  });

  bool get isFinished => status == 'finished' || status == 'cancelled';
  int get moveCount => moves.length;
}
