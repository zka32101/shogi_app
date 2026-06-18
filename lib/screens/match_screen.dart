// lib/screens/match_screen.dart
// リアルタイムネットワーク対局画面（盤面同期付き）

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../logic.dart';
import '../piece.dart';
import '../game_screen.dart';
import '../services/matching_service.dart';
import '../services/network_service.dart';
import '../services/board_sync_service.dart';
import '../character_icons.dart';
import 'network_board_widget.dart';
import 'match_chat_widget.dart';
import 'report_user_screen.dart';
import 'match_analyzer_screen.dart';
import '../theme_config.dart';

class MatchScreen extends StatefulWidget {
  final String matchId;
  final bool isPlayer1;

  const MatchScreen({
    super.key,
    required this.matchId,
    required this.isPlayer1,
  });

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final MatchingService _matchingService = MatchingService();
  final NetworkService _networkService = NetworkService();
  final BoardSyncService _boardSync = BoardSyncService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late Stream<NetworkBoardState?> _boardStream;
  bool _isResigning = false;
  bool _showChat = false;
  bool _isMakingMove = false;

  // タイム管理
  Timer? _clockTimer;
  int _myTimeRemaining = 600;
  int _opponentTimeRemaining = 600;
  DateTime? _lastTickAt;

  // 千日手検出: 盤面ハッシュの履歴
  final List<String> _boardHistory = [];
  bool _sennichiteDialogShown = false;

  // キャラクターアイコン
  String? _myCharIconId;

  // 盤面テーマ
  PieceTheme _theme = PieceTheme.standard;

  // 最新の盤面状態キャッシュ（毎回Firestore読まずに使用）
  NetworkBoardState? _latestBoardState;

  // 時計: 30秒毎にRTDB同期
  Timer? _clockSyncTimer;
  int _clockSyncIntervalSec = 0;
  bool _clockInitialized = false;

  @override
  void initState() {
    super.initState();
    _boardStream = _boardSync.watchBoardState(widget.matchId).map((state) {
      _latestBoardState = state;
      // RTDBからの初回時計同期（lastTickMsが0でなければ現在残り時間を再計算）
      if (state != null && state.lastTickMs > 0 && !_clockInitialized) {
        _clockInitialized = true;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final elapsedMs = nowMs - state.lastTickMs;
        final p1Remaining = (state.p1Ms - (state.lastTurn == 1 ? elapsedMs : 0))
            .clamp(0, state.p1Ms);
        final p2Remaining = (state.p2Ms - (state.lastTurn == 2 ? elapsedMs : 0))
            .clamp(0, state.p2Ms);
        _myTimeRemaining       = ((widget.isPlayer1 ? p1Remaining : p2Remaining) / 1000).ceil();
        _opponentTimeRemaining = ((widget.isPlayer1 ? p2Remaining : p1Remaining) / 1000).ceil();
      }
      // 試合終了を検知してクロックを止める
      if (state?.status == 'finished') {
        _clockTimer?.cancel();
        _clockSyncTimer?.cancel();
      }
      return state;
    });
    _startClock();
    _initBoardIfNeeded();
    _loadCharIcon();
    _loadTheme();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _clockSyncTimer?.cancel();
    super.dispose();
  }

  // ── 初期化 ─────────────────────────────────────────────────

