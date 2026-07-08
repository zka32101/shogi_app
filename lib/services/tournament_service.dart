// lib/services/tournament_service.dart
// トーナメントシステム（シングルエリミネーション）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'network_achievement_service.dart';

// ── モデル ──────────────────────────────────────────────────

class TournamentEntry {
  final String userId;
  final String username;
  final int rating;

  TournamentEntry(
      {required this.userId, required this.username, required this.rating});

  Map<String, dynamic> toJson() =>
      {'user_id': userId, 'username': username, 'rating': rating};

  factory TournamentEntry.fromJson(Map<String, dynamic> j) =>
      TournamentEntry(
        userId: j['user_id'] as String,
        username: j['username'] as String? ?? '?',
        rating: j['rating'] as int? ?? 1500,
      );
}

class TournamentMatch {
  final String id;
  final int round; // 1=1回戦, 2=2回戦, ...
  final int position; // 同ラウンド内の順番
  final TournamentEntry? player1;
  final TournamentEntry? player2;
  final String? winnerId;
  final String? firestoreMatchId; // 対局ID
  final String status; // pending, playing, finished, bye
  // 対局者それぞれの自己申告（両者が一致して初めて確定する）
  final String? p1ReportedWinnerId;
  final String? p2ReportedWinnerId;

  TournamentMatch({
    required this.id,
    required this.round,
    required this.position,
    this.player1,
    this.player2,
    this.winnerId,
    this.firestoreMatchId,
    required this.status,
    this.p1ReportedWinnerId,
    this.p2ReportedWinnerId,
  });

  bool get isBye => player2 == null;
  bool get isFinished => status == 'finished' || status == 'bye';
  bool get isDisputed =>
      p1ReportedWinnerId != null &&
      p2ReportedWinnerId != null &&
      p1ReportedWinnerId != p2ReportedWinnerId;
  TournamentEntry? get winner => winnerId == player1?.userId
      ? player1
      : winnerId == player2?.userId
          ? player2
          : null;

  /// 指定ユーザーが既に申告した勝者ID（未申告 or 対局者でなければ null）
  String? reportedWinnerIdFor(String userId) {
    if (player1?.userId == userId) return p1ReportedWinnerId;
    if (player2?.userId == userId) return p2ReportedWinnerId;
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'round': round,
        'position': position,
        'player1': player1?.toJson(),
        'player2': player2?.toJson(),
        'winner_id': winnerId,
        'match_id': firestoreMatchId,
        'status': status,
        'p1_reported_winner_id': p1ReportedWinnerId,
        'p2_reported_winner_id': p2ReportedWinnerId,
      };

  factory TournamentMatch.fromJson(Map<String, dynamic> j) =>
      TournamentMatch(
        id: j['id'] as String,
        round: j['round'] as int,
        position: j['position'] as int,
        player1: j['player1'] != null
            ? TournamentEntry.fromJson(
                (j['player1'] as Map).cast<String, dynamic>())
            : null,
        player2: j['player2'] != null
            ? TournamentEntry.fromJson(
                (j['player2'] as Map).cast<String, dynamic>())
            : null,
        winnerId: j['winner_id'] as String?,
        firestoreMatchId: j['match_id'] as String?,
        status: j['status'] as String? ?? 'pending',
        p1ReportedWinnerId: j['p1_reported_winner_id'] as String?,
        p2ReportedWinnerId: j['p2_reported_winner_id'] as String?,
      );
}

class Tournament {
  final String id;
  final String name;
  final String creatorId;
  final int maxPlayers; // 2 の累乗 (4,8,16,32)
  final List<TournamentEntry> entries;
  final List<TournamentMatch> matches;
  final String status; // open, started, finished
  final DateTime createdAt;
  final int? championRating; // 優勝者レーティング変動ボーナス

  Tournament({
    required this.id,
    required this.name,
    required this.creatorId,
    required this.maxPlayers,
    required this.entries,
    required this.matches,
    required this.status,
    required this.createdAt,
    this.championRating,
  });

  bool get isFull => entries.length >= maxPlayers;
  int get currentRound => matches.isEmpty
      ? 0
      : matches.map((m) => m.round).reduce((a, b) => a > b ? a : b);

