import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../tesuji_problems.dart';

/// 毎日更新される5問の詰将棋問題を管理
class DailyProblemService {
  static const int dailyProblemsCount = 5;
  static const String _cacheKeyPrefix = 'daily_problems_';
  static const String _lastFetchKeyPrefix = 'daily_problems_fetch_';

  /// 本日の問題をダウンロード（キャッシュ優先）
  static Future<List<TesujiProb>> fetchTodayProblems() async {
    final today = _getDateKey();
    final prefs = await SharedPreferences.getInstance();

    // キャッシュ確認
    final cached = prefs.getString('$_cacheKeyPrefix$today');
    if (cached != null) {
      try {
        return _parseProblems(jsonDecode(cached) as List<dynamic>);
      } catch (_) {}
    }

    // Cloud Storage から DL
    try {
      final storage = FirebaseStorage.instance;
      final file =
          await storage.ref('problems/$today.json').getData(5 * 1024 * 1024);

      if (file == null) {
        return _getFallbackProblems(prefs, today);
      }

      final json = jsonDecode(utf8.decode(file)) as List<dynamic>;
      await prefs.setString('$_cacheKeyPrefix$today', jsonEncode(json));
      await prefs.setInt('$_lastFetchKeyPrefix$today', DateTime.now().millisecondsSinceEpoch);

      return _parseProblems(json);
    } catch (e) {
      return _getFallbackProblems(prefs, today);
    }
  }

  /// フォールバック：前日のキャッシュを使用
  static Future<List<TesujiProb>> _getFallbackProblems(
    SharedPreferences prefs,
    String today,
  ) async {
    for (int daysAgo = 1; daysAgo <= 7; daysAgo++) {
      final fallbackDate = _getDateKey(daysAgo: daysAgo);
      final cached = prefs.getString('$_cacheKeyPrefix$fallbackDate');
      if (cached != null) {
        try {
          return _parseProblems(jsonDecode(cached) as List<dynamic>);
        } catch (_) {}
      }
    }
    return [];
  }

  /// JSON リストから TesujiProb に変換
  static List<TesujiProb> _parseProblems(List<dynamic> json) {
    return json
        .map((e) => TesujiProb.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 日付キーを生成（YYYY-MM-DD 形式）
  static String _getDateKey({int daysAgo = 0}) {
    final date = DateTime.now().subtract(Duration(days: daysAgo));
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// キャッシュをクリア
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_cacheKeyPrefix) ||
          key.startsWith(_lastFetchKeyPrefix)) {
        await prefs.remove(key);
      }
    }
  }

  /// 指定した日付の問題をキャッシュから取得
  static Future<List<TesujiProb>?> getCachedProblemsForDate(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('$_cacheKeyPrefix$date');
    if (cached == null) return null;

    try {
      return _parseProblems(jsonDecode(cached) as List<dynamic>);
    } catch (_) {
      return null;
    }
  }
}
