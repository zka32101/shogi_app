// lib/network_game_service.dart — Firebase Realtime DB を使ったネットワーク対局
import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'piece.dart';

/// Firebase Realtime DB 構造:
/// /rooms/{6桁コード}/
///   status: 'waiting' | 'playing' | 'ended'
///   createdAt: timestamp
///   moves/
///     {pushKey}/
///       fr, fc, tr, tc: int  (-1 = 打ち駒)
///       promote: bool
///       drop: int? (PieceType.index)
///       isP1: bool
///       ts: timestamp
///   result: 'p1win' | 'p2win' | 'draw' | null
///   resignedBy: 'p1' | 'p2' | null
///
/// /matchmaking/{pushKey}/
///   status: 'waiting' | 'matched'
///   roomCode: null | string
///   userId: string
///   createdAt: timestamp
class NetworkGameService {
  NetworkGameService._();

  /// Firebase が正常に初期化されているか
  static bool _firebaseReady = false;
  static void setFirebaseReady() => _firebaseReady = true;
  static bool get firebaseReady => _firebaseReady;

  static String? _roomCode;
  static bool _isHost = false;
  static bool _isSpectator = false;
  static bool _hostIsP1 = true;
  static StreamSubscription? _moveSub;
  static StreamSubscription? _statusSub;
  static StreamSubscription? _reactionSub;
  static int _lastMoveCount = 0;

  // ストリーム（相手の指し手 / 状態変化 / 絵文字リアクション）
  static final _moveCtrl   = StreamController<AMove>.broadcast();
  static final _statusCtrl = StreamController<NetworkStatus>.broadcast();
  static final _emojiCtrl  = StreamController<ReceivedEmoji>.broadcast();

  static Stream<AMove>          get moveStream   => _moveCtrl.stream;
  static Stream<NetworkStatus>  get statusStream => _statusCtrl.stream;
  static Stream<ReceivedEmoji>  get emojiStream  => _emojiCtrl.stream;

  // マッチング用
  static StreamSubscription? _matchWatchSub;
  static String?              _myMatchKey;

  static String? get roomCode     => _roomCode;
  static bool    get isHost       => _isHost;
  static bool    get isSpectator  => _isSpectator;
  static bool    get hostIsP1     => _hostIsP1;