  factory Tournament.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Tournament(
      id: doc.id,
      name: d['name'] as String? ?? '?',
      creatorId: d['creator_id'] as String? ?? '',
      maxPlayers: d['max_players'] as int? ?? 8,
      entries: ((d['entries'] as List?) ?? [])
          .map((e) =>
              TournamentEntry.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      matches: ((d['matches'] as List?) ?? [])
          .map((m) =>
              TournamentMatch.fromJson((m as Map).cast<String, dynamic>()))
          .toList(),
      status: d['status'] as String? ?? 'open',
      createdAt: d['created_at'] is Timestamp
          ? (d['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      championRating: d['champion_rating'] as int?,
    );
  }
}

// ── サービス ────────────────────────────────────────────────

class TournamentService {
  static final TournamentService _instance = TournamentService._internal();
  factory TournamentService() => _instance;
  TournamentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── 作成 ──────────────────────────────────────────────────

  Future<String> createTournament({
    required String creatorId,
    required String name,
    required int maxPlayers,
  }) async {
    assert([4, 8, 16, 32].contains(maxPlayers), 'maxPlayers must be 4/8/16/32');

    final ref = _firestore.collection('tournaments').doc();
    await ref.set({
      'id': ref.id,
      'name': name,
      'creator_id': creatorId,
      'max_players': maxPlayers,
      'entries': [],
      'matches': [],
      'status': 'open',
      'created_at': DateTime.now(),
      'champion_rating': 50, // 優勝ボーナス
    });
    return ref.id;
  }

  // ── エントリー ────────────────────────────────────────────

  Future<bool> joinTournament(String tournamentId, TournamentEntry entry) async {
    try {
      return await _firestore.runTransaction<bool>((tx) async {
        final ref =
            _firestore.collection('tournaments').doc(tournamentId);
        final doc = await tx.get(ref);
        if (!doc.exists) return false;

        final t = Tournament.fromDoc(doc);
        if (t.isFull) return false;
        if (t.status != 'open') return false;

        // 重複エントリー確認
        if (t.entries.any((e) => e.userId == entry.userId)) return false;

        final newEntries = [...t.entries.map((e) => e.toJson()), entry.toJson()];
        tx.update(ref, {'entries': newEntries});
        return true;
      });
    } catch (e) {
      print('Join tournament error: $e');
      return false;
    }
  }

  Future<void> leaveTournament(String tournamentId, String userId) async {
    try {
      await _firestore.runTransaction((tx) async {
        final ref =
            _firestore.collection('tournaments').doc(tournamentId);
        final doc = await tx.get(ref);
        if (!doc.exists) return;

        final t = Tournament.fromDoc(doc);
        if (t.status != 'open') return;

        final newEntries = t.entries
            .where((e) => e.userId != userId)
            .map((e) => e.toJson())
            .toList();
        tx.update(ref, {'entries': newEntries});
      });
    } catch (e) {
      print('Leave tournament error: $e');
    }
  }

  // ── 開始（ブラケット生成） ────────────────────────────────

  Future<void> startTournament(String tournamentId) async {
    try {
      final doc = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .get();
      if (!doc.exists) return;

      final t = Tournament.fromDoc(doc);
      if (t.status != 'open' || t.entries.length < 2) return;

      // シード順（レーティング降順）でシャッフル
      final entries = List<TournamentEntry?>.from(t.entries);
      entries.sort((a, b) => (b?.rating ?? 0).compareTo(a?.rating ?? 0));

      // 参加者を 2の累乗に合わせて BYE を追加
      final size = _nextPow2(entries.length);
      while (entries.length < size) entries.add(null); // BYE

      // 1回戦ブラケット生成
      final matches = <TournamentMatch>[];
      for (int i = 0; i < size ~/ 2; i++) {
        final p1 = entries[i * 2];
        final p2 = entries[i * 2 + 1];
        final isBye = p2 == null;

        matches.add(TournamentMatch(
          id: '${tournamentId}_r1_p$i',
          round: 1,
          position: i,
          player1: p1,
          player2: p2,
          winnerId: isBye ? p1?.userId : null,
          status: isBye ? 'bye' : 'pending',
        ));
      }

      await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .update({
        'status': 'started',
        'matches': matches.map((m) => m.toJson()).toList(),
        'started_at': DateTime.now(),
      });
    } catch (e) {
      print('Start tournament error: $e');
      rethrow;
    }
  }

  // ── 試合結果登録（両対局者の自己申告が一致して初めて確定）──────
  // 戻り値: 'confirmed'（両者一致・確定） / 'recorded'（自分の申告のみ受理・相手待ち）
  //        / 'disputed'（相手の申告と食い違い） / 'error'（対局者本人でない等）
  Future<String> reportMatchResult(
    String tournamentId,
    String matchId,
    String reporterId,
    String claimedWinnerId,
  ) async {
    String? newChampionId; // トランザクション外で実績判定するために保持
    try {
      final resultStatus = await _firestore.runTransaction<String>((tx) async {
        final ref =
            _firestore.collection('tournaments').doc(tournamentId);
        final doc = await tx.get(ref);
        if (!doc.exists) return 'error';

        final t = Tournament.fromDoc(doc);
        final matchIdx = t.matches.indexWhere((m) => m.id == matchId);
        if (matchIdx < 0) return 'error';

        final match = t.matches[matchIdx];
        if (match.isFinished) return 'error';

        final isP1 = match.player1?.userId == reporterId;
        final isP2 = match.player2?.userId == reporterId;
        if (!isP1 && !isP2) return 'error'; // 対局者本人のみ申告可能

        final newP1Report = isP1 ? claimedWinnerId : match.p1ReportedWinnerId;
        final newP2Report = isP2 ? claimedWinnerId : match.p2ReportedWinnerId;
        final agreed = newP1Report != null &&
            newP2Report != null &&
            newP1Report == newP2Report;

        if (!agreed) {
          // 片方のみ申告済み、または両者の申告が食い違い
          final updatedMatches = t.matches.map((m) {
            if (m.id != matchId) return m.toJson();
            return {
              ...m.toJson(),
              'p1_reported_winner_id': newP1Report,
              'p2_reported_winner_id': newP2Report,
            };
          }).toList();
          tx.update(ref, {'matches': updatedMatches});
          return (newP1Report != null && newP2Report != null)
              ? 'disputed'
              : 'recorded';
        }

        // 両者の申告が一致 → 確定
        final winnerId = newP1Report;
        final updatedMatches = t.matches.map((m) {
          if (m.id != matchId) return m.toJson();
          return {
            ...m.toJson(),
            'winner_id': winnerId,
            'status': 'finished',
            'p1_reported_winner_id': newP1Report,
            'p2_reported_winner_id': newP2Report,
          };
        }).toList();

        // 次ラウンドのマッチに勝者を配置
        final nextRound = match.round + 1;
        final nextPos = match.position ~/ 2;
        final nextMatchIdx = updatedMatches.indexWhere(
          (m) => (m as Map)['round'] == nextRound && (m)['position'] == nextPos,
        );

        final winner = match.player1?.userId == winnerId
            ? match.player1
            : match.player2;

        if (nextMatchIdx >= 0 && winner != null) {
          final nextMatch = updatedMatches[nextMatchIdx] as Map;
          final isOddPosition = match.position % 2 == 0;
          if (isOddPosition) {
            updatedMatches[nextMatchIdx] = {
              ...nextMatch,
              'player1': winner.toJson(),
            };
          } else {
            updatedMatches[nextMatchIdx] = {
              ...nextMatch,
              'player2': winner.toJson(),
            };
          }
        }

        // 全試合完了か確認
        final allDone = updatedMatches.every((m) =>
            (m as Map)['status'] == 'finished' ||
            (m)['status'] == 'bye');

        tx.update(ref, {
          'matches': updatedMatches,
          if (allDone) 'status': 'finished',
          if (allDone) 'champion_id': winnerId,
          if (allDone) 'finished_at': DateTime.now(),
        });

        if (allDone) newChampionId = winnerId;
        return 'confirmed';
      });

      if (newChampionId != null) {
        await NetworkAchievementService().checkTournamentWin(newChampionId!);
      }
      return resultStatus;
    } catch (e) {
      print('Report match result error: $e');
      return 'error';
    }
  }

  // ── 次ラウンド生成 ─────────────────────────────────────────

  Future<void> advanceRound(String tournamentId) async {
    try {
      final doc = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .get();
      if (!doc.exists) return;

      final t = Tournament.fromDoc(doc);
      final currentRound = t.currentRound;

      // 現ラウンドの勝者を収集
      final currentRoundMatches = t.matches
          .where((m) => m.round == currentRound && m.isFinished)
          .toList();

      // 全ての現ラウンドマッチが終了しているか確認
      final allCurrentDone =
          t.matches.where((m) => m.round == currentRound).every((m) => m.isFinished);
      if (!allCurrentDone) return;

      final winners = currentRoundMatches.map((m) => m.winner).toList();

      if (winners.length == 1) {
        // 決勝も終了 → トーナメント完了
        return;
      }

      // 次ラウンドのマッチを生成
      final nextRound = currentRound + 1;
      final newMatches = <TournamentMatch>[];
      for (int i = 0; i < winners.length ~/ 2; i++) {
        final p1 = winners[i * 2];
        final p2 = winners[i * 2 + 1];
        newMatches.add(TournamentMatch(
          id: '${tournamentId}_r${nextRound}_p$i',
          round: nextRound,
          position: i,
          player1: p1,
          player2: p2,
          status: 'pending',
        ));
      }

      final allMatches = [
        ...t.matches.map((m) => m.toJson()),
        ...newMatches.map((m) => m.toJson()),
      ];

      await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .update({'matches': allMatches});
    } catch (e) {
      print('Advance round error: $e');
    }
  }

  // ── 監視 ─────────────────────────────────────────────────

  Stream<List<Tournament>> watchOpenTournaments() {
    return _firestore
        .collection('tournaments')
        .where('status', whereIn: ['open', 'started'])
        .orderBy('created_at', descending: true)
        .limit(20)
        .snapshots()
        .map((s) => s.docs.map((d) => Tournament.fromDoc(d)).toList());
  }

  Stream<Tournament?> watchTournament(String id) {
    return _firestore
        .collection('tournaments')
        .doc(id)
        .snapshots()
        .map((d) => d.exists ? Tournament.fromDoc(d) : null);
  }

  // ── ヘルパー ──────────────────────────────────────────────

  int _nextPow2(int n) {
    int p = 1;
    while (p < n) p *= 2;
    return p;
  }
}
