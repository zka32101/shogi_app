// lib/services/stability_metrics_service.dart
// ネットワーク安定性・パフォーマンスメトリクス計測

import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ネットワーク遅延・通信安定性を計測するサービス
class StabilityMetricsService {
  static final StabilityMetricsService _instance =
      StabilityMetricsService._internal();

  factory StabilityMetricsService() {
    return _instance;
  }

  StabilityMetricsService._internal();

  final _rtdb = FirebaseDatabase.instance;
  final _firestore = FirebaseFirestore.instance;

  /// 対局中のメトリクス記録
  final Map<String, MatchMetrics> _matchMetrics = {};

  // ── ネットワーク遅延測定 ────────────────────────────

  /// Firebase RTDB への疎通確認・遅延測定
  /// 期待値: 200-500ms
  Future<int> measureRtdbLatency() async {
    try {
      final start = DateTime.now();

      // RTDB にタイムスタンプを書き込み
      final testRef = _rtdb.ref('_heartbeat');
      await testRef.set({'timestamp': start.millisecondsSinceEpoch})
          .timeout(const Duration(seconds: 5));

      final end = DateTime.now();
      final latency = end.difference(start).inMilliseconds;

      return latency;
    } catch (e) {
      return -1; // エラーの場合は -1 を返す
    }
  }

  /// 対局中の盤面更新遅延を計測
  /// [matchId]: 対局ID
  /// [boardState]: 盤面状態
  Future<int> measureBoardSyncLatency(String matchId, String boardState) async {
    try {
      final start = DateTime.now();

      // RTDB に盤面を書き込み
      final gameRef = _rtdb.ref('games/$matchId');
      await gameRef.update({'board_state': boardState, 'updated_at': start})
          .timeout(const Duration(seconds: 3));

      final end = DateTime.now();
      final latency = end.difference(start).inMilliseconds;

      // メトリクスを記録
      _recordLatencyMetric(matchId, latency, 'board_sync');

      return latency;
    } catch (e) {
      return -1;
    }
  }

  /// 対局中のチャットメッセージ送信遅延
  Future<int> measureChatLatency(String matchId, String message) async {
    try {
      final start = DateTime.now();

      final chatRef = _firestore
          .collection('matches')
          .doc(matchId)
          .collection('chat')
          .doc();

      await chatRef.set({
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        '_client_timestamp': start,
      }).timeout(const Duration(seconds: 3));

      final end = DateTime.now();
      final latency = end.difference(start).inMilliseconds;

      _recordLatencyMetric(matchId, latency, 'chat');
      return latency;
    } catch (e) {
      return -1;
    }
  }

  // ── 対局イベントログ ────────────────────────────────

  /// 対局イベントを記録
  /// [matchId]: 対局ID
  /// [event]: イベント種別（move, timeout, disconnect, etc）
  /// [data]: イベントデータ
  void logMatchEvent(
    String matchId,
    String event,
    Map<String, dynamic> data,
  ) {
    final timestamp = DateTime.now();
    final logEntry = {
      'event': event,
      'timestamp': timestamp.toIso8601String(),
      'data': data,
    };

    // メモリログ（対局中のリアルタイムログ）
    if (!_matchMetrics.containsKey(matchId)) {
      _matchMetrics[matchId] = MatchMetrics(matchId);
    }
    _matchMetrics[matchId]?.events.add(logEntry);

    // 標準出力に出力
    print(
        '[MATCH $matchId] $event | ${logEntry['timestamp']} | $data',
    );

    // 重要なイベントは Firebase に記録
    if (event == 'timeout' || event == 'disconnect' || event == 'error') {
      _logCriticalEvent(matchId, event, data, timestamp);
    }
  }

