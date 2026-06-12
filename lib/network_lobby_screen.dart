// lib/network_lobby_screen.dart — ネットワーク対局ロビー画面
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_screen.dart';
import 'network_game_service.dart';
import 'local_network_service.dart';
import 'purchase_service.dart';

// ── 変則ルール選択データ ──────────────────────────────────────
const _variantOptions = [
  (VariantType.normal,        '標準',         Icons.sports_esports),
  (VariantType.captureForced, '取る一手',      Icons.flash_on),
  (VariantType.checkForced,   '王手将棋',      Icons.gavel),
  (VariantType.hiddenPieces,  'かくし将棋',    Icons.visibility_off),
  (VariantType.kagemusha,     '影武者',        Icons.theater_comedy),
  (VariantType.invader,       'インベーダー',  Icons.rocket_launch),
];

// ── 相手の強さ設定 ────────────────────────────────────────────
enum _StrengthPref { weak, any, strong }

const _strengthOptions = [
  (_StrengthPref.weak,   '弱め',      Icons.sentiment_satisfied),
  (_StrengthPref.any,    'なんでも',  Icons.people),
  (_StrengthPref.strong, '強め',      Icons.military_tech),
];

// ── 1日あたりの無料ネット対局数上限 ──────────────────────────
const _kNetDailyLimit = 5;

class NetworkLobbyScreen extends StatefulWidget {
  const NetworkLobbyScreen({super.key});

  @override
  State<NetworkLobbyScreen> createState() => _NetworkLobbyScreenState();
}

enum _LobbyState { initial, creating, joining, waiting, matching, spectating, localHost, localGuest }

class _NetworkLobbyScreenState extends State<NetworkLobbyScreen> {
  _LobbyState _state    = _LobbyState.initial;
  String      _code     = '';
  String      _error    = '';
  bool        _loading  = false;
  int         _matchingElapsed = 0; // マッチング経過秒数
  Timer?      _matchingTimer;
  final _codeCtrl = TextEditingController();
  StreamSubscription? _statusSub;
  List<Map<String, dynamic>> _activeRooms = [];
  bool _loadingRooms = false;
  String _localIp = '';
  final _ipCtrl = TextEditingController();
  // 変則ルール選択
  VariantType _selectedVariant = VariantType.normal;
  // 相手の強さ設定
  _StrengthPref _strengthPref = _StrengthPref.any;
  // レーティング戦かどうか
  bool _rated = true;

  @override
  void dispose() {
    _statusSub?.cancel();
    _matchingTimer?.cancel();
    _codeCtrl.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }

