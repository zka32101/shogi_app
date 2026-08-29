// lib/widgets/connectivity_indicator_widget.dart
// ネットワーク接続状況インジケータ

import 'package:flutter/material.dart';
import '../services/network_connectivity_service.dart';

/// ネットワーク接続状況を表示するウィジェット
class ConnectivityIndicator extends StatelessWidget {
  final NetworkConnectivityService connectivityService;
  final String? matchId;

  const ConnectivityIndicator({
    super.key,
    required this.connectivityService,
    this.matchId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NetworkConnectionState>(
      stream: connectivityService.onStateChanged,
      initialData: connectivityService.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? NetworkConnectionState.connected;

        // 接続状態が良好な場合は非表示
        if (state == NetworkConnectionState.connected) {
          return const SizedBox.shrink();
        }

        return _buildStatusBar(state);
      },
    );
  }

  /// ステータスバーを構築
  Widget _buildStatusBar(NetworkConnectionState state) {
    switch (state) {
      case NetworkConnectionState.disconnected:
        return _buildDisconnectBar();
      case NetworkConnectionState.reconnecting:
        return _buildReconnectingBar();
      case NetworkConnectionState.connected:
        return const SizedBox.shrink();
    }
  }

  /// 切断状態バー
  Widget _buildDisconnectBar() {
    return Container(
      height: 40,
      color: Colors.red.shade700.withAlpha(200),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Text(
            '⚠️ インターネット接続がありません',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 再接続中バー
  Widget _buildReconnectingBar() {
    return Container(
      height: 40,
      color: Colors.orange.shade700.withAlpha(200),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLoadingSpinner(),
          const SizedBox(width: 8),
          const Text(
            '🔄 接続を復帰中...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// ローディングスピナー（小型）
  Widget _buildLoadingSpinner() {
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          Colors.white.withAlpha(200),
        ),
      ),
    );
  }
}

/// マッチ画面用接続状況バナー（より詳細）
class MatchConnectivityBanner extends StatefulWidget {
  final NetworkConnectivityService connectivityService;
  final String matchId;
  final VoidCallback? onResyncPressed;

  const MatchConnectivityBanner({
    super.key,
    required this.connectivityService,
    required this.matchId,
    this.onResyncPressed,
  });

  @override
  State<MatchConnectivityBanner> createState() =>
      _MatchConnectivityBannerState();
}

class _MatchConnectivityBannerState extends State<MatchConnectivityBanner> {
  bool _isResyncInProgress = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NetworkConnectionState>(
      stream: widget.connectivityService.onStateChanged,
      initialData: widget.connectivityService.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? NetworkConnectionState.connected;

        if (state == NetworkConnectionState.connected) {
          return const SizedBox.shrink();
        }

        if (state == NetworkConnectionState.disconnected) {
          return _buildDisconnectBanner();
        }

        return _buildReconnectingBanner();
      },
    );
  }

  /// 切断状態バナー（再同期ボタン付き）
  Widget _buildDisconnectBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.red.shade900.withAlpha(220),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '接続が失われました',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Wi-Fiまたはモバイル接続を確認してください',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isResyncInProgress ? null : _handleResyncPressed,
            icon: Icon(
              _isResyncInProgress
                  ? Icons.hourglass_bottom
                  : Icons.sync,
              size: 16,
            ),
            label: Text(_isResyncInProgress ? '再同期中...' : '再同期'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withAlpha(220),
              foregroundColor: Colors.red.shade900,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 再接続中バナー
  Widget _buildReconnectingBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.orange.shade900.withAlpha(220),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withAlpha(200),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '接続を復帰中',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '盤面同期をしています...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 再同期ボタン押下処理
  Future<void> _handleResyncPressed() async {
    setState(() => _isResyncInProgress = true);

    try {
      final success =
          await widget.connectivityService.resyncBoard(widget.matchId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 盤面を再同期しました'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ 盤面の再同期に失敗しました'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isResyncInProgress = false);
      }
    }

    widget.onResyncPressed?.call();
  }
}