  /// 重要なイベントを Firestore に記録（後で分析可能）
  Future<void> _logCriticalEvent(
    String matchId,
    String event,
    Map<String, dynamic> data,
    DateTime timestamp,
  ) async {
    try {
      await _firestore
          .collection('matches')
          .doc(matchId)
          .collection('critical_events')
          .add({
            'event': event,
            'data': data,
            'timestamp': timestamp,
            'recorded_at': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      // Firestore 書き込み失敗は無視（ローカルログは残る）
    }
  }

  /// 遅延メトリクスを記録
  void _recordLatencyMetric(String matchId, int latency, String type) {
    if (!_matchMetrics.containsKey(matchId)) {
      _matchMetrics[matchId] = MatchMetrics(matchId);
    }

    _matchMetrics[matchId]?.latencies.add({
      'type': type, // board_sync, chat, etc
      'latency_ms': latency,
      'timestamp': DateTime.now(),
    });
  }

  // ── メトリクス集約 ────────────────────────────────────

  /// 対局のメトリクスを集約・統計化
  Future<MatchMetricsSummary?> getMetricsSummary(String matchId) async {
    final metrics = _matchMetrics[matchId];
    if (metrics == null) return null;

    return MatchMetricsSummary(
      matchId: matchId,
      totalEvents: metrics.events.length,
      averageLatency: _calculateAverageLatency(metrics.latencies),
      maxLatency: _calculateMaxLatency(metrics.latencies),
      minLatency: _calculateMinLatency(metrics.latencies),
      timeoutCount: metrics.events
          .where((e) => e['event'] == 'timeout')
          .length,
      disconnectCount: metrics.events
          .where((e) => e['event'] == 'disconnect')
          .length,
      errorCount: metrics.events
          .where((e) => e['event'] == 'error')
          .length,
    );
  }

  /// 平均遅延を計算
  int _calculateAverageLatency(List<Map<String, dynamic>> latencies) {
    if (latencies.isEmpty) return 0;
    final total = latencies.fold<int>(
      0,
      (sum, item) => sum + (item['latency_ms'] as int),
    );
    return total ~/ latencies.length;
  }

  /// 最大遅延を計算
  int _calculateMaxLatency(List<Map<String, dynamic>> latencies) {
    if (latencies.isEmpty) return 0;
    return latencies.fold<int>(
      0,
      (max, item) => (item['latency_ms'] as int) > max
          ? item['latency_ms'] as int
          : max,
    );
  }

  /// 最小遅延を計算
  int _calculateMinLatency(List<Map<String, dynamic>> latencies) {
    if (latencies.isEmpty) return 0;
    return latencies.fold<int>(
      999999,
      (min, item) => (item['latency_ms'] as int) < min
          ? item['latency_ms'] as int
          : min,
    );
  }

  // ── 診断・デバッグ ────────────────────────────────────

  /// 対局のイベントログを表示（デバッグ用）
  void printMatchLog(String matchId) {
    final metrics = _matchMetrics[matchId];
    if (metrics == null) {
      print('[DEBUG] No metrics for match $matchId');
      return;
    }

    print('=== MATCH $matchId DEBUG LOG ===');
    print('Total events: ${metrics.events.length}');
    for (final event in metrics.events) {
      print('  [${event['timestamp']}] ${event['event']}: ${event['data']}');
    }
  }

  /// 全対局のメトリクスサマリーを表示
  Future<void> printAllMetricsSummary() async {
    print('\n=== ALL MATCHES METRICS SUMMARY ===');
    for (final matchId in _matchMetrics.keys) {
      final summary = await getMetricsSummary(matchId);
      if (summary != null) {
        print(summary);
      }
    }
  }

  /// 対局終了時にメトリクスをリセット
  void clearMetrics(String matchId) {
    _matchMetrics.remove(matchId);
  }
}

// ── データモデル ────────────────────────────────────────

/// 対局中のメトリクス（メモリに保持）
class MatchMetrics {
  final String matchId;
  final List<Map<String, dynamic>> events = [];
  final List<Map<String, dynamic>> latencies = [];

  MatchMetrics(this.matchId);
}

/// 対局のメトリクスサマリー（統計）
class MatchMetricsSummary {
  final String matchId;
  final int totalEvents;
  final int averageLatency; // ms
  final int maxLatency; // ms
  final int minLatency; // ms
  final int timeoutCount;
  final int disconnectCount;
  final int errorCount;

  MatchMetricsSummary({
    required this.matchId,
    required this.totalEvents,
    required this.averageLatency,
    required this.maxLatency,
    required this.minLatency,
    required this.timeoutCount,
    required this.disconnectCount,
    required this.errorCount,
  });

  @override
  String toString() => '''
MatchMetricsSummary(
  matchId: $matchId,
  totalEvents: $totalEvents,
  averageLatency: ${averageLatency}ms,
  maxLatency: ${maxLatency}ms,
  minLatency: ${minLatency}ms,
  timeouts: $timeoutCount,
  disconnects: $disconnectCount,
  errors: $errorCount
)''';

  /// 診断: 問題がないか確認
  String getDiagnosis() {
    final warnings = <String>[];

    if (averageLatency > 500) {
      warnings.add('⚠️  高遅延: 平均 ${averageLatency}ms');
    }
    if (maxLatency > 2000) {
      warnings.add('⚠️  極度の遅延: 最大 ${maxLatency}ms');
    }
    if (disconnectCount > 2) {
      warnings.add('⚠️  多数の切断: $disconnectCount 回');
    }
    if (timeoutCount > 0) {
      warnings.add('⚠️  タイムアウト: $timeoutCount 回');
    }
    if (errorCount > 0) {
      warnings.add('⚠️  エラー: $errorCount 件');
    }

    if (warnings.isEmpty) {
      return '✅ 問題なし: 安定した対局';
    }
    return warnings.join('\n');
  }
}
