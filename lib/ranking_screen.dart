// lib/ranking_screen.dart — グローバルランキング画面

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'stats_screen.dart';
import 'ranking_service.dart';
import 'network_game_service.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  List<_RankEntry> _entries  = [];
  bool _loading              = true;
  bool _loadError            = false;
  bool _firebaseAvailable    = false;
  String _myUserId           = '';
  int _myLocalRating         = 1000;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _myUserId = await RankingService.getUserId();

    final prefs = await SharedPreferences.getInstance();
    _myLocalRating = prefs.getInt('rating_current') ?? 1000;

    _firebaseAvailable = NetworkGameService.firebaseReady;

    if (_firebaseAvailable) {
      await _fetchRanking();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchRanking() async {
    setState(() { _loading = true; _loadError = false; });
    try {
      final snap = await FirebaseDatabase.instance
          .ref('rankings')
          .orderByChild('rating')
          .limitToLast(50)
          .get()
          .timeout(const Duration(seconds: 10));

      final List<_RankEntry> entries = [];
      if (snap.exists) {
        for (final child in snap.children) {
          final data = Map<String, dynamic>.from(child.value as Map);
          entries.add(_RankEntry(
            userId  : child.key ?? '',
            nickname: data['nickname'] as String? ?? '???',
            rating  : (data['rating']  as num?)?.toInt() ?? 1000,
            wins    : (data['wins']    as num?)?.toInt() ?? 0,
            losses  : (data['losses']  as num?)?.toInt() ?? 0,
          ));
        }
      }

      // Firebase は limitToLast で昇順に返るので降順に並べ替え
      entries.sort((a, b) => b.rating.compareTo(a.rating));

      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (_) {
      setState(() { _loading = false; _loadError = true; });
    }
  }

  String _trophyOrRank(int rank) {
    switch (rank) {
      case 1: return '🥇';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '$rank';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('グローバルランキング',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: !_firebaseAvailable
          ? _buildFirebaseNotReady()
          : _loadError
              ? _buildLoadError()
              : _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.amber))
                  : RefreshIndicator(
                      color: Colors.amber,
                      backgroundColor: const Color(0xFF16213E),
                      onRefresh: _fetchRanking,
                      child: _entries.isEmpty
                          ? _buildEmpty()
                          : _buildList(),
                    ),
    );
  }

  Widget _buildFirebaseNotReady() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, color: Colors.white38, size: 56),
            const SizedBox(height: 16),
            const Text('Firebase未設定',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'ネットワーク対局を有効にすると\nランキングも利用できます。',
              style: TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _buildLoadError() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: Colors.white38, size: 56),
            const SizedBox(height: 16),
            const Text('読み込めませんでした',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('通信環境を確認してください',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchRanking,
              icon: const Icon(Icons.refresh),
              label: const Text('再読み込み'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown.shade700),
            ),
          ],
        ),
      );

  Widget _buildEmpty() => ListView(
        children: const [
          SizedBox(height: 120),
          Center(
            child: Text('まだランキングデータがありません',
                style: TextStyle(color: Colors.white38, fontSize: 14)),
          ),
        ],
      );

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _entries.length + 1, // +1 for league card header
      itemBuilder: (context, index) {
        // ヘッダー: リーグカード
        if (index == 0) {
          return _LeagueCard(rating: _myLocalRating);
        }
        final entry = _entries[index - 1];
        final rank  = index; // 1-based after header
        final isMe  = entry.userId == _myUserId;

        final rankColor = ratingToColor(entry.rating);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            color: isMe
                ? Colors.amber.withAlpha(30)
                : const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isMe ? Colors.amber.withAlpha(120) : Colors.white12,
              width: isMe ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 順位
                SizedBox(
                  width: 36,
                  child: Text(
                    _trophyOrRank(rank),
                    style: TextStyle(
                      fontSize: rank <= 3 ? 20 : 14,
                      color: rank <= 3 ? null : Colors.white54,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // リーグバッジ
                _LeagueBadge(rating: entry.rating),
                const SizedBox(width: 8),

                // ニックネーム
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.nickname,
                        style: TextStyle(
                          color: isMe ? Colors.amber : Colors.white,
                          fontSize: 14,
                          fontWeight: isMe
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        ratingToRank(entry.rating),
                        style: TextStyle(color: rankColor, fontSize: 11),
                      ),
                    ],
                  ),
                ),

                // レーティング
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${entry.rating}',
                      style: TextStyle(
                        color: rankColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${entry.wins}勝${entry.losses}敗',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── データクラス ─────────────────────────────────────────────
class _RankEntry {
  final String userId;
  final String nickname;
  final int rating;
  final int wins;
  final int losses;

  const _RankEntry({
    required this.userId,
    required this.nickname,
    required this.rating,
    required this.wins,
    required this.losses,
  });
}

// ── リーグシステム ────────────────────────────────────────────
class _League {
  final String name;
  final String emoji;
  final Color color;
  final int minRating;
  const _League(this.name, this.emoji, this.color, this.minRating);
}

const _leagues = [
  _League('王者',       '👑', Color(0xFFFFD700), 2000),
  _League('ダイヤモンド', '💎', Color(0xFF00E5FF), 1600),
  _League('プラチナ',   '🏆', Color(0xFFE0E0E0), 1300),
  _League('ゴールド',   '🥇', Color(0xFFFFAB40), 1000),
  _League('シルバー',   '🥈', Color(0xFFB0BEC5), 700),
  _League('ブロンズ',   '🥉', Color(0xFFBF8E5B), 0),
];

_League _leagueOf(int rating) {
  for (final l in _leagues) {
    if (rating >= l.minRating) return l;
  }
  return _leagues.last;
}

_League? _nextLeague(int rating) {
  for (int i = _leagues.length - 1; i >= 0; i--) {
    if (rating < _leagues[i].minRating) return _leagues[i];
  }
  return null;
}

// ── リーグカード（ヘッダー） ──────────────────────────────────
class _LeagueCard extends StatelessWidget {
  final int rating;
  const _LeagueCard({required this.rating});

  @override
  Widget build(BuildContext context) {
    final league = _leagueOf(rating);
    final next = _nextLeague(rating);
    final progress = next != null
        ? ((rating - league.minRating) / (next.minRating - league.minRating)).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            league.color.withAlpha(40),
            const Color(0xFF16213E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: league.color.withAlpha(100), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(league.emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'あなたのリーグ',
                style: TextStyle(color: league.color.withAlpha(160), fontSize: 11),
              ),
              Text(
                '${league.name}リーグ',
                style: TextStyle(color: league.color, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$rating', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const Text('レーティング', style: TextStyle(color: Colors.white38, fontSize: 10)),
            ]),
          ]),
          if (next != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${next.name}まで ${next.minRating - rating}点',
                    style: TextStyle(color: next.color.withAlpha(200), fontSize: 11)),
                Text('${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: next.color.withAlpha(180), fontSize: 11)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(next.color),
                minHeight: 6,
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('👑 最高リーグ達成！',
                  style: TextStyle(color: league.color, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

// ── リーグバッジ（一覧行） ────────────────────────────────────
class _LeagueBadge extends StatelessWidget {
  final int rating;
  const _LeagueBadge({required this.rating});

  @override
  Widget build(BuildContext context) {
    final league = _leagueOf(rating);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(league.emoji, style: const TextStyle(fontSize: 14)),
    );
  }
}
