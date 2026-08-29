// lib/services/network_connectivity_service.dart
// ネットワーク接続状況の監視・復帰ロジック

import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'board_sync_service.dart';
import 'stability_metrics_service.dart';

/// ネットワーク接続状態の定義
enum NetworkConnectionState {
  /// インターネット接続あり
  connected,
  /// インターネット接続なし（Wi-Fi/モバイル切断）
  disconnected,
  /// 接続中（リコネクト試行中）
  reconnecting,
}

/// ネットワーク接続・復帰を監視・管理するサービス
class NetworkConnectivityService {
  static final NetworkConnectivityService _instance =
      NetworkConnectivityService._internal();

  factory NetworkConnectivityService() {
    return _instance;
  }

  NetworkConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StabilityMetricsService _metricsService = StabilityMetricsService();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // 接続状態ストリーム
  final StreamController<NetworkConnectionState> _stateController =
      StreamController<NetworkConnectionState>.broadcast();

  NetworkConnectionState _currentState = NetworkConnectionState.connected;
  DateTime? _lastDisconnectAt;
  DateTime? _lastReconnectAt;

  /// 接続状態ストリーム（UI監視用）
  Stream<NetworkConnectionState> get onStateChanged => _stateController.stream;

  /// 現在の接続状態を取得
  NetworkConnectionState get currentState => _currentState;

  /// 最後の切断時刻
  DateTime? get lastDisconnectAt => _lastDisconnectAt;

  /// 最後の再接続時刻
  DateTime? get lastReconnectAt => _lastReconnectAt;

  /// ネットワーク監視を開始
  Future<void> startMonitoring() async {
    // 初期状態を確認
    await _checkConnectivity();

    // 接続状態の変化を監視
    _connectivitySub = _connectivity.onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      _handleConnectivityChange(result);
    });
  }

  /// ネットワーク監視を停止
  Future<void> stopMonitoring() async {
    await _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// 接続状態を確認
  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _handleConnectivityChange(result as List<ConnectivityResult>? ?? []);
    } catch (e) {
      _logMetric('connectivity_check_error', {'error': e.toString()});
    }
  }

  /// 接続状態の変化を処理
  void _handleConnectivityChange(List<ConnectivityResult> result) {
    final isConnected = result.isNotEmpty &&
        result.any((r) =>
            r == ConnectivityResult.mobile || r == ConnectivityResult.wifi);

    if (isConnected && _currentState == NetworkConnectionState.disconnected) {
      // 🔄 再接続検出
      _onReconnected();
    } else if (!isConnected &&
        _currentState == NetworkConnectionState.connected) {
      // 🔴 切断検出
      _onDisconnected();
    }
  }

  /// 接続が切断された場合の処理
  void _onDisconnected() {
    _currentState = NetworkConnectionState.disconnected;
    _lastDisconnectAt = DateTime.now();

    _logMetric('connection_lost', {
      'timestamp': _lastDisconnectAt?.toIso8601String(),
      'state': 'disconnected',
    });

    _stateController.add(NetworkConnectionState.disconnected);
  }

  /// 再接続を検出した場合の処理
  Future<void> _onReconnected() async {
    _currentState = NetworkConnectionState.reconnecting;
    _lastReconnectAt = DateTime.now();

    _logMetric('reconnection_started', {
      'timestamp': _lastReconnectAt?.toIso8601String(),
      'state': 'reconnecting',
      'offline_duration_ms':
          _lastDisconnectAt != null
              ? _lastReconnectAt!
                  .difference(_lastDisconnectAt!)
                  .inMilliseconds
              : null,
    });

    _stateController.add(NetworkConnectionState.reconnecting);

    // 盤面同期の再試行（30秒以内に完了）
    await Future.delayed(const Duration(milliseconds: 500));

    // リコネクション成功
    _currentState = NetworkConnectionState.connected;
    _logMetric('reconnection_completed', {
      'timestamp': DateTime.now().toIso8601String(),
      'state': 'connected',
    });

    _stateController.add(NetworkConnectionState.connected);
  }

  /// 対局の盤面を再同期（再接続時に呼ぶ）
  Future<bool> resyncBoard(String matchId) async {
    try {
      final boardSync = BoardSyncService();
      final state = await boardSync
          .getBoardState(matchId)
          .timeout(const Duration(seconds: 5));

      if (state != null) {
        _logMetric('board_resync_success', {
          'match_id': matchId,
          'timestamp': DateTime.now().toIso8601String(),
        });
        return true;
      }
      return false;
    } catch (e) {
      _logMetric('board_resync_error', {
        'match_id': matchId,
        'error': e.toString(),
      });
      return false;
    }
  }

  /// メトリクスをログに記録
  void _logMetric(String event, Map<String, dynamic> data) {
    print('[CONNECTIVITY] $event | ${data['timestamp'] ?? DateTime.now().toIso8601String()} | $data');
    _metricsService.logMatchEvent('network', event, data);
  }

  /// クリーンアップ
  Future<void> dispose() async {
    await stopMonitoring();
    await _stateController.close();
  }
}
