import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_analysis.dart';

class KifuAnalyticsService {
  static const String _analysisPrefix = 'game_analysis_';
  static const String _patternsKey = 'blunder_patterns_';

  Future<GameAnalysis> analyzeAndSaveGame({
    required List<int> evalHistory,
    required List<String> moveNotations,
    required bool playerWon,
    required String? openingName,
    required bool playerIsP1,
  }) async {
    final gameId = DateTime.now().millisecondsSinceEpoch.toString();

    final (blunders, goodMoves) = _extractMoveQualities(
      evalHistory,
      moveNotations,
      playerIsP1,
    );

    final analysis = GameAnalysis(
      id: gameId,
      playedAt: DateTime.now(),
      evalHistory: evalHistory,
      moveNotations: moveNotations,
      playerWon: playerWon,
      movesCount: moveNotations.length,
      blunders: blunders,
      goodMoves: goodMoves,
      openingName: openingName,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_analysisPrefix$gameId',
      jsonEncode(analysis.toJson()),
    );

    await _updateBlunderPatterns(blunders, gameId);

    return analysis;
  }

  (List<BlunderInfo>, List<GoodMoveInfo>) _extractMoveQualities(
    List<int> evalHistory,
    List<String> moveNotations,
    bool playerIsP1,
  ) {
    final blunders = <BlunderInfo>[];
    final goodMoves = <GoodMoveInfo>[];

    if (evalHistory.isEmpty) return (blunders, goodMoves);

    // evalHistory[i] は moveNotations[i] を指した"後"の評価値（_endTurn()で
    // 1手ごとにkifu/評価値が同時にaddされるため、両リストは同じ添字iで
    // 対応する）。以前は添字を1からずらしてループしており、
    // (1) 初手(i=0)が判定対象から漏れる、(2) delta(=evalHistory[i]-
    // evalHistory[i-1]、実質i手目の結果)にmoveNotations[i-1]という
    // ひとつ前の手の指し手を紐付けてしまう、(3) moveIsP1の偶奇判定が
    // 手番と逆になる、という3つのバグが重なっていた。
    for (int i = 0; i < evalHistory.length && i < moveNotations.length; i++) {
      // i=0（初手）には直前の評価値が無いため、先後互角とみなせる0を基準にする
      final delta = evalHistory[i] - (i > 0 ? evalHistory[i - 1] : 0);

      final moveIsP1 = (i % 2 == 0); // 先手が偶数番目（0手目, 2手目, ...）
      final playerDelta = playerIsP1 == moveIsP1 ? delta : -delta;

      final notation = moveNotations[i];
      final (fromSq, toSq, piece) = _parseNotation(notation);
      final moveNum = i + 1; // 表示用は1手目から数える

      if (playerDelta <= -80) {
        blunders.add(BlunderInfo(
          moveNum: moveNum,
          evalDelta: playerDelta,
          fromSquare: fromSq,
          toSquare: toSq,
          pieceMoved: piece,
          analyzedAt: DateTime.now(),
        ));
      }

      if (playerDelta >= 150) {
        goodMoves.add(GoodMoveInfo(
          moveNum: moveNum,
          evalDelta: playerDelta,
          toSquare: toSq,
          pieceMoved: piece,
          analyzedAt: DateTime.now(),
        ));
      }
    }

    return (blunders, goodMoves);
  }

  (String?, String, String) _parseNotation(String notation) {
    if (notation.length < 2) return (null, '?', '?');

    if (notation.contains('打')) {
      final idx = notation.indexOf('打');
      final toSq = notation.substring(0, 2);
      final piece = idx > 2 ? notation.substring(2, idx) : '?';
      return ('', toSq, piece);
    }

    final toSq = notation.substring(0, 2);
    final rest = notation.length > 2 ? notation.substring(2) : '';
    final piece = rest.replaceAll('成', '').replaceAll('不成', '');

    return (null, toSq, piece.isEmpty ? '?' : piece);
  }

  Future<void> _updateBlunderPatterns(
    List<BlunderInfo> blunders,
    String gameId,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    for (final blunder in blunders) {
      final patternKey = '${blunder.toSquare}_${blunder.pieceMoved}';
      final hash = md5.convert(utf8.encode(patternKey)).toString();

      final patternsJson = prefs.getString('$_patternsKey$hash') ?? '{}';
      final patternData = jsonDecode(patternsJson) as Map<String, dynamic>;

      late BlunderPattern pattern;
      try {
        pattern = BlunderPattern.fromJson(patternData);
      } catch (_) {
        pattern = BlunderPattern(
          boardHash: hash,
          occurrenceCount: 0,
          mistakes: [],
          lastOccurred: DateTime.now(),
        );
      }

      final updated = BlunderPattern(
        boardHash: hash,
        occurrenceCount: pattern.occurrenceCount + 1,
        mistakes: [
          ...pattern.mistakes,
          blunder.toSquare,
        ],
        lastOccurred: DateTime.now(),
      );

      await prefs.setString(
        '$_patternsKey$hash',
        jsonEncode(updated.toJson()),
      );
    }
  }

  Future<List<GameAnalysis>> getAllAnalyses() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_analysisPrefix));

    final analyses = <GameAnalysis>[];
    for (final key in keys) {
      final json = prefs.getString(key);
      if (json != null) {
        try {
          analyses.add(
            GameAnalysis.fromJson(jsonDecode(json) as Map<String, dynamic>),
          );
        } catch (_) {}
      }
    }

    analyses.sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return analyses;
  }

  Future<GameAnalysis?> getAnalysis(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('$_analysisPrefix$gameId');
    if (json == null) return null;

    try {
      return GameAnalysis.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<BlunderPattern>> getRepeatedBlunders({int topN = 5}) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_patternsKey));

    final patterns = <BlunderPattern>[];
    for (final key in keys) {
      final json = prefs.getString(key);
      if (json != null) {
        try {
          patterns.add(
            BlunderPattern.fromJson(jsonDecode(json) as Map<String, dynamic>),
          );
        } catch (_) {}
      }
    }

    patterns.sort((a, b) => b.occurrenceCount.compareTo(a.occurrenceCount));
    return patterns.take(topN).toList();
  }
}