  // ─── ランダムマッチング ──────────────────────────────────────────────────────
  /// 不特定多数との対戦マッチング
  /// [myRating] 自分の現在レーティング（強さフィルタに使用）
  /// [strengthPref] 'weak' | 'any' | 'strong'
  /// 戻り値: MatchResult（roomCode + isHost）
  /// 60秒以内にマッチしない場合 TimeoutException
  static Future<MatchResult> startMatchmaking({
    int myRating = 1000,
    String strengthPref = 'any',
    bool rated = true,
  }) async {
    if (!_firebaseReady) {
      throw Exception('Firebase が設定されていません。\nfirebase_options.dart の設定を確認してください。');
    }
    cancelMatchmaking();
    final myId  = _generateUserId();
    final mqRef = FirebaseDatabase.instance.ref('matchmaking');

    // ── 古いエントリ（3分超）を掃除 ─────────────────────────────────────────
    try {
      final cutoff = DateTime.now()
          .subtract(const Duration(minutes: 3))
          .millisecondsSinceEpoch;
      final oldSnap = await mqRef
          .orderByChild('createdAt')
          .endAt(cutoff)
          .get();
      if (oldSnap.exists) {
        for (final child in oldSnap.children) {
          await child.ref.remove();
        }
      }
    } catch (_) {}

    // ── 待機中エントリを探して Atomic クレーム ────────────────────────────────
    try {
      final waitSnap = await mqRef
          .orderByChild('status')
          .equalTo('waiting')
          .limitToFirst(5) // 複数取って 1 つ以上クレームできるまで試みる
          .get();

      if (waitSnap.exists) {
        for (final entry in waitSnap.children) {
          // 自分が以前残したエントリはスキップ
          final entryData = entry.value as Map?;
          final entryUserId = entryData?['userId'];
          if (entryUserId == myId) continue;

          // 強さフィルタチェック
          final entryRating = (entryData?['rating'] as num?)?.toInt() ?? 1000;
          if (strengthPref == 'weak'   && entryRating > myRating + 50) continue;
          if (strengthPref == 'strong' && entryRating < myRating - 50) continue;

          // Atomic に status を 'matched' にする
          bool claimed = false;
          try {
            final txResult = await entry.ref.runTransaction((current) {
              if (current == null) return Transaction.abort();
              final data = Map<String, dynamic>.from(current as Map);
              if (data['status'] != 'waiting') return Transaction.abort();
              data['status'] = 'matched_pending';
              data['matchedBy'] = myId;
              return Transaction.success(data);
            });
            claimed = txResult.committed;
          } catch (_) {}

          if (!claimed) continue;

          // クレーム成功 → ルーム作成してエントリに roomCode を書き込む
          final code = await _createRoomInternal();
          await entry.ref.update({'roomCode': code, 'status': 'matched'});

          // 自分もルームを購読（ホスト = P1）
          _isHost = true;
          _subscribeRoom(code);
          return MatchResult(roomCode: code, isHost: true);
        }
      }
    } catch (_) {}

    // ── 自分を待機キューに追加 ────────────────────────────────────────────────
    final myRef = mqRef.push();
    _myMatchKey = myRef.key;
    await myRef.set({
      'userId':       myId,
      'status':       'waiting',
      'createdAt':    ServerValue.timestamp,
      'roomCode':     null,
      'rating':       myRating,
      'strengthPref': strengthPref,
      'rated':        rated,
    });

    // ── ルームコードが届くのを待つ ────────────────────────────────────────────
    final completer = Completer<MatchResult>();
    _matchWatchSub = myRef.onValue.listen((event) {
      if (completer.isCompleted) return;
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      final status   = data['status'] as String?;
      final roomCode = data['roomCode'] as String?;
      if ((status == 'matched' || status == 'matched_pending') &&
          roomCode != null) {
        _matchWatchSub?.cancel();
        // 自分はゲスト（P2/後手）
        _isHost = false;
        _roomCode = roomCode;
        _lastMoveCount = 0;
        _subscribeRoom(roomCode);
        completer.complete(MatchResult(roomCode: roomCode, isHost: false));
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        cancelMatchmaking();
        throw TimeoutException('マッチングがタイムアウトしました', const Duration(seconds: 60));
      },
    );
  }

  /// マッチングをキャンセル（自分のエントリを削除）
  static Future<void> cancelMatchmaking() async {
    _matchWatchSub?.cancel();
    _matchWatchSub = null;
    if (_myMatchKey != null) {
      try {
        await FirebaseDatabase.instance
            .ref('matchmaking/$_myMatchKey')
            .remove();
      } catch (_) {}
      _myMatchKey = null;
    }
  }

  // ルームだけを内部作成（dispose を呼ばない版）
  static Future<String> _createRoomInternal() async {
    _lastMoveCount = 0;
    final code = await _uniqueCode();
    await FirebaseDatabase.instance.ref('rooms/$code').set({
      'status':    'playing', // マッチング済みなので即 playing
      'createdAt': ServerValue.timestamp,
    });
    _roomCode = code;
    return code;
  }

  // ランダムユーザーID（セッション内一意）
  static String _generateUserId() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(36).toRadixString(36)).join();
  }

  // ─── ルーム作成（先後はランダム決定）────────────────────────────────────────
  static Future<String> createRoom() async {
    if (!_firebaseReady) {
      throw Exception('Firebase が設定されていません。\nfirebase_options.dart の設定を確認してください。');
    }
    dispose(); // 既存セッションをクリア
    _hostIsP1 = Random().nextBool(); // ランダムで先後決定
    _isHost = true;
    _lastMoveCount = 0;
    final code = await _uniqueCode();
    await FirebaseDatabase.instance.ref('rooms/$code').set({
      'status':    'waiting',
      'createdAt': ServerValue.timestamp,
      'hostIsP1':  _hostIsP1,
    });
    _roomCode = code;
    _subscribeRoom(code);
    return code;
  }

  // ─── ルーム参加（ゲスト）──────────────────────────────────────────────────
  static Future<JoinResult> joinRoom(String code) async {
    if (!_firebaseReady) return JoinResult.error;
    dispose();
    _isHost = false;
    _lastMoveCount = 0;
    final code6 = code.trim();
    final ref  = FirebaseDatabase.instance.ref('rooms/$code6');
    try {
      final snap = await ref.get();
      if (!snap.exists) return JoinResult.notFound;
      final data = snap.value as Map?;
      if (data == null) return JoinResult.notFound;
      final status = data['status'] as String?;
      if (status == 'playing' || status == 'ended') return JoinResult.full;
      // ホストの先後を取得して、ゲストは逆
      _hostIsP1 = (data['hostIsP1'] as bool?) ?? true;
    } catch (_) {
      return JoinResult.error;
    }
    try {
      await ref.update({'status': 'playing'});
    } catch (_) {
      return JoinResult.error;
    }
    _roomCode = code6;
    _subscribeRoom(code6);
    return JoinResult.ok;
  }

  // ─── 観戦参加 ──────────────────────────────────────────────────────────────
  static Future<JoinResult> joinAsSpectator(String code) async {
    if (!_firebaseReady) return JoinResult.error;
    dispose();
    _isHost = false;
    _isSpectator = true;
    _lastMoveCount = 0;
    final code6 = code.trim();
    final ref = FirebaseDatabase.instance.ref('rooms/$code6');
    try {
      final snap = await ref.get();
      if (!snap.exists) return JoinResult.notFound;
      final data = snap.value as Map?;
      if (data == null) return JoinResult.notFound;
      final status = data['status'] as String?;
      if (status == 'ended') return JoinResult.full; // ended = 終了済み
    } catch (_) {
      return JoinResult.error;
    }
    _roomCode = code6;
    _subscribeRoom(code6);
    return JoinResult.ok;
  }

  // ─── 絵文字リアクション送信 ────────────────────────────────────────────────
  static Future<void> sendEmoji(String emoji, {required bool isP1}) async {
    if (!_firebaseReady || _roomCode == null) return;
    await FirebaseDatabase.instance
        .ref('rooms/$_roomCode/reactions')
        .push()
        .set({'emoji': emoji, 'isP1': isP1, 'ts': ServerValue.timestamp});
  }

  // ─── 指し手送信 ─────────────────────────────────────────────────────────────
  static Future<void> sendMove(AMove mv, {required bool isP1}) async {
    if (_roomCode == null) return;
    await FirebaseDatabase.instance
        .ref('rooms/$_roomCode/moves')
        .push()
        .set(_encodeMove(mv, isP1: isP1));
  }

  // ─── 投了 ─────────────────────────────────────────────────────────────────
  static Future<void> resign({required bool isP1}) async {
    if (_roomCode == null) return;
    await FirebaseDatabase.instance.ref('rooms/$_roomCode').update({
      'status':     'ended',
      'result':     isP1 ? 'p2win' : 'p1win',
      'resignedBy': isP1 ? 'p1' : 'p2',
    });
  }

  // ─── アクティブな対局一覧取得 ─────────────────────────────────────────────
  /// 現在プレイ中のルーム一覧を取得（最大20件）
  static Future<List<Map<String, dynamic>>> getActiveRooms() async {
    if (!_firebaseReady) return [];
    try {
      final snap = await FirebaseDatabase.instance
          .ref('rooms')
          .limitToLast(20)
          .get();
      if (!snap.exists) return [];
      final data = snap.value as Map<dynamic, dynamic>?;
      if (data == null) return [];
      final rooms = <Map<String, dynamic>>[];
      data.forEach((key, value) {
        final v = value as Map<dynamic, dynamic>?;
        if (v != null && v['status'] == 'playing') {
          final moveCount = (v['moves'] as Map?)?.length ?? 0;
          rooms.add({
            'code': key as String,
            'moveCount': moveCount,
            'createdAt': v['createdAt'] ?? 0,
          });
        }
      });
      // 作成日時降順でソート
      rooms.sort((a, b) => (b['createdAt'] as int).compareTo(a['createdAt'] as int));
      return rooms;
    } catch (_) {
      return [];
    }
  }

  // ─── 解放 ─────────────────────────────────────────────────────────────────
  static void dispose() {
    _moveSub?.cancel();
    _statusSub?.cancel();
    _reactionSub?.cancel();
    _matchWatchSub?.cancel();
    _moveSub = null;
    _statusSub = null;
    _reactionSub = null;
    _matchWatchSub = null;
    _myMatchKey = null;
    _roomCode = null;
    _lastMoveCount = 0;
    _isSpectator = false;
    _hostIsP1 = true;
  }

  // ─── 内部: ルーム購読 ────────────────────────────────────────────────────
  static void _subscribeRoom(String code) {
    final ref = FirebaseDatabase.instance.ref('rooms/$code');

    // ステータス変化
    _statusSub = ref.onValue.listen((event) {
      if (!event.snapshot.exists) return;
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      final status = data['status'] as String?;
      switch (status) {
        case 'playing':
          _statusCtrl.add(NetworkStatus.playing);
        case 'ended':
          final resignedBy = data['resignedBy'] as String?;
          final result     = data['result'] as String?;
          if (resignedBy != null) {
            // 相手が投了
            final opponentResigned =
                (_isHost && resignedBy == 'p2') ||
                (!_isHost && resignedBy == 'p1');
            if (opponentResigned) {
              _statusCtrl.add(NetworkStatus.opponentResigned);
            }
          } else if (result != null) {
            _statusCtrl.add(NetworkStatus.ended);
          }
        case 'waiting':
          break;
      }
    });

    // 絵文字リアクション（onChildAdded で新着のみ受信）
    _reactionSub = ref.child('reactions').onChildAdded.listen((event) {
      if (!event.snapshot.exists) return;
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      final emoji = data['emoji'] as String?;
      final isP1  = data['isP1'] as bool? ?? true;
      if (emoji == null) return;
      // 対局モード: 自分が送ったリアクションはスキップ
      if (!_isSpectator) {
        final isMine = (_isHost && isP1) || (!_isHost && !isP1);
        if (isMine) return;
      }
      _emojiCtrl.add(ReceivedEmoji(emoji: emoji, isP1: isP1));
    });

    // 指し手リスト
    _moveSub = ref.child('moves').onValue.listen((event) {
      if (!event.snapshot.exists) return;
      final raw = event.snapshot.value;
      final moves = _extractMoves(raw);
      for (int i = _lastMoveCount; i < moves.length; i++) {
        final m      = moves[i];
        final isP1   = m['isP1'] as bool? ?? true;
        // 観戦モード: すべての手を転送。対局モード: 自分の手はスキップ
        if (!_isSpectator) {
          final isMine = (_isHost && isP1) || (!_isHost && !isP1);
          if (isMine) continue;
        }
        final mv = _decodeMove(m);
        if (mv != null) _moveCtrl.add(mv);
      }
      _lastMoveCount = moves.length;
    });
  }

  // ─── 内部: moves を List<Map> に正規化 ──────────────────────────────────
  static List<Map> _extractMoves(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.whereType<Map>().toList();
    }
    if (raw is Map) {
      final keys = raw.keys.toList()
        ..sort((a, b) {
          // Firebase push key は時系列順
          return a.toString().compareTo(b.toString());
        });
      return keys.map((k) => raw[k]).whereType<Map>().toList();
    }
    return [];
  }

  // ─── 内部: AMove ↔ Map ──────────────────────────────────────────────────
  static Map<String, dynamic> _encodeMove(AMove mv, {required bool isP1}) => {
    'fr':      mv.fr,
    'fc':      mv.fc,
    'tr':      mv.tr,
    'tc':      mv.tc,
    'promote': mv.promote,
    'drop':    mv.drop?.index,
    'isP1':    isP1,
    'ts':      ServerValue.timestamp,
  };

  static AMove? _decodeMove(Map m) {
    try {
      final fr      = (m['fr'] as num).toInt();
      final fc      = (m['fc'] as num).toInt();
      final tr      = (m['tr'] as num).toInt();
      final tc      = (m['tc'] as num).toInt();
      final promote = m['promote'] as bool? ?? false;
      final dropIdx = m['drop'];
      final drop    = dropIdx != null
          ? PieceType.values[(dropIdx as num).toInt()]
          : null;
      return AMove(fr: fr, fc: fc, tr: tr, tc: tc, promote: promote, drop: drop);
    } catch (_) {
      return null;
    }
  }

  // ─── 内部: 重複しないコード生成 ──────────────────────────────────────────
  static Future<String> _uniqueCode() async {
    final rng = Random.secure();
    for (int i = 0; i < 5; i++) {
      final code = List.generate(6, (_) => rng.nextInt(10).toString()).join();
      final snap = await FirebaseDatabase.instance.ref('rooms/$code').get();
      if (!snap.exists) return code;
    }
    return List.generate(6, (_) => rng.nextInt(10).toString()).join();
  }
}

enum NetworkStatus { playing, opponentResigned, ended }

enum JoinResult { ok, notFound, full, error }

class MatchResult {
  final String roomCode;
  final bool   isHost; // true=P1/先手  false=P2/後手
  const MatchResult({required this.roomCode, required this.isHost});
}

class ReceivedEmoji {
  final String emoji;
  final bool   isP1;
  const ReceivedEmoji({required this.emoji, required this.isP1});
}