  Future<void> _loadCharIcon() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('character_icon_id');
      if (mounted) setState(() => _myCharIconId = id);
    } catch (_) {}
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIdx = prefs.getInt('piece_theme_idx') ?? 0;
      final themes = PieceTheme.values;
      final theme = themeIdx < themes.length ? themes[themeIdx] : PieceTheme.standard;
      if (mounted) setState(() => _theme = theme);
    } catch (_) {}
  }

  Future<void> _initBoardIfNeeded() async {
    try {
      final doc =
          await _firestore.collection('matches').doc(widget.matchId).get();
      if (doc.exists && doc['board'] == null) {
        await _boardSync.initMatchBoard(widget.matchId);
      }
      // 初期タイムはRTDBストリームの初回イベントで設定される（_clockInitializedフラグ）
      // Firestoreの時刻フィールドは使わない
    } catch (e) {
      print('Init board error: $e');
    }
  }

  // ── タイマー管理 ───────────────────────────────────────────

  void _startClock() {
    _lastTickAt = DateTime.now();
    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _tickClock());
  }

  void _tickClock() {
    // ゲーム終了済みなら何もしない
    if (_latestBoardState?.status == 'finished') return;

    final currentTurn = _latestBoardState?.currentTurn ?? 1;
    final isMyTurn = (currentTurn == 1) == widget.isPlayer1;

    if (!mounted) return;
    setState(() {
      if (isMyTurn) {
        _myTimeRemaining = (_myTimeRemaining - 1).clamp(0, 99999);
      } else {
        _opponentTimeRemaining = (_opponentTimeRemaining - 1).clamp(0, 99999);
      }
    });

    // タイムアウト検知（自分の時間切れのみ処理）
    if (isMyTurn && _myTimeRemaining <= 0) {
      _clockTimer?.cancel();
      _clockSyncTimer?.cancel();
      _handleTimeout();
      return;
    }

    // 30秒毎にRTDBへ同期（Firestoreには書かない）
    _clockSyncIntervalSec++;
    if (_clockSyncIntervalSec >= 30) {
      _clockSyncIntervalSec = 0;
      _syncClockToRtdb();
    }
  }

  void _syncClockToRtdb() {
    final p1Ms = (widget.isPlayer1
        ? _myTimeRemaining
        : _opponentTimeRemaining) * 1000;
    final p2Ms = (widget.isPlayer1
        ? _opponentTimeRemaining
        : _myTimeRemaining) * 1000;
    final currentTurn = _latestBoardState?.currentTurn ?? 1;
    _boardSync.syncClock(
      matchId: widget.matchId,
      p1Ms: p1Ms,
      p2Ms: p2Ms,
      currentTurn: currentTurn,
    ).catchError((_) {});
  }

  Future<void> _handleTimeout() async {
    try {
      // opponentIdをRTDB盤面状態から取得（Firestoreを読まない）
      final state = _latestBoardState;
      String? opponentId;
      if (state != null) {
        // RTDBにplayer IDが入っていない場合はFirestoreからフォールバック
        opponentId = widget.isPlayer1
            ? (_latestBoardState == null
                ? null
                : await _getOpponentIdFromFirestore())
            : await _getOpponentIdFromFirestore();
      }
      opponentId ??= await _getOpponentIdFromFirestore();
      if (opponentId == null) return;

      await _networkService.finishMatchWithRating(
          widget.matchId, opponentId, 'timeout');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('時間切れで敗北しました', style: TextStyle(color: Colors.red))),
        );
      }
    } catch (e) {
      print('Timeout error: $e');
    }
  }

  Future<String?> _getOpponentIdFromFirestore() async {
    try {
      final doc = await _firestore.collection('matches').doc(widget.matchId).get();
      if (!doc.exists) return null;
      return widget.isPlayer1
          ? doc['player2_id'] as String?
          : doc['player1_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── 指し手 ─────────────────────────────────────────────────

  Future<void> _onMove(KifuMove move) async {
    if (_isMakingMove) return;
    setState(() => _isMakingMove = true);

    try {
      // キャッシュ済み盤面を使用（Firestoreを毎回読まない）
      final cached = _latestBoardState;
      if (cached == null) return;

      final board  = cached.board;
      final p1Hand = Map<PieceType, int>.from(cached.p1Hand);
      final p2Hand = Map<PieceType, int>.from(cached.p2Hand);

      // 指し手適用後の盤面を計算
      final newBoard  = GL.copy(board);
      final newP1Hand = Map<PieceType, int>.from(p1Hand);
      final newP2Hand = Map<PieceType, int>.from(p2Hand);
      GL.applyKifuMove(newBoard, newP1Hand, newP2Hand, move);

      final nextTurn = widget.isPlayer1 ? 2 : 1;
      final remainingMs = _myTimeRemaining * 1000;

      // RTDBにアトミックに書き込む
      await _boardSync.applyMove(
        matchId: widget.matchId,
        newBoard: newBoard,
        newP1Hand: newP1Hand,
        newP2Hand: newP2Hand,
        nextTurn: nextTurn,
        move: move,
        remainingMsForCurrentPlayer: remainingMs,
      );

      // 指した後の盤面で詰みチェック（上で計算済み）

      final opponentIsP1 = !widget.isPlayer1;
      final isCheckmate = _boardSync.isCheckmate(
        newBoard,
        newP1Hand,
        newP2Hand,
        opponentIsP1,
      );

      if (isCheckmate) {
        final myId = _networkService.currentUser!.uid;
        await _networkService.finishMatchWithRating(
            widget.matchId, myId, 'checkmate');
      } else {
        // 千日手・持将棋チェック
        _checkSpecialEndings(newBoard, newP1Hand, newP2Hand);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _isMakingMove = false);
    }
  }

  // ── 投了 ───────────────────────────────────────────────────

  Future<void> _resign() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('投了しますか？'),
        content: const Text('この対局を終了します。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('投了する')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isResigning = true);
    try {
      final doc =
          await _firestore.collection('matches').doc(widget.matchId).get();
      final opponentId = widget.isPlayer1
          ? doc['player2_id'] as String
          : doc['player1_id'] as String;
      await _networkService.finishMatchWithRating(
          widget.matchId, opponentId, 'resignation');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
        setState(() => _isResigning = false);
      }
    }
  }

  // ── 千日手・持将棋検出 ────────────────────────────────────────

  String _boardHash(
    List<List<Piece?>> board,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
    bool isP1Turn,
  ) {
    final sb = StringBuffer();
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = board[r][c];
        sb.write(p == null ? '.' : '${p.type.index}${p.isPlayer1 ? 'B' : 'W'}');
      }
    }
    sb.write('|');
    for (final e in p1Hand.entries) sb.write('${e.key.index}:${e.value},');
    sb.write('|');
    for (final e in p2Hand.entries) sb.write('${e.key.index}:${e.value},');
    sb.write('|${isP1Turn ? '1' : '2'}');
    return sb.toString();
  }

  void _checkSpecialEndings(
    List<List<Piece?>> board,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
  ) {
    final isP1Turn = !widget.isPlayer1; // 相手番
    final hash = _boardHash(board, p1Hand, p2Hand, isP1Turn);
    _boardHistory.add(hash);

    // 千日手: 同一局面4回
    final count = _boardHistory.where((h) => h == hash).length;
    if (count >= 4 && !_sennichiteDialogShown) {
      _sennichiteDialogShown = true;
      _showSennichiteDialog();
      return;
    }

    // 持将棋: 両玉が相手陣に入りポイントを確認
    if (_checkJishogi(board, p1Hand, p2Hand)) {
      _showJishogiDialog(board, p1Hand, p2Hand);
    }
  }

  bool _checkJishogi(
    List<List<Piece?>> board,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
  ) {
    // 先手玉が敵陣(row 0-2)に、後手玉が敵陣(row 6-8)にいるか
    bool p1KingIn = false, p2KingIn = false;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = board[r][c];
        if (p == null) continue;
        if (p.type == PieceType.king) {
          if (p.isPlayer1 && r <= 2) p1KingIn = true;
          if (!p.isPlayer1 && r >= 6) p2KingIn = true;
        }
      }
    }
    if (!p1KingIn || !p2KingIn) return false;

    // ポイントカウント: 飛・角=5点, 他=1点 (玉除く)
    int _count(List<List<Piece?>> b, Map<PieceType, int> hand, bool isP1) {
      int pts = 0;
      // 盤上の駒
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          final p = b[r][c];
          if (p == null || p.isPlayer1 != isP1 || p.type == PieceType.king) continue;
          final base = p.type == PieceType.rook || p.type == PieceType.bishop ? 5 : 1;
          pts += base;
        }
      }
      // 持ち駒
      for (final e in hand.entries) {
        final base = e.key == PieceType.rook || e.key == PieceType.bishop ? 5 : 1;
        pts += base * e.value;
      }
      return pts;
    }

    final p1Pts = _count(board, p1Hand, true);
    final p2Pts = _count(board, p2Hand, false);
    return p1Pts >= 27 && p2Pts >= 27;
  }

  void _showSennichiteDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('千日手', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        content: const Text(
          '同一局面が4回繰り返されました。\n千日手により引き分けを申し込みますか？',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('続ける'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _proposeDraw('sennichite');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
            child: const Text('引き分けを申し込む', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showJishogiDialog(
    List<List<Piece?>> board,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
  ) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('持将棋', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold)),
        content: const Text(
          '両玉が相手陣に入り点数条件を満たしました。\n持将棋として引き分けを申し込みますか？',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('続ける'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _proposeDraw('jishogi');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan.shade700),
            child: const Text('引き分けを申し込む', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _proposeDraw(String reason) async {
    try {
      await _firestore.collection('matches').doc(widget.matchId).update({
        'draw_proposed_by': _networkService.currentUser?.uid,
        'draw_reason': reason,
        'draw_proposed_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('引き分けを申し込みました。相手の応答を待っています...')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    }
  }

  // ── 通報 ───────────────────────────────────────────────────

  Future<void> _showReportDialog() async {
    try {
      final doc =
          await _firestore.collection('matches').doc(widget.matchId).get();
      final opponentId = widget.isPlayer1
          ? doc['player2_id'] as String?
          : doc['player1_id'] as String?;
      final opponentName = widget.isPlayer1
          ? doc['player2_name'] as String? ?? '相手'
          : doc['player1_name'] as String? ?? '相手';
      if (opponentId == null || !mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportUserScreen(
            reportedUserId: opponentId,
            reportedUsername: opponentName,
            matchId: widget.matchId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    }
  }

  // ── UI ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('対局中です。投了で終了してください。')),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16213E),
          title: const Text('対局中', style: TextStyle(color: Colors.white)),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: Icon(Icons.chat,
                  color: _showChat ? Colors.amber : Colors.white70),
              onPressed: () => setState(() => _showChat = !_showChat),
              tooltip: 'チャット',
            ),
            IconButton(
              icon: const Icon(Icons.flag_outlined, color: Colors.white70),
              onPressed: _showReportDialog,
              tooltip: '通報',
            ),
          ],
        ),
        body: StreamBuilder<NetworkBoardState?>(
          stream: _boardStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final state = snapshot.data!;

            // ゲーム終了
            if (state.isFinished) {
              return _buildGameOverScreen(state);
            }

            final isMyTurn = (state.currentTurn == 1) == widget.isPlayer1;

            return SafeArea(
              child: Column(
                children: [
                  // 相手情報バー
                  _buildPlayerBar(isMe: false),
                  // 盤面
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: NetworkBoardWidget(
                        state: state,
                        isPlayer1: widget.isPlayer1,
                        isMyTurn: isMyTurn && !_isMakingMove,
                        onMove: _onMove,
                        theme: _theme,
                      ),
                    ),
                  ),
                  // 自分情報バー
                  _buildPlayerBar(isMe: true),
                  // 操作ボタン
                  _buildActionBar(isMyTurn),
                  // チャットパネル
                  if (_showChat)
                    SizedBox(
                      height: 200,
                      child: MatchChatWidget(matchId: widget.matchId),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlayerBar({required bool isMe}) {
    final time = isMe ? _myTimeRemaining : _opponentTimeRemaining;
    final isLow = time <= 30;
    final timeStr = _formatTime(time);
    final charIcon = (isMe && _myCharIconId != null)
        ? findCharacterById(_myCharIconId!)
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.blue.shade900.withAlpha(80)
            : Colors.grey.shade900,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (charIcon != null)
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: charIcon.bgColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.cyan.withAlpha(120), width: 1.5),
              ),
              child: Center(
                child: Text(charIcon.emoji, style: const TextStyle(fontSize: 14)),
              ),
            )
          else
            Icon(
              isMe ? Icons.person : Icons.person_outline,
              color: isMe ? Colors.cyan : Colors.white54,
              size: 18,
            ),
          const SizedBox(width: 6),
          Text(
            isMe ? 'あなた' : '相手',
            style: TextStyle(
              color: isMe ? Colors.cyan : Colors.white70,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              color: isLow ? Colors.red : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            child: Text(timeStr),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(bool isMyTurn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0xFF0F0F2E),
      child: Row(
        children: [
          if (isMyTurn)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(40),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'あなたのターン',
                style: TextStyle(
                    color: Colors.amber, fontWeight: FontWeight.bold),
              ),
            )
          else
            const Text('相手の番...',
                style: TextStyle(color: Colors.white54)),
          const Spacer(),
          if (_isMakingMove)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            ElevatedButton.icon(
              onPressed: _isResigning ? null : _resign,
              icon: const Icon(Icons.flag, size: 16),
              label: const Text('投了'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
        ],
      ),
    );
  }

  // ── ゲームオーバー画面 ─────────────────────────────────────

  Widget _buildGameOverScreen(NetworkBoardState state) {
    final myId = _networkService.currentUser?.uid ?? '';
    final isWinner = state.winner == myId;
    final isDraw = state.winner == null;

    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isDraw
                      ? Icons.handshake
                      : isWinner
                          ? Icons.emoji_events
                          : Icons.sentiment_dissatisfied,
                  size: 72,
                  color: isDraw
                      ? Colors.grey
                      : isWinner
                          ? Colors.amber
                          : Colors.grey.shade600,
                ),
                const SizedBox(height: 12),
                Text(
                  isDraw ? '引き分け' : isWinner ? '勝利！' : '敗北',
                  style: TextStyle(
                    color: isDraw
                        ? Colors.grey
                        : isWinner
                            ? Colors.amber
                            : Colors.grey.shade600,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('${state.moveCount}手',
                    style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('一覧に戻る'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MatchAnalyzerScreen(
                              matchId: widget.matchId),
                        ),
                      ),
                      icon: const Icon(Icons.analytics, size: 16),
                      label: const Text('棋譜分析'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // 感想戦チャット
        Expanded(
          flex: 3,
          child: PostMatchChatWidget(matchId: widget.matchId),
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