  // ─── 1日の対局上限チェック ────────────────────────────────────────────────
  /// true なら対局可能。false なら上限に達していてダイアログ表示済み。
  Future<bool> _checkDailyLimit() async {
    // プレミアム会員は無制限
    if (PurchaseService.isPremium) return true;

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    final savedDate  = prefs.getString('net_daily_date') ?? '';
    int   count      = prefs.getInt('net_daily_count')  ?? 0;

    if (savedDate != today) {
      // 日付が変わったのでリセット
      count = 0;
      await prefs.setString('net_daily_date', today);
      await prefs.setInt('net_daily_count', 0);
    }

    if (count >= _kNetDailyLimit) {
      if (!mounted) return false;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: const Text('1日の上限に達しました', style: TextStyle(color: Colors.white)),
          content: Text(
            '無料プランでは1日あたりネット対局は${_kNetDailyLimit}戦までです。\n'
            '明日またチャレンジするか、プレミアムに登録してください。',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('閉じる', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      );
      return false;
    }

    // カウントアップ
    await prefs.setInt('net_daily_count', count + 1);
    return true;
  }

  // ─── ランダムマッチング ──────────────────────────────────────────────────────
  Future<void> _startMatchmaking() async {
    if (!await _checkDailyLimit()) return;
    setState(() {
      _state   = _LobbyState.matching;
      _error   = '';
      _loading = false;
      _matchingElapsed = 0;
    });
    // 経過秒数カウンター
    _matchingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _matchingElapsed++);
    });

    try {
      // 現在のレーティングを取得して強さフィルタに使う
      final prefs    = await SharedPreferences.getInstance();
      final myRating = prefs.getInt('rating_current') ?? 1000;
      final strengthStr = _strengthPref == _StrengthPref.weak   ? 'weak'
                        : _strengthPref == _StrengthPref.strong ? 'strong'
                        : 'any';
      final result = await NetworkGameService.startMatchmaking(
        myRating:     myRating,
        strengthPref: strengthStr,
        rated:        _rated,
      );
      _matchingTimer?.cancel();
      if (mounted) _goToGame(isHost: result.isHost);
    } on TimeoutException {
      _matchingTimer?.cancel();
      if (mounted) {
        setState(() {
          _state = _LobbyState.initial;
          _error = '対戦相手が見つかりませんでした。しばらく後でお試しください。';
        });
      }
    } catch (e) {
      _matchingTimer?.cancel();
      if (mounted) {
        setState(() {
          _state = _LobbyState.initial;
          _error = 'エラー: $e';
        });
      }
    }
  }

  // ─── マッチングキャンセル ────────────────────────────────────────────────
  Future<void> _cancelMatchmaking() async {
    _matchingTimer?.cancel();
    await NetworkGameService.cancelMatchmaking();
    if (mounted) {
      setState(() {
        _state = _LobbyState.initial;
        _error = '';
      });
    }
  }

  // ─── 部屋を作る ────────────────────────────────────────────────────────────
  Future<void> _createRoom() async {
    if (!await _checkDailyLimit()) return;
    setState(() { _loading = true; _error = ''; });
    try {
      final code = await NetworkGameService.createRoom();
      setState(() {
        _code    = code;
        _state   = _LobbyState.waiting;
        _loading = false;
      });
      // 相手が参加するのを待つ
      _statusSub = NetworkGameService.statusStream.listen((status) {
        if (status == NetworkStatus.playing && mounted) {
          _statusSub?.cancel();
          _goToGame(isHost: NetworkGameService.hostIsP1);
        }
      });
    } catch (e) {
      setState(() { _error = 'エラー: $e'; _loading = false; });
    }
  }

  // ─── 部屋に参加 ────────────────────────────────────────────────────────────
  Future<void> _joinRoom() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = '6桁のコードを入力してください');
      return;
    }
    if (!await _checkDailyLimit()) return;
    setState(() { _loading = true; _error = ''; });
    try {
      final result = await NetworkGameService.joinRoom(code);
      setState(() => _loading = false);
      switch (result) {
        case JoinResult.ok:
          _goToGame(isHost: !NetworkGameService.hostIsP1);
        case JoinResult.notFound:
          setState(() => _error = 'ルームが見つかりません（コードを確認してください）');
        case JoinResult.full:
          setState(() => _error = 'この部屋はすでに対局中です');
        case JoinResult.error:
          setState(() => _error = '接続エラー。もう一度お試しください');
      }
    } catch (e) {
      setState(() { _error = 'エラー: $e'; _loading = false; });
    }
  }

  // ─── GameScreen へ遷移 ─────────────────────────────────────────────────────
  void _goToGame({required bool isHost}) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          settings: GameSettings(
            mode:          GameMode.network,
            networkIsHost: isHost,
            variant:       _selectedVariant,
            networkRated:  _rated,
          ),
        ),
      ),
    );
  }

  // ─── 観戦参加 ─────────────────────────────────────────────────────────────
  Future<void> _joinSpectator() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = '6桁のコードを入力してください');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      final result = await NetworkGameService.joinAsSpectator(code);
      setState(() => _loading = false);
      switch (result) {
        case JoinResult.ok:
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => GameScreen(
                settings: const GameSettings(mode: GameMode.spectator),
              ),
            ),
          );
        case JoinResult.notFound:
          setState(() => _error = 'ルームが見つかりません（コードを確認してください）');
        case JoinResult.full:
          setState(() => _error = 'この対局はすでに終了しています');
        case JoinResult.error:
          setState(() => _error = '接続エラー。もう一度お試しください');
      }
    } catch (e) {
      setState(() { _error = 'エラー: $e'; _loading = false; });
    }
  }

  // ─── アクティブルーム一覧読み込み ────────────────────────────────────────
  Future<void> _loadActiveRooms() async {
    try {
      final rooms = await NetworkGameService.getActiveRooms();
      if (mounted) {
        setState(() {
          _activeRooms = rooms;
          _loadingRooms = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRooms = false);
    }
  }

  // ─── コードを指定して観戦参加 ─────────────────────────────────────────────
  Future<void> _joinSpectatorByCode(String code) async {
    setState(() { _loading = true; _error = ''; });
    try {
      final result = await NetworkGameService.joinAsSpectator(code);
      setState(() => _loading = false);
      switch (result) {
        case JoinResult.ok:
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => GameScreen(
                settings: const GameSettings(mode: GameMode.spectator),
              ),
            ),
          );
        case JoinResult.notFound:
          setState(() => _error = 'ルームが見つかりません');
        case JoinResult.full:
          setState(() => _error = 'この対局はすでに終了しています');
        case JoinResult.error:
          setState(() => _error = '接続エラー。もう一度お試しください');
      }
    } catch (e) {
      setState(() { _error = 'エラー: $e'; _loading = false; });
    }
  }

  // ─── ローカルホスト開始 ──────────────────────────────────────────────────
  Future<void> _startLocalHost() async {
    if (!await _checkDailyLimit()) return;
    setState(() { _loading = true; _error = ''; });
    try {
      await LocalNetworkService.startHost();
      final ip = await LocalNetworkService.getLocalIp();
      setState(() {
        _localIp = ip;
        _state   = _LobbyState.localHost;
        _loading = false;
      });
      _statusSub = LocalNetworkService.statusStream.listen((status) {
        if (status == NetworkStatus.playing && mounted) {
          _statusSub?.cancel();
          _goToLocalGame(isHost: true);
        }
      });
    } catch (e) {
      setState(() { _error = 'エラー: $e'; _loading = false; });
    }
  }

  // ─── ローカルゲスト接続 ──────────────────────────────────────────────────
  Future<void> _connectLocalGuest() async {
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) {
      setState(() => _error = 'IPアドレスを入力してください');
      return;
    }
    if (!await _checkDailyLimit()) return;
    setState(() { _loading = true; _error = ''; });
    try {
      await LocalNetworkService.connectToHost(ip);
      if (mounted) _goToLocalGame(isHost: false);
    } catch (e) {
      setState(() { _error = '接続エラー: $e\nIPアドレスとポートを確認してください'; _loading = false; });
    }
  }

  void _goToLocalGame({required bool isHost}) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          settings: GameSettings(
            mode:          GameMode.localNetwork,
            networkIsHost: isHost,
            variant:       _selectedVariant,
          ),
        ),
      ),
    );
  }

  // ─── キャンセル ─────────────────────────────────────────────────────────────
  void _cancel() {
    _statusSub?.cancel();
    NetworkGameService.dispose();
    LocalNetworkService.dispose();
    setState(() {
      _state   = _LobbyState.initial;
      _code    = '';
      _error   = '';
      _loading = false;
      _codeCtrl.clear();
      _ipCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('ネットワーク対局', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.amber),
          SizedBox(height: 20),
          Text('接続中...', style: TextStyle(color: Colors.white70)),
        ],
      );
    }

    switch (_state) {
      case _LobbyState.initial:
        return _buildInitial();
      case _LobbyState.creating:
        return _buildJoinInput();
      case _LobbyState.joining:
        return _buildJoinInput();
      case _LobbyState.waiting:
        return _buildWaiting();
      case _LobbyState.matching:
        return _buildMatching();
      case _LobbyState.spectating:
        return _buildSpectateInput();
      case _LobbyState.localHost:
        return _buildLocalHostWaiting();
      case _LobbyState.localGuest:
        return _buildLocalGuestInput();
    }
  }

  // ─── 変則ルール選択ピッカー ───────────────────────────────────────────────
  Widget _buildVariantPicker() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.auto_awesome, color: Colors.deepPurpleAccent, size: 16),
            const SizedBox(width: 6),
            const Text(
              '変則ルール',
              style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1),
            ),
            if (_selectedVariant != VariantType.normal) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withAlpha(80),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.deepPurpleAccent.withAlpha(150)),
                ),
                child: Text(
                  _variantOptions.firstWhere((o) => o.$1 == _selectedVariant).$2,
                  style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _variantOptions.map((option) {
              final (type, label, icon) = option;
              final isSelected = _selectedVariant == type;
              return GestureDetector(
                onTap: () => setState(() => _selectedVariant = type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.deepPurple.withAlpha(180)
                        : const Color(0xFF0F1A30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.deepPurpleAccent : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: isSelected ? Colors.white : Colors.white54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white54,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── 相手の強さ選択ピッカー ──────────────────────────────────────────────
  Widget _buildStrengthPicker() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.bar_chart, color: Colors.tealAccent, size: 16),
            SizedBox(width: 6),
            Text(
              '相手の強さ',
              style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1),
            ),
          ]),
          const SizedBox(height: 10),
          Row(
            children: _strengthOptions.map((option) {
              final (pref, label, icon) = option;
              final isSelected = _strengthPref == pref;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _strengthPref = pref),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.teal.withAlpha(180)
                          : const Color(0xFF0F1A30),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? Colors.tealAccent : Colors.white24,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.white54),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white54,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── レーティング戦トグル ────────────────────────────────────────────────
  Widget _buildRatedToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('レーティング戦', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                Text('勝敗でスコアが変動', style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: _rated,
            activeColor: Colors.amber,
            onChanged: (v) => setState(() => _rated = v),
          ),
        ],
      ),
    );
  }

  // ─── 初期画面 ────────────────────────────────────────────────────────────
  Widget _buildInitial() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi, color: Colors.amber, size: 64),
        const SizedBox(height: 24),
        const Text(
          'オンライン対局',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '不特定多数とのマッチング、または\nルームコードで友人と対局できます',
          style: TextStyle(color: Colors.white54, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        // ─── 変則ルール選択 ───────────────────────────────────────────────
        _buildVariantPicker(),
        const SizedBox(height: 12),
        // ─── 相手の強さ設定 ───────────────────────────────────────────────
        _buildStrengthPicker(),
        const SizedBox(height: 12),
        // ─── レーティング戦トグル ──────────────────────────────────────────
        _buildRatedToggle(),
        const SizedBox(height: 24),
        // ─── マッチング ───────────────────────────────────────────────────
        _bigButton(
          label:  'マッチングを探す',
          icon:   Icons.search,
          color:  const Color(0xFF6C3483),
          onTap:  _startMatchmaking,
        ),
        const SizedBox(height: 16),
        const Row(children: [
          Expanded(child: Divider(color: Colors.white12)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('または友人と', style: TextStyle(color: Colors.white30, fontSize: 12)),
          ),
          Expanded(child: Divider(color: Colors.white12)),
        ]),
        const SizedBox(height: 16),
        // ─── 友人対局 ─────────────────────────────────────────────────────
        _bigButton(
          label:  '部屋を作る',
          icon:   Icons.add_circle_outline,
          color:  const Color(0xFF1B4F72),
          onTap:  _createRoom,
        ),
        const SizedBox(height: 12),
        _bigButton(
          label:  '部屋に参加',
          icon:   Icons.login,
          color:  const Color(0xFF1B6F3A),
          onTap:  () => setState(() => _state = _LobbyState.joining),
        ),
        const SizedBox(height: 16),
        const Row(children: [
          Expanded(child: Divider(color: Colors.white12)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('または', style: TextStyle(color: Colors.white30, fontSize: 12)),
          ),
          Expanded(child: Divider(color: Colors.white12)),
        ]),
        const SizedBox(height: 16),
        _bigButton(
          label:  '対局を観戦する',
          icon:   Icons.visibility_outlined,
          color:  const Color(0xFF4A235A),
          onTap:  () {
            setState(() {
              _state = _LobbyState.spectating;
              _loadingRooms = true;
              _activeRooms = [];
            });
            _loadActiveRooms();
          },
        ),
        const SizedBox(height: 16),
        const Row(children: [
          Expanded(child: Divider(color: Colors.white12)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('同じWi-Fiで対局', style: TextStyle(color: Colors.white30, fontSize: 12)),
          ),
          Expanded(child: Divider(color: Colors.white12)),
        ]),
        const SizedBox(height: 16),
        _bigButton(
          label:  'ホストになる（先手）',
          icon:   Icons.router,
          color:  const Color(0xFF7B3F00),
          onTap:  _startLocalHost,
        ),
        const SizedBox(height: 12),
        _bigButton(
          label:  'IPで接続（後手）',
          icon:   Icons.link,
          color:  const Color(0xFF2E4057),
          onTap:  () => setState(() { _state = _LobbyState.localGuest; _error = ''; }),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 20),
          _errorText(_error),
        ],
      ],
    );
  }

  // ─── ローカルホスト待機画面 ──────────────────────────────────────────────
  Widget _buildLocalHostWaiting() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.router, color: Colors.orange, size: 56),
        const SizedBox(height: 20),
        const Text(
          'ゲストの接続を待っています',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        const Text('あなたのIPアドレス', style: TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: _localIp));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('IPをコピーしました'), duration: Duration(seconds: 2)),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              color:        const Color(0xFF0D0D1A),
              borderRadius: BorderRadius.circular(14),
              border:       Border.all(color: Colors.orange.shade700, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _localIp,
                  style: const TextStyle(
                    color: Colors.orange, fontSize: 28,
                    fontWeight: FontWeight.bold, letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.copy, color: Colors.white38, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'このIPアドレスをゲストに伝えてください',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 32),
        const LinearProgressIndicator(
          backgroundColor: Color(0xFF2A2A4A),
          color: Colors.orange,
        ),
        const SizedBox(height: 32),
        TextButton.icon(
          onPressed: _cancel,
          icon:  const Icon(Icons.cancel_outlined, color: Colors.red),
          label: const Text('キャンセル', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  // ─── ローカルゲスト接続画面 ──────────────────────────────────────────────
  Widget _buildLocalGuestInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.link, color: Colors.lightBlue, size: 56),
        const SizedBox(height: 20),
        const Text(
          'ホストのIPアドレスを入力',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          '同じWi-Fiに繋がっている必要があります',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 24),
        TextField(
          controller:   _ipCtrl,
          autofocus:    true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign:    TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 1),
          decoration: InputDecoration(
            hintText:      '例: 192.168.1.10',
            hintStyle:     const TextStyle(color: Colors.white24, fontSize: 18),
            filled:        true,
            fillColor:     const Color(0xFF0D0D1A),
            border:        OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   const BorderSide(color: Colors.lightBlue, width: 2),
            ),
          ),
          onSubmitted: (_) => _connectLocalGuest(),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E4057),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _connectLocalGuest,
            child: const Text('接続する', style: TextStyle(color: Colors.white, fontSize: 18)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _cancel,
          child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          _errorText(_error),
        ],
      ],
    );
  }

  // ─── マッチング待機画面 ──────────────────────────────────────────────────
  Widget _buildMatching() {
    final mins = _matchingElapsed ~/ 60;
    final secs = _matchingElapsed % 60;
    final timeStr = mins > 0
        ? '$mins:${secs.toString().padLeft(2, '0')}'
        : '${secs}秒';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        // アニメーション的な検索アイコン
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.purple.shade300.withAlpha(80), width: 2),
              ),
            ),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.purple.shade400.withAlpha(120), width: 2),
              ),
            ),
            const Icon(Icons.search, color: Colors.purple, size: 40),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          '対戦相手を探しています...',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          '経過時間: $timeStr',
          style: const TextStyle(color: Colors.white38, fontSize: 14),
        ),
        const SizedBox(height: 8),
        const Text(
          '最大60秒待ちます',
          style: TextStyle(color: Colors.white24, fontSize: 12),
        ),
        const SizedBox(height: 32),
        const LinearProgressIndicator(
          backgroundColor: Color(0xFF2A2A4A),
          color:           Colors.purple,
        ),
        const SizedBox(height: 32),
        TextButton.icon(
          onPressed: _cancelMatchmaking,
          icon:  const Icon(Icons.cancel_outlined, color: Colors.red),
          label: const Text('キャンセル', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  // ─── コード入力画面 ──────────────────────────────────────────────────────
  Widget _buildJoinInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.keyboard, color: Colors.green, size: 56),
        const SizedBox(height: 20),
        const Text(
          '6桁のルームコードを入力',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        TextField(
          controller:   _codeCtrl,
          autofocus:    true,
          maxLength:    6,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign:    TextAlign.center,
          style: const TextStyle(
            color:      Colors.white,
            fontSize:   32,
            letterSpacing: 8,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            counterText:    '',
            hintText:       '000000',
            hintStyle:      const TextStyle(color: Colors.white24, fontSize: 32, letterSpacing: 8),
            filled:         true,
            fillColor:      const Color(0xFF0D0D1A),
            border:         OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   const BorderSide(color: Colors.white24),
            ),
            focusedBorder:  OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   const BorderSide(color: Colors.amber, width: 2),
            ),
          ),
          onSubmitted: (_) => _joinRoom(),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B6F3A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _joinRoom,
            child: const Text('参加する', style: TextStyle(color: Colors.white, fontSize: 18)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _cancel,
          child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          _errorText(_error),
        ],
      ],
    );
  }

  // ─── 観戦対局一覧画面 ────────────────────────────────────────────────────
  Widget _buildSpectateInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.visibility, color: Colors.purple, size: 56),
        const SizedBox(height: 16),
        const Text(
          '観戦する対局を選択',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          '現在進行中の対局一覧です',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 16),
        if (_loadingRooms)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: CircularProgressIndicator(color: Colors.purple),
          )
        else if (_activeRooms.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                const Icon(Icons.info_outline, color: Colors.white38, size: 40),
                const SizedBox(height: 12),
                const Text(
                  '現在進行中の対局はありません',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _loadingRooms = true);
                    _loadActiveRooms();
                  },
                  icon: const Icon(Icons.refresh, color: Colors.purple),
                  label: const Text('更新', style: TextStyle(color: Colors.purple)),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 240,
            child: ListView.builder(
              itemCount: _activeRooms.length,
              itemBuilder: (ctx, i) {
                final room = _activeRooms[i];
                final code = room['code'] as String;
                final moveCount = room['moveCount'] as int;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D2A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.shade800, width: 1),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.sports_esports, color: Colors.purple),
                    title: Text(
                      '対局 #$code',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '$moveCount手目進行中',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A235A),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _joinSpectatorByCode(code),
                      child: const Text('観戦', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _cancel,
          child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          _errorText(_error),
        ],
      ],
    );
  }

  // ─── 待機画面（ホストが相手を待っている）────────────────────────────────
  Widget _buildWaiting() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.hourglass_empty, color: Colors.amber, size: 56),
        const SizedBox(height: 20),
        const Text(
          '相手を待っています...',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        const Text(
          'ルームコード',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(height: 12),
        // コード大きく表示
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: _code));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('コードをコピーしました'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
              color:        const Color(0xFF0D0D1A),
              borderRadius: BorderRadius.circular(16),
              border:       Border.all(color: Colors.amber.shade700, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _code,
                  style: const TextStyle(
                    color:       Colors.amber,
                    fontSize:    40,
                    fontWeight:  FontWeight.bold,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.copy, color: Colors.white38, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'このコードを相手に教えてください',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 32),
        const LinearProgressIndicator(
          backgroundColor: Color(0xFF2A2A4A),
          color:           Colors.amber,
        ),
        const SizedBox(height: 32),
        TextButton.icon(
          onPressed: _cancel,
          icon:  const Icon(Icons.cancel_outlined, color: Colors.red),
          label: const Text('キャンセル', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  // ─── ヘルパー ────────────────────────────────────────────────────────────
  Widget _bigButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width:  double.infinity,
      height: 64,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon:     Icon(icon, color: Colors.white, size: 24),
        label:    Text(label, style: const TextStyle(color: Colors.white, fontSize: 18)),
        onPressed: onTap,
      ),
    );
  }

  Widget _errorText(String msg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color:        Colors.red.shade900.withAlpha(120),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(msg, style: const TextStyle(color: Colors.red, fontSize: 13)),
  );
}
