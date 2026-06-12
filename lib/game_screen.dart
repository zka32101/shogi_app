// lib/game_screen.dart — メインゲーム画面（全機能）

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'piece.dart';
import 'logic.dart';
import 'character_icons.dart';
import 'ai_personality.dart';
import 'sound_service.dart';
import 'coach_report_screen.dart';
import 'feedback_screen.dart';
import 'ai_data_service.dart';
import 'stats_screen.dart' show ratingToRank, ratingToColor;
import 'rank_badge_widget.dart' show showRankUpDialog;
import 'ghost_service.dart';
import 'purchase_service.dart';
import 'screens/premium_screen.dart';

// ── コーチモード補助関数 ──────────────────────────────
int _pEvalChange(int before, int after, bool wasP1Turn) =>
    wasP1Turn ? after - before : before - after;

String _coachLabel(int change) {
  if (change >= 150) return '★ 好手！';
  if (change >= 30)  return '✓ 良手';
  if (change >= -80) return '';
  if (change >= -200) return '? 疑問手';
  return '✗ 悪手！';
}

Color _coachColor(int change) {
  if (change >= 150) return const Color(0xFF5C9DFF);
  if (change >= 30)  return const Color(0xFF64B5F6);
  if (change >= -80) return Colors.white38;
  if (change >= -200) return const Color(0xFFFF9800);
  return const Color(0xFFEF5350);
}

IconData _coachIcon(int change) {
  if (change >= 150) return Icons.star;
  if (change >= 30)  return Icons.check_circle_outline;
  if (change >= -80) return Icons.remove;
  if (change >= -200) return Icons.warning_amber_outlined;
  return Icons.cancel_outlined;
}

// ===== 盤面ペインター（グリッド＋星＋質感効果） =====
class _BoardPainter extends CustomPainter {
  final Color cellColor;
  final double? advantageRatio;
  final Color borderColor;
  final PieceTheme theme;
  final Color? gradientTop;
  final Color? gradientBottom;

  _BoardPainter({
    required this.cellColor,
    required this.borderColor,
    required this.theme,
    this.advantageRatio,
    this.gradientTop,
    this.gradientBottom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 9;

    // 有利度に応じた背景色（P1有利=青系、P2有利=赤系）
    if (advantageRatio != null && advantageRatio != 0.5) {
      Color advantageColor;
      if (advantageRatio! > 0.5) {
        // P1有利 → 青
        final blend = ((advantageRatio! - 0.5) * 2).clamp(0.0, 1.0);
        advantageColor = Color.lerp(Colors.transparent, Colors.blue.shade900.withAlpha(40), blend)!;
      } else {
        // P2有利 → 赤
        final blend = ((0.5 - advantageRatio!) * 2).clamp(0.0, 1.0);
        advantageColor = Color.lerp(Colors.transparent, Colors.red.shade900.withAlpha(40), blend)!;
      }
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = advantageColor);
    }

    // 質感テーマ用：グラデーション背景を先に描画
    if (theme == PieceTheme.textured && gradientTop != null && gradientBottom != null) {
      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [gradientTop!, gradientBottom!],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), gradientPaint);
    }

    // グリッドラインを描画
    final linePaint = Paint()
      ..color = borderColor
      ..strokeWidth = 0.5;

    // 質感テーマ用：線に陰影を追加
    if (theme == PieceTheme.textured) {
      final shadowPaint = Paint()
        ..color = Colors.black.withAlpha(40)
        ..strokeWidth = 1.5;
      // 縦線（影）
      for (int i = 0; i <= 9; i++) {
        final x = i * cellSize;
        canvas.drawLine(Offset(x + 0.5, 0), Offset(x + 0.5, size.height), shadowPaint);
      }
      // 横線（影）
      for (int i = 0; i <= 9; i++) {
        final y = i * cellSize;
        canvas.drawLine(Offset(0, y + 0.5), Offset(size.width, y + 0.5), shadowPaint);
      }
    }

    // 通常のグリッドラインを描画
    // 縦線
    for (int i = 0; i <= 9; i++) {
      final x = i * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    // 横線
    for (int i = 0; i <= 9; i++) {
      final y = i * cellSize;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // 星を描画（3×3グリッドの交点）
    final starColor = theme == PieceTheme.dark ? Colors.white70 : Colors.black;
    final starPaint = Paint()
      ..color = starColor
      ..style = PaintingStyle.fill;

    // 質感テーマ用：星に光の効果を追加
    if (theme == PieceTheme.textured) {
      final starHighlight = Paint()
        ..color = Colors.white.withAlpha(80)
        ..style = PaintingStyle.fill;
      final starRadius = cellSize * 0.08;
      const starPositions = [
        (2, 2), (2, 5), (2, 8),
        (5, 2), (5, 5), (5, 8),
        (8, 2), (8, 5), (8, 8),
      ];
      for (final (row, col) in starPositions) {
        final x = col * cellSize + cellSize / 2;
        final y = row * cellSize + cellSize / 2;
        // 星の内側に光を追加
        canvas.drawCircle(Offset(x - 1, y - 1), starRadius * 0.6, starHighlight);
      }
    }

    final starRadius = cellSize * 0.08;
    const starPositions = [
      (2, 2), (2, 5), (2, 8),
      (5, 2), (5, 5), (5, 8),
      (8, 2), (8, 5), (8, 8),
    ];

    for (final (row, col) in starPositions) {
      final x = col * cellSize + cellSize / 2;
      final y = row * cellSize + cellSize / 2;
      canvas.drawCircle(Offset(x, y), starRadius, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is _BoardPainter) {
      return oldDelegate.theme != theme ||
          oldDelegate.cellColor != cellColor ||
          oldDelegate.borderColor != borderColor ||
          oldDelegate.gradientTop != gradientTop ||
          oldDelegate.gradientBottom != gradientBottom;
    }
    return true;
  }
}

// ===== 設定 =====
enum GameMode {
  pvp,           // ローカル対人対局
  vsAI,          // AI対局
  network,       // オンライン対局
  spectator,     // 観戦
  localNetwork,  // ローカルネットワーク対局
}

enum AILevel { random, easy, medium, hard }

extension AILevelLabel on AILevel {
  String get rankLabel {
    switch (this) {
      case AILevel.random:
        return 'ランダム';
      case AILevel.easy:
        return '初級';
      case AILevel.medium:
        return '中級';
      case AILevel.hard:
        return '上級';
    }
  }

  String get rankDesc {
    switch (this) {
      case AILevel.random:
        return 'ランダムな手を指します';
      case AILevel.easy:
        return '初心者向けのレベルです';
      case AILevel.medium:
        return '中級者向けのレベルです';
      case AILevel.hard:
        return '上級者向けの高いレベルです';
    }
  }
}

enum VariantType {
  normal,         // 標準的な将棋
  captureForced,  // 取る一手（駒を取れば取らなければならない）
  checkForced,    // 王手将棋（王手できれば王手しなければならない）
  hiddenPieces,   // かくし将棋（相手の駒が見えない）
  kagemusha,      // 影武者（相手の王が見えない）
  invader,        // インベーダー将棋
}

extension VariantTypeLabel on VariantType {
  String get label {
    switch (this) {
      case VariantType.normal:
        return '標準';
      case VariantType.captureForced:
        return '取る一手';
      case VariantType.checkForced:
        return '王手将棋';
      case VariantType.hiddenPieces:
        return 'かくし将棋';
      case VariantType.kagemusha:
        return '影武者';
      case VariantType.invader:
        return 'インベーダー';
    }
  }
}

enum PieceTheme {
  standard,  // 標準
  dark,      // ダーク
  textured,  // 質感（プレミアム）
  emerald,   // エメラルド（プレミアム）
  cherry,    // 桜（プレミアム）
}

/// 駒落ちハンデ（後手 = 上手 の駒を減らす）
enum Handicap {
  none,         // 平手
  lance,        // 香落ち（左香）
  bishop,       // 角落ち
  rook,         // 飛車落ち
  rookBishop,   // 飛角落ち
  four,         // 四枚落ち（飛・角・両香）
  six,          // 六枚落ち（飛・角・両香・両桂）
  eight,        // 八枚落ち（飛・角・両香・両桂・両銀）
}

extension HandicapLabel on Handicap {
  String get label {
    switch (this) {
      case Handicap.none:       return '平手';
      case Handicap.lance:      return '香落ち';
      case Handicap.bishop:     return '角落ち';
      case Handicap.rook:       return '飛車落ち';
      case Handicap.rookBishop: return '飛角落ち';
      case Handicap.four:       return '四枚落ち';
      case Handicap.six:        return '六枚落ち';
      case Handicap.eight:      return '八枚落ち';
    }
  }
}

class GameSettings {
  final GameMode mode;
  final AILevel aiLevel;
  final bool aiIsP2; // AI が後手か
  final int? timeLimitSec; // null=制限なし
  final int? byoyomiSec; // 秒読み（null=なし）
  final int fischerIncrementSec; // フィッシャー加算（0=なし）
  final PieceTheme theme;
  final Handicap handicap;
  final VariantType variant;
  final bool aiRated;
  final bool castleGuideEnabled;
  final String castleGuideName;
  final int castleGuideMaxPly;
  final bool networkIsHost; // ネットワーク対局でホストか
  final bool networkRated; // ネットワーク対局でレーティング戦か
  final bool coachMode;   // コーチモード（指導対局）
  final String? opponentCharacterId; // AIの棋風キャラID（null=デフォルト）

  const GameSettings({
    this.mode = GameMode.pvp,
    this.aiLevel = AILevel.easy,
    this.aiIsP2 = true,
    this.timeLimitSec,
    this.byoyomiSec,
    this.fischerIncrementSec = 0,
    this.theme = PieceTheme.standard,
    this.handicap = Handicap.none,
    this.variant = VariantType.normal,
    this.aiRated = true,
    this.castleGuideEnabled = false,
    this.castleGuideName = 'mino',
    this.castleGuideMaxPly = 30,
    this.networkIsHost = false,
    this.networkRated = true,
    this.coachMode = false,
    this.opponentCharacterId,
  });

  int get aiDepth {
    switch (aiLevel) {
      case AILevel.random:
        return 0;
      case AILevel.easy:
        return 2;  // 置換表効果で旧depth=3相当
      case AILevel.medium:
        return 3;  // 置換表効果で旧depth=4相当
      case AILevel.hard:
        return 5;  // 置換表+killer+historyで旧depth=7相当
    }
  }
}

// ===== 棋譜表記補助 =====
const _rowKanji = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
String _sq(int r, int c) => '${9 - c}${_rowKanji[r]}';

// ===== GameScreen =====
class GameScreen extends StatefulWidget {
  final GameSettings settings;
  // カスタム初期配置（局面エディタから渡す場合に使用）
  final List<List<Piece?>>? initialBoard;
  final Map<PieceType, int>? initialP1Hand;
  final Map<PieceType, int>? initialP2Hand;
  final bool initialP1Turn;

  const GameScreen({
    super.key,
    required this.settings,
    this.initialBoard,
    this.initialP1Hand,
    this.initialP2Hand,
    this.initialP1Turn = true,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  // --- 盤面状態 ---
  late List<List<Piece?>> board;
  Map<PieceType, int> p1Hand = {}, p2Hand = {};
  bool p1Turn = true;
  String? result;

  // --- 選択 ---
  int? selR, selC;
  PieceType? selHand;
  var hl = _eHL();

  // --- 棋譜 ---
  List<KifuMove> kifu = [];

  // --- タイマー ---
  Timer? _timer;
  int p1Time = 0, p2Time = 0;

  // --- UI ---
  bool showKifu = false;
  bool _aiThinking = false;
  bool showAttackMap = true;
  List<List<int>>? _p1AtkMap, _p2AtkMap; // 効きマップキャッシュ（絶対：先手/後手）
  bool _analysisMode = false; // 局面分析モード
  AMove? _hintMove; // ヒント手
  int? lastFR, lastFC, lastTR, lastTC;

  // --- 評価値バー ---
  int _evalScore = 0; // 正=先手有利 負=後手有利

  // --- コーチモード ---
  final List<List<List<Piece?>>> _boardSnaps = [];
  final List<Map<PieceType, int>> _p1HandSnaps = [];
  final List<Map<PieceType, int>> _p2HandSnaps = [];
  final List<bool> _p1TurnSnaps = [];
  List<List<Piece?>>? _coachInitialBoard; // 対局開始時盤面（講評用）
  String? _coachBadgeText;
  Color _coachBadgeColor = Colors.white38;
  IconData _coachBadgeIcon = Icons.remove;
  Timer? _coachBadgeTimer;

  // --- キャラクターアイコン ---
  String? _charIconId; // 自分（先手 or 人間側）のアイコンID

  // --- AIキャラセリフ ---
  String? _aiDialogue;       // 表示中のセリフ（null=非表示）
  bool _dialogueVisible = false;

  // --- 局面メモ ---
  final Map<int, String> _memos = {}; // moveIndex → memo text
  bool _showMemoOverlay = false;

  // --- アニメーション ---
  late AnimationController _anim;
  late Animation<double> _animVal;

  GameSettings get s => widget.settings;
  bool get vsAI => s.mode == GameMode.vsAI;
  bool get isAITurn => vsAI && ((s.aiIsP2 && !p1Turn) || (!s.aiIsP2 && p1Turn));
  // ユーザーは常に下（後手）に表示
  bool get _userIsP2 => vsAI ? !s.aiIsP2 : false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animVal = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);
    // 通常初期配置 or エディタからのカスタム配置
    board = widget.initialBoard != null
        ? GL.copy(widget.initialBoard!)
        : _initBoard(s.handicap);
    if (widget.initialP1Hand != null) p1Hand = Map.from(widget.initialP1Hand!);
    if (widget.initialP2Hand != null) p2Hand = Map.from(widget.initialP2Hand!);
    p1Turn = widget.initialP1Turn;

    if (s.timeLimitSec != null) {
      p1Time = s.timeLimitSec!;
      p2Time = s.timeLimitSec!;
      _startTimer();
    }
    _updateAtkMap();
    // コーチモード: 初期盤面を保存
    if (s.coachMode) {
      _coachInitialBoard = GL.copy(board);
    }
    _loadCharacterIcon();
    // AIパーソナリティを設定
    if (vsAI) {
      final pers = getPersonality(s.opponentCharacterId);
      AI.setPersonality(pers, aiIsP1: !s.aiIsP2);
      // 対局開始セリフ
      if (s.opponentCharacterId != null) {
        _showDialogue(DialogueTrigger.gameStart);
      }
    }
    // AI が先手の場合は最初の手番を AI に渡す
    if (vsAI && !s.aiIsP2) {
      Future.delayed(const Duration(milliseconds: 600), _runAI);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _timer?.cancel();
    _coachBadgeTimer?.cancel();
    AI.setPersonality(null); // パーソナリティをリセット
    super.dispose();
  }

  // ===== コーチモード: スナップショット保存 =====
  void _saveSnap() {
    _boardSnaps.add(GL.copy(board));
    _p1HandSnaps.add(Map.from(p1Hand));
    _p2HandSnaps.add(Map.from(p2Hand));
    _p1TurnSnaps.add(p1Turn);
  }

  // ===== コーチモード: 待った =====
  Future<void> _takata() async {
    if (!s.coachMode) return;
    final undoCount = vsAI ? 2 : 1;
    if (kifu.length < undoCount || _boardSnaps.length < undoCount) return;

    final targetIdx = kifu.length - undoCount;

    setState(() {
      board = GL.copy(_boardSnaps[targetIdx]);
      p1Hand = Map.from(_p1HandSnaps[targetIdx]);
      p2Hand = Map.from(_p2HandSnaps[targetIdx]);
      p1Turn = _p1TurnSnaps[targetIdx];

      kifu = List.from(kifu.sublist(0, targetIdx));
      _boardSnaps.removeRange(targetIdx, _boardSnaps.length);
      _p1HandSnaps.removeRange(targetIdx, _p1HandSnaps.length);
      _p2HandSnaps.removeRange(targetIdx, _p2HandSnaps.length);
      _p1TurnSnaps.removeRange(targetIdx, _p1TurnSnaps.length);

      lastFR = null; lastFC = null; lastTR = null; lastTC = null;
      _coachBadgeText = null;
      _hintMove = null;
      result = null;
      _clearSel();
      _evalScore = AI.eval(board, p1Hand, p2Hand);
      _updateAtkMap();
    });

    // ベスト手をヒントとして表示
    final mv = await Future(() => AI.bestMove(board, p1Hand, p2Hand, p1Turn, 2));
    if (mounted) setState(() => _hintMove = mv);
  }

  // ===== コーチモード: バッジ表示 =====
  void _showCoachBadge(int evalChange) {
    final label = _coachLabel(evalChange);
    if (label.isEmpty) return;
    _coachBadgeTimer?.cancel();
    setState(() {
      _coachBadgeText = label;
      _coachBadgeColor = _coachColor(evalChange);
      _coachBadgeIcon = _coachIcon(evalChange);
    });
    _coachBadgeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _coachBadgeText = null);
    });
  }

  // ===== コーチモード: 1局講評画面へ =====
  void _openCoachReport() {
    if (_coachInitialBoard == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoachReportScreen(
          kifu: List.from(kifu),
          initialBoard: _coachInitialBoard!,
          result: result ?? '未終了',
          playerIsP1: !s.aiIsP2, // AI が後手なら player は先手
        ),
      ),
    );
  }

  // ===== 効きマップ更新（setState 内から呼ぶ）=====
  void _updateAtkMap() {
    if (showAttackMap) {
      // 絶対座標で先手/後手を固定計算（手番に依存しない）
      _p1AtkMap = GL.attackMap(board, true);  // 先手の利き
      _p2AtkMap = GL.attackMap(board, false); // 後手の利き
    } else {
      _p1AtkMap = null;
      _p2AtkMap = null;
    }
  }

  // ===== 局面分析ヒント計算 =====
  Future<void> _computeHint() async {
    if (result != null || isAITurn) return;
    // depth 2 で AI の最善手を非同期計算
    final mv = await Future(
      () => AI.bestMove(board, p1Hand, p2Hand, p1Turn, 2),
    );
    if (mounted) setState(() => _hintMove = mv);
  }

  // ===== タイマー =====
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (result != null || _aiThinking) return;
      setState(() {
        if (p1Turn) {
          p1Time--;
          if (p1Time <= 0) {
            p1Time = 0;
            result = '後手の勝ち！（時間切れ）';
            _timer?.cancel();
          }
        } else {
          p2Time--;
          if (p2Time <= 0) {
            p2Time = 0;
            result = '先手の勝ち！（時間切れ）';
            _timer?.cancel();
          }
        }
      });
    });
  }

  String _fmt(int sec) =>
      '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';

  // ===== 選択解除 =====
  void _clearSel() {
    selR = null;
    selC = null;
    selHand = null;
    hl = _eHL();
  }

  Map<PieceType, int> get _curH => p1Turn ? p1Hand : p2Hand;
  Map<PieceType, int> get _oppH => p1Turn ? p2Hand : p1Hand;
  bool get _showAds => !PurchaseService.isPremium;
  static List<List<bool>> _eHL() =>
      List.generate(9, (_) => List.filled(9, false));

  // ===== サブスクリプション =====
  // ===== AIセリフ表示 =====
  void _showDialogue(DialogueTrigger trigger) {
    final line = getRandomDialogue(s.opponentCharacterId, trigger);
    if (line == null || !mounted) return;
    setState(() {
      _aiDialogue = line;
      _dialogueVisible = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _dialogueVisible = false);
    });
  }

  void _loadCharacterIcon() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final charIconId = prefs.getString('character_icon_id');
      if (mounted) {
        setState(() {
          _charIconId = charIconId;
        });
      }
    } catch (_) {}
  }

  void _goToPremium() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PremiumScreen()),
    );
  }

  // ===== 局面メモ =====
  void _openMemoDialog() {
    final moveIdx = kifu.length; // 現在の手数でメモ
    final existing = _memos[moveIdx] ?? '';
    final ctrl = TextEditingController(text: existing);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: Text(
          '手数${moveIdx}のメモ',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          maxLength: 200,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'この局面についてメモ...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.grey.shade900,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          if (existing.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() => _memos.remove(moveIdx));
                Navigator.pop(context);
              },
              child: const Text('削除', style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            onPressed: () {
              final text = ctrl.text.trim();
              setState(() {
                if (text.isEmpty) {
                  _memos.remove(moveIdx);
                } else {
                  _memos[moveIdx] = text;
                }
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
            child: const Text('保存', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // ===== 成りダイアログ =====
  Future<bool?> _askPromo() => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text('成りますか？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('成らない'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('成る'),
        ),
      ],
    ),
  );

  // ===== 手番終了処理 =====
  void _endTurn() {
    final next = !p1Turn;
    final hand = next ? p1Hand : p2Hand;
    if (!GL.hasLegalMove(board, next, hand)) {
      result = GL.inCheck(board, next)
          ? (p1Turn ? '先手の勝ち！🎉' : '後手の勝ち！🎉')
          : '引き分け（千日手）';
      _timer?.cancel();
      SoundService.playGameEnd();
      // ゲーム終了ダイアログ表示
      if (mounted) {
        Future.microtask(() => _showGameEndDialog());
      }
    } else if (GL.inCheck(board, next)) {
      // 王手音
      SoundService.playCheck();
    }
    // コーチバッジ（p1Turn 切替前、AI判定が正確）
    if (s.coachMode && kifu.isNotEmpty && result == null) {
      final humanJustMoved = !vsAI || !isAITurn;
      if (humanJustMoved) {
        final change = _pEvalChange(_evalScore, _evalScore, kifu.last.p1);
        _showCoachBadge(change);
      }
    } else {
      // AI対局中: 人間が指した後にセリフトリガー（coachModeでない場合）
      if (vsAI && kifu.isNotEmpty && s.opponentCharacterId != null && result == null) {
        final humanJustMoved = isAITurn; // これからAI番 = 人間が今指した
        if (humanJustMoved) {
          final change = _pEvalChange(_evalScore, _evalScore, kifu.last.p1);
          if (change >= 150) {
            _showDialogue(DialogueTrigger.opponentGoodMove);
          } else if (change <= -200) {
            _showDialogue(DialogueTrigger.opponentBadMove);
          }
        }
      }
    }

    // フィッシャー方式: 指した側の残り時間に加算
    if (s.fischerIncrementSec > 0 && s.timeLimitSec != null && result == null) {
      if (p1Turn) {
        // p1Turn はまだ切り替わっていないので「今動いたのは先手」
        p1Time = (p1Time + s.fischerIncrementSec).clamp(0, 3600);
      } else {
        p2Time = (p2Time + s.fischerIncrementSec).clamp(0, 3600);
      }
    }

    p1Turn = next;
    _updateAtkMap();
    if (_analysisMode && result == null && !isAITurn) _computeHint();
    if (result == null && isAITurn) {
      Future.delayed(const Duration(milliseconds: 100), _runAI);
    }
  }

  // ゲーム終了ダイアログ
  void _showGameEndDialog() {
    if (!mounted || result == null) return;
    // AI対局終了セリフ
    if (vsAI && s.opponentCharacterId != null) {
      final aiWon = result!.contains(s.aiIsP2 ? '後手' : '先手');
      _showDialogue(aiWon ? DialogueTrigger.aiWins : DialogueTrigger.aiLoses);
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          result!,
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Text(
              '${kifu.length}手で終局',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            // コーチモード: AI講評ボタン
            if (s.coachMode && kifu.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.psychology, size: 20),
                  label: const Text('AI講評を見る', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _openCoachReport();
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (kifu.length >= 2 && !result!.contains('勝ち') == false) // プレイヤーが負けた場合
                  ElevatedButton.icon(
                    icon: const Icon(Icons.repeat),
                    label: const Text('リベンジ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _loadDefeatAndReplay();
                    },
                  ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('新局'),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      board = _initBoard(s.handicap);
                      p1Hand = {};
                      p2Hand = {};
                      p1Turn = true;
                      result = null;
                      kifu = [];
                      _coachInitialBoard = s.coachMode ? GL.copy(board) : null;
                      _boardSnaps.clear();
                      _p1HandSnaps.clear();
                      _p2HandSnaps.clear();
                      _p1TurnSnaps.clear();
                      _clearSel();
                      lastFR = null;
                      lastFC = null;
                      lastTR = null;
                      lastTC = null;
                      _hintMove = null;
                      _updateAtkMap();
                      if (s.timeLimitSec != null) {
                        p1Time = s.timeLimitSec!;
                        p2Time = s.timeLimitSec!;
                        _startTimer();
                      }
                      if (vsAI && !s.aiIsP2)
                        Future.delayed(const Duration(milliseconds: 600), _runAI);
                    });
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.home),
                  label: const Text('ホーム'),
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Then close game screen
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===== AI 実行 =====
  Future<void> _runAI() async {
    if (result != null || !mounted) return;
    setState(() => _aiThinking = true);
    try {
      await Future.delayed(Duration(milliseconds: 100 + Random().nextInt(200)));
      if (!mounted || result != null) return;

      // ── オープニングブック参照（序盤20手以内・中級以上） ──
      AMove? mv;
      if (kifu.length < 20 && s.aiDepth >= 2) {
        mv = AiDataService.lookupOpeningBook(board, kifu.length);
      }

      // ── ブックにない場合は探索（棋風による深さ補正を適用）──
      final pers = getPersonality(s.opponentCharacterId);
      final depthBonus = pers?.depthBonus ?? 0;
      final effectiveDepth = (s.aiDepth + depthBonus).clamp(1, 6);
      mv ??= await Future(() => AI.bestMove(board, p1Hand, p2Hand, !s.aiIsP2, effectiveDepth));

      if (mv == null) {
        if (mounted) setState(() => _aiThinking = false);
        return;
      }
      if (mounted) {
        setState(() {
          _applyAIMove(mv!);
          _aiThinking = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _aiThinking = false);
    }
  }

  void _applyAIMove(AMove mv) {
    if (s.coachMode) _saveSnap(); // スナップショット保存（AI指手前）
    final aiP1 = !s.aiIsP2;
    final note = mv.drop != null
        ? '${_sq(mv.tr, mv.tc)}${pieceLabel(mv.drop!)}打'
        : '${_sq(mv.tr, mv.tc)}${board[mv.fr][mv.fc]!.label}${mv.promote ? "成" : ""}';

    if (mv.drop != null) {
      SoundService.playDrop();
      board[mv.tr][mv.tc] = Piece(mv.drop!, aiP1);
      final h = aiP1 ? p1Hand : p2Hand;
      h[mv.drop!] = (h[mv.drop!] ?? 1) - 1;
      if (h[mv.drop!] == 0) h.remove(mv.drop!);
    } else {
      final piece = board[mv.fr][mv.fc]!;
      final cap = board[mv.tr][mv.tc];
      if (cap != null) {
        SoundService.playCapture();
        final h = aiP1 ? p1Hand : p2Hand;
        final bt = cap.baseType;
        h[bt] = (h[bt] ?? 0) + 1;
      } else {
        SoundService.playMove();
      }
      board[mv.tr][mv.tc] = mv.promote
          ? Piece(piece.promotedType, piece.isPlayer1)
          : piece;
      board[mv.fr][mv.fc] = null;
    }
    lastFR = mv.fr;
    lastFC = mv.fc;
    lastTR = mv.tr;
    lastTC = mv.tc;
    _anim.forward(from: 0);
    kifu.add(KifuMove(kifu.length + 1, aiP1, note,
        fr: mv.fr, fc: mv.fc, tr: mv.tr, tc: mv.tc,
        drop: mv.drop, promote: mv.promote));
    _hintMove = null;
    _endTurn();
  }

  // ===== 投了 =====
  Future<void> _resign() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('投了しますか？'),
        content: Text('${p1Turn ? "▲先手" : "△後手"}が投了します。よろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('投了する', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      SoundService.playResign();
      setState(() {
        result = p1Turn ? '後手の勝ち！（先手投了）' : '先手の勝ち！（後手投了）';
        _timer?.cancel();
      });
    }
  }

  // ===== KIF エクスポート =====
  void _showKifExport() {
    final buf = StringBuffer();
    buf.writeln('# 将棋アプリ 棋譜');
    buf.writeln('# ${DateTime.now().toString().substring(0, 16)}');
    buf.writeln('手数----指手----------');
    for (final m in kifu) {
      buf.writeln(m.text);
    }
    final text = buf.toString();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('棋譜エクスポート', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 400,
          height: 300,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F2A40),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      text,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('クリップボードにコピー'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  Navigator.pop(context);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('クリップボードにコピーしました'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  // ===== 棋譜を保存（JSON 複数対応）=====
  Future<void> _saveKifu() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 既存リストを読み込み
      final raw = prefs.getString('kifu_records') ?? '[]';
      final List<dynamic> list = jsonDecode(raw);
      // 新しいレコードを先頭に追加（最大20件）
      final record = {
        'date': DateTime.now().toString().substring(0, 16),
        'result': result ?? '未完了',
        'mode': s.mode == GameMode.vsAI ? 'AI対局' : '二人対局',
        'handicap': s.handicap.label,
        'moveCount': kifu.length,
        'moves': kifu.map((m) => m.toJson()).toList(),
      };
      list.insert(0, record);
      if (list.length > 20) list.removeLast();
      await prefs.setString('kifu_records', jsonEncode(list));
      // 対局統計を更新
      await _updateStats();
      // ゴーストデータをバックグラウンドでアップロード（fire-and-forget）
      GhostService.updateMyGhost();
      // ストリーク更新（週次・月次）
      await _updateStreaks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('棋譜を保存しました'),
              duration: Duration(seconds: 2)),
        );
      }
    } catch (_) {}
  }

  // ===== この局面をフィードバック報告 =====
  void _reportPosition() {
    // 直近20手の棋譜テキストを作成
    final recent = kifu.length > 20
        ? kifu.sublist(kifu.length - 20)
        : kifu;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FeedbackScreen(
          board:      board,
          p1Hand:     Map.from(p1Hand),
          p2Hand:     Map.from(p2Hand),
          recentKifu: recent.map((m) => m.text).toList(),
          moveCount:  kifu.length,
        ),
      ),
    );
  }

  // ===== 対局統計を更新 =====
  Future<void> _updateStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final total = (prefs.getInt('stats_total') ?? 0) + 1;
      await prefs.setInt('stats_total', total);
      await prefs.setInt('stats_moves_sum',
          (prefs.getInt('stats_moves_sum') ?? 0) + kifu.length);

      // 勝敗判定
      bool? playerWon;
      if (result != null) {
        if (vsAI) {
          final playerIsP1 = !s.aiIsP2;
          playerWon = (result!.contains('先手') && playerIsP1) ||
                      (result!.contains('後手') && !playerIsP1);
        }
        if (result!.contains('先手')) {
          await prefs.setInt('stats_p1_wins', (prefs.getInt('stats_p1_wins') ?? 0) + 1);
        } else if (result!.contains('後手')) {
          await prefs.setInt('stats_p2_wins', (prefs.getInt('stats_p2_wins') ?? 0) + 1);
        }
      }

      // 棋風診断用統計（先手視点）
      final playerMoves = vsAI
          ? kifu.where((m) => m.p1 != s.aiIsP2).toList()
          : kifu.where((m) => m.p1).toList();
      final totalPM = playerMoves.length;
      if (totalPM > 0) {
        final attackMvs = playerMoves.where((m) => m.drop == null && m.tr < m.fr).length;
        final retreatMvs = playerMoves.where((m) => m.drop == null && m.tr > m.fr).length;
        final dropMvs = playerMoves.where((m) => m.drop != null).length;
        await prefs.setInt('playstyle_attack', (prefs.getInt('playstyle_attack') ?? 0) + attackMvs);
        await prefs.setInt('playstyle_retreat', (prefs.getInt('playstyle_retreat') ?? 0) + retreatMvs);
        await prefs.setInt('playstyle_drop', (prefs.getInt('playstyle_drop') ?? 0) + dropMvs);
        await prefs.setInt('playstyle_total', (prefs.getInt('playstyle_total') ?? 0) + totalPM);
        await prefs.setInt('playstyle_games', (prefs.getInt('playstyle_games') ?? 0) + 1);
      }

      // 絆レベル更新（対局で使用したキャラがいれば +1）
      String? charId = s.opponentCharacterId;
      if (charId != null) {
        final key = 'character_bond_level_$charId';
        final currentLevel = prefs.getInt(key) ?? 0;
        await prefs.setInt(key, currentLevel + 1);
      }

      // リベンジ用：敗着検出（プレイヤーが負けた場合）
      if (playerWon == false && kifu.length >= 2) {
        _detectDefeatMove();
      }

      // レーティング更新（AI対局・レーティング戦のみ）
      if (vsAI && s.aiRated && playerWon != null) {
        final prevRating = prefs.getInt('rating_current') ?? 700;
        final prevRankStr = ratingToRank(prevRating);

        // Elo 変動量（難度別）
        final delta = playerWon
            ? [5, 10, 20, 35][s.aiLevel.index]
            : [-3, -7, -15, -20][s.aiLevel.index];
        final newRating = (prevRating + delta).clamp(0, 9999);

        await prefs.setInt('rating_current', newRating);
        await prefs.setInt('rating_ai_current', newRating);

        // 昇段チェック
        final newRankStr = ratingToRank(newRating);
        if (newRankStr != prevRankStr && delta > 0 && mounted) {
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) {
            await showRankUpDialog(context, newRankStr, ratingToColor(newRating));
          }
        }
      }
    } catch (_) {}
  }

  // ===== ストリーク更新（週次・月次） =====
  Future<void> _updateStreaks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final weekKey = '${now.year}-W${(now.day / 7).ceil()}';
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      if (result != null && result!.contains('勝')) {
        // 勝利時のみストリーク更新
        final weekStreak = (prefs.getInt('weekly_streak_$weekKey') ?? 0) + 1;
        final monthStreak = (prefs.getInt('monthly_streak_$monthKey') ?? 0) + 1;
        await prefs.setInt('weekly_streak_$weekKey', weekStreak);
        await prefs.setInt('monthly_streak_$monthKey', monthStreak);
      } else if (result != null) {
        // 敗北時はストリークリセット
        await prefs.remove('weekly_streak_$weekKey');
        await prefs.remove('monthly_streak_$monthKey');
      }
    } catch (_) {}
  }

  // ===== リベンジ: 敗着から再開 =====
  void _loadDefeatAndReplay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final kifuJson = prefs.getString('last_defeat_kifu');
      if (kifuJson == null) return;

      final List<dynamic> moves = jsonDecode(kifuJson);
      final playerIsP1 = !s.aiIsP2;

      // 初期盤面に戻す
      setState(() {
        board = _initBoard(s.handicap);
        p1Hand = {};
        p2Hand = {};
        p1Turn = true;
        result = null;
        kifu = [];
        _coachInitialBoard = s.coachMode ? GL.copy(board) : null;
        _boardSnaps.clear();
        _p1HandSnaps.clear();
        _p2HandSnaps.clear();
        _p1TurnSnaps.clear();
        _clearSel();
        lastFR = null;
        lastFC = null;
        lastTR = null;
        lastTC = null;
        _hintMove = null;
      });

      // 敗着までの棋譜を再生
      for (final moveJson in moves) {
        final km = KifuMove.fromJson(moveJson as Map<String, dynamic>);
        GL.applyKifuMove(board, p1Hand, p2Hand, km);
        kifu.add(km);
        p1Turn = !km.p1;
      }

      setState(() {
        _updateAtkMap();
        if (s.timeLimitSec != null) {
          p1Time = s.timeLimitSec!;
          p2Time = s.timeLimitSec!;
          _startTimer();
        }
      });

      // AIが後手の場合は思考開始
      if (vsAI && !s.aiIsP2 && p1Turn) {
        Future.delayed(const Duration(milliseconds: 600), _runAI);
      }
    } catch (_) {}
  }

  // ===== リベンジ: 敗着検出 =====
  void _detectDefeatMove() async {
    try {
      final playerIsP1 = !s.aiIsP2;
      var testBoard = List.generate(9, (_) => List<Piece?>.filled(9, null));
      var testP1Hand = <PieceType, int>{};
      var testP2Hand = <PieceType, int>{};

      // 初期盤面をコピー
      for (int i = 0; i < 9; i++) {
        for (int j = 0; j < 9; j++) {
          testBoard[i][j] = board[i][j];
        }
      }
      testP1Hand = Map.from(p1Hand);
      testP2Hand = Map.from(p2Hand);

      int defeatIdx = -1;
      int worstEval = 0;

      // 棋譜を再生しながら敗着を検出
      for (int i = 0; i < kifu.length; i++) {
        final move = kifu[i];
        final isPlayerMove = move.p1 == playerIsP1;

        if (isPlayerMove) {
          // 駒数ベースの簡易評価（少ないほど不利）
          int piecesOnBoard = 0;
          for (int r = 0; r < 9; r++)
            for (int c = 0; c < 9; c++)
              if (testBoard[r][c] != null && testBoard[r][c]!.isPlayer1 == playerIsP1) piecesOnBoard++;
          final handPieces = (playerIsP1 ? testP1Hand : testP2Hand).values.fold(0, (a, b) => a + b);
          final eval = piecesOnBoard + handPieces;
          if (eval < worstEval || worstEval == 0) {
            worstEval = eval;
            defeatIdx = i;
          }
        }

        // 手を適用
        if (move.drop != null) {
          testBoard[move.tr][move.tc] = Piece(move.drop!, move.p1);
          final hand = move.p1 ? testP1Hand : testP2Hand;
          hand[move.drop!] = (hand[move.drop!] ?? 1) - 1;
          if (hand[move.drop!] == 0) hand.remove(move.drop!);
        } else {
          final piece = testBoard[move.fr][move.fc]!;
          final cap = testBoard[move.tr][move.tc];
          if (cap != null) {
            final hand = move.p1 ? testP1Hand : testP2Hand;
            hand[cap.baseType] = (hand[cap.baseType] ?? 0) + 1;
          }
          testBoard[move.tr][move.tc] = move.promote ? Piece(piece.promotedType, piece.isPlayer1) : piece;
          testBoard[move.fr][move.fc] = null;
        }
      }

      if (defeatIdx >= 0) {
        // 敗着までの棋譜を保存
        final defeatKifu = kifu.sublist(0, defeatIdx + 1);
        final kifuJson = defeatKifu.map((m) => m.toJson()).toList();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_defeat_kifu', jsonEncode(kifuJson));
      }
    } catch (_) {}
  }

  // ===== セルタップ =====
  Future<void> _onCell(int row, int col) async {
    if (result != null || _aiThinking) return;
    if (vsAI && isAITurn) return;

    // 持ち駒を打つ
    if (selHand != null) {
      if (hl[row][col]) {
        final type = selHand!;
        final note = '${_sq(row, col)}${pieceLabel(type)}打';
        SoundService.playDrop();
        if (s.coachMode) _saveSnap(); // スナップショット保存
        setState(() {
          board[row][col] = Piece(type, p1Turn);
          final hand = p1Turn ? p1Hand : p2Hand;
          hand[type] = (hand[type] ?? 0) - 1;
          if ((hand[type] ?? 0) <= 0) hand.remove(type);
          lastFR = -1;
          lastFC = -1;
          lastTR = row;
          lastTC = col;
          _anim.forward(from: 0);
          kifu.add(KifuMove(kifu.length + 1, p1Turn, note,
              tr: row, tc: col, drop: type));
          _hintMove = null;
          _clearSel();
          _endTurn();
        });
      } else {
        setState(_clearSel);
      }
      return;
    }

    final piece = board[row][col];

    if (selR == null) {
      if (piece != null && piece.isPlayer1 == p1Turn) {
        final moves = GL.legal(board, row, col);
        setState(() {
          selR = row;
          selC = col;
          hl = _eHL();
          for (final m in moves) hl[m.$1][m.$2] = true;
        });
      }
      return;
    }

    if (selR == row && selC == col) {
      setState(_clearSel);
      return;
    }

    if (piece != null && piece.isPlayer1 == p1Turn) {
      final moves = GL.legal(board, row, col);
      setState(() {
        selR = row;
        selC = col;
        hl = _eHL();
        for (final m in moves) hl[m.$1][m.$2] = true;
      });
      return;
    }

    if (!hl[row][col]) {
      setState(_clearSel);
      return;
    }

    // 移動実行
    final moving = board[selR!][selC!]!;
    bool promote = false;
    bool inZone(bool p1, int r) => p1 ? r <= 2 : r >= 6;

    if (moving.canPromote) {
      if (moving.mustPromote(row)) {
        promote = true;
      } else if (inZone(moving.isPlayer1, selR!) ||
          inZone(moving.isPlayer1, row)) {
        promote = (await _askPromo()) ?? false;
      }
    }

    if (s.coachMode) _saveSnap(); // スナップショット保存（移動前）
    final cap = board[row][col];
    final note =
        '${_sq(row, col)}${moving.label}${promote ? "成" : ""}${cap != null ? "(取)" : ""}';
    final fr = selR!, fc = selC!;

    // 効果音（setState 前に呼ぶ）
    if (cap != null) {
      SoundService.playCapture();
    } else {
      SoundService.playMove();
    }

    setState(() {
      if (cap != null) {
        final bt = cap.baseType;
        final hand = p1Turn ? p1Hand : p2Hand;
        hand[bt] = (hand[bt] ?? 0) + 1;
      }
      board[row][col] = promote
          ? Piece(moving.promotedType, moving.isPlayer1)
          : moving;
      board[fr][fc] = null;
      lastFR = fr;
      lastFC = fc;
      lastTR = row;
      lastTC = col;
      _anim.forward(from: 0);
      kifu.add(KifuMove(kifu.length + 1, p1Turn, note,
          fr: fr, fc: fc, tr: row, tc: col, promote: promote));
      _hintMove = null;
      _clearSel();
      _endTurn();
    });
  }

  // ===== 持ち駒タップ =====
  void _onHand(PieceType type, bool isP1) {
    if (result != null || _aiThinking) return;
    if (isP1 != p1Turn) return;
    if (vsAI && isAITurn) return;
    setState(() {
      if (selHand == type) {
        _clearSel();
        return;
      }
      _clearSel();
      selHand = type;
      // isP1 は現在の手番と同一（1468行でガード）
      // 正しい持ち駒と相手の持ち駒を渡す
      final hand = isP1 ? p1Hand : p2Hand;
      final oppHand = isP1 ? p2Hand : p1Hand;
      final drops = GL.dropSquares(board, type, isP1, hand, oppHand);
      hl = _eHL();
      for (final d in drops) hl[d.$1][d.$2] = true;
    });
  }

  // ===== 有利度計算（駒数ベース） =====
  double _advantageRatio() {
    int p1Score = 0, p2Score = 0;
    const values = {
      PieceType.king: 0,
      PieceType.rook: 5,
      PieceType.bishop: 3,
      PieceType.gold: 1,
      PieceType.silver: 1,
      PieceType.knight: 1,
      PieceType.lance: 1,
      PieceType.pawn: 1,
      PieceType.promotedRook: 6,
      PieceType.promotedBishop: 4,
    };
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = board[r][c];
        if (piece != null) {
          final val = values[piece.type] ?? 0;
          if (piece.isPlayer1) p1Score += val;
          else p2Score += val;
        }
      }
    }
    p1Hand.forEach((type, cnt) {
      final val = values[type] ?? 0;
      p1Score += val * cnt;
    });
    p2Hand.forEach((type, cnt) {
      final val = values[type] ?? 0;
      p2Score += val * cnt;
    });
    final total = p1Score + p2Score;
    return total == 0 ? 0.5 : p1Score / total;
  }

  // ===== テーマ =====
  Color get _cellColor {
    switch (s.theme) {
      case PieceTheme.dark:
        return const Color(0xFF6B5310);
      case PieceTheme.textured:
        return const Color(0xD4AF87); // 上品な金茶色
      case PieceTheme.standard:
      case PieceTheme.emerald:
      case PieceTheme.cherry:
        return const Color(0xFFDEB887);
    }
  }

  Color get _cellBorder {
    switch (s.theme) {
      case PieceTheme.dark:
        return const Color(0xFF3D2F0A);
      case PieceTheme.textured:
        return const Color(0x8D6E63); // 質感用ボーダー
      case PieceTheme.standard:
      case PieceTheme.emerald:
      case PieceTheme.cherry:
        return Colors.brown.shade600;
    }
  }

  Color? get _gradientTop {
    if (s.theme == PieceTheme.textured) {
      return const Color(0x3E2723); // グラデーション上部（濃い茶）
    }
    return null;
  }

  Color? get _gradientBottom {
    if (s.theme == PieceTheme.textured) {
      return const Color(0x5D4037); // グラデーション下部
    }
    return null;
  }
  Color pieceTextColor(Piece p) {
    // ユーザーの駒は青、相手の駒は赤系
    final isUserPiece = _userIsP2 ? !p.isPlayer1 : p.isPlayer1;

    if (isUserPiece) {
      // ユーザーの駒は青
      return p.isPromoted ? Colors.blue.shade200 : Colors.blue.shade600;
    } else {
      // 相手の駒は赤系
      if (s.theme == PieceTheme.dark)
        return p.isPromoted ? Colors.red.shade200 : Colors.red.shade300;
      return p.isPromoted ? Colors.red.shade600 : Colors.red.shade800;
    }
  }

  // 相手の駒がこの位置を取れるかチェック
  bool _canBeCaptured(int r, int c) {
    final piece = board[r][c];
    if (piece == null) return false;
    // 相手の全駒をチェック
    for (int pr = 0; pr < 9; pr++) {
      for (int pc = 0; pc < 9; pc++) {
        final p = board[pr][pc];
        if (p == null || p.isPlayer1 == piece.isPlayer1) continue;
        final moves = GL.pseudo(board, pr, pc);
        if (moves.any((m) => m.$1 == r && m.$2 == c)) {
          return true;
        }
      }
    }
    return false;
  }

  // ===== BUILD =====
  @override
  Widget build(BuildContext context) {
    final inCheck = result == null && GL.inCheck(board, p1Turn);
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: Text(
          result != null
              ? result!
              : inCheck
              ? '${p1Turn ? "▲先手" : "△後手"} 王手！  ${kifu.length}手目'
              : '${kifu.length > 0 ? "${kifu.length}手目  " : ""}${p1Turn ? "▲ 先手の番" : "△ 後手の番"}',
          style: TextStyle(
            color: result != null
                ? Colors.amber
                : inCheck
                ? Colors.red.shade300
                : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (result == null && kifu.isNotEmpty)
            IconButton(
              icon: Icon(Icons.flag, color: Colors.red.shade300),
              tooltip: '投了',
              onPressed: _resign,
            ),
          // コーチモード: 待ったボタン
          if (s.coachMode && result == null && kifu.length >= (vsAI ? 2 : 1))
            IconButton(
              icon: const Icon(Icons.undo, color: Colors.cyan),
              tooltip: '待った（やり直し）',
              onPressed: _takata,
            ),
          // コーチモード: 講評ボタン（対局中も見られる）
          if (s.coachMode && kifu.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.psychology_outlined, color: Colors.deepPurpleAccent),
              tooltip: 'AI講評',
              onPressed: _openCoachReport,
            ),
          // 局面メモ
          IconButton(
            icon: Icon(
              _memos.containsKey(kifu.length) ? Icons.note : Icons.note_add_outlined,
              color: _memos.containsKey(kifu.length) ? Colors.amber : Colors.white54,
            ),
            tooltip: 'メモ',
            onPressed: _openMemoDialog,
          ),
          // 局面分析（ヒント）
          IconButton(
            icon: Icon(
              Icons.lightbulb_outline,
              color: _analysisMode ? Colors.yellow : Colors.white54,
            ),
            tooltip: _analysisMode ? '分析オフ' : '局面分析（ヒント）',
            onPressed: () => setState(() {
              _analysisMode = !_analysisMode;
              if (_analysisMode) {
                _computeHint();
              } else {
                _hintMove = null;
              }
            }),
          ),
          // 効果音 ON/OFF
          IconButton(
            icon: Icon(
              SoundService.enabled ? Icons.volume_up : Icons.volume_off,
              color: SoundService.enabled ? Colors.white : Colors.white38,
            ),
            tooltip: SoundService.enabled ? '音をオフ' : '音をオン',
            onPressed: () => setState(() {
              SoundService.enabled = !SoundService.enabled;
            }),
          ),
          // 効き可視化
          IconButton(
            icon: Icon(
              Icons.visibility,
              color: showAttackMap ? Colors.orangeAccent : Colors.white54,
            ),
            tooltip: showAttackMap ? '利き非表示' : '利きを表示',
            onPressed: () => setState(() {
              showAttackMap = !showAttackMap;
              _updateAtkMap();
            }),
          ),
          // 棋譜/盤面切替
          IconButton(
            icon: Icon(
              showKifu ? Icons.grid_on : Icons.list_alt,
              color: Colors.white,
            ),
            tooltip: showKifu ? '盤面' : '棋譜',
            onPressed: () => setState(() => showKifu = !showKifu),
          ),
          // KIFエクスポート
          IconButton(
            icon: const Icon(Icons.file_download, color: Colors.white70),
            tooltip: '棋譜エクスポート',
            onPressed: kifu.isEmpty ? null : _showKifExport,
          ),
          // 保存
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white70),
            tooltip: '棋譜保存',
            onPressed: kifu.isEmpty ? null : _saveKifu,
          ),
          // この局面を報告
          IconButton(
            icon: const Icon(Icons.bug_report_outlined, color: Colors.white38),
            tooltip: 'バグ報告・改善要望',
            onPressed: _reportPosition,
          ),
          // 新局
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: '新局',
            onPressed: () => setState(() {
              board = _initBoard(s.handicap);
              p1Hand = {};
              p2Hand = {};
              p1Turn = true;
              result = null;
              kifu = [];
              _clearSel();
              lastFR = null;
              lastFC = null;
              lastTR = null;
              lastTC = null;
              _hintMove = null;
              _updateAtkMap();
              if (s.timeLimitSec != null) {
                p1Time = s.timeLimitSec!;
                p2Time = s.timeLimitSec!;
                _startTimer();
              }
              if (vsAI && !s.aiIsP2)
                Future.delayed(const Duration(milliseconds: 600), _runAI);
            }),
          ),
        ],
      ),
      body: showKifu ? _kifuView() : _gameView(),
    );
  }

  Widget _gameView() {
    // ユーザーは常に下に表示
    return SafeArea(
      child: Column(
        children: [
          _playerBar(!_userIsP2), // 相手は上
          _handBar(!_userIsP2),
          _evalBar(), // 評価値バー
          // コーチバッジ
          if (s.coachMode && _coachBadgeText != null) _coachBadgeWidget(),
          Expanded(child: Center(child: _boardWidget())),
          _handBar(_userIsP2), // ユーザーは下
          _playerBar(_userIsP2),
          if (_analysisMode || (s.coachMode && _hintMove != null)) _hintBar(),
          // ゲーム終了時に広告を表示
          if (result != null) _adWidget(),
        ],
      ),
    );
  }

  // ===== コーチバッジ =====
  Widget _coachBadgeWidget() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _coachBadgeColor.withAlpha(40),
        border: Border.all(color: _coachBadgeColor, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_coachBadgeIcon, color: _coachBadgeColor, size: 16),
          const SizedBox(width: 6),
          Text(
            _coachBadgeText!,
            style: TextStyle(
              color: _coachBadgeColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ===== 評価値バー =====
  Widget _evalBar() {
    if (kifu.isEmpty) return const SizedBox(height: 6);
    // スコアを -3000〜3000 でクランプして 0〜1 に正規化
    const maxScore = 3000;
    final clamped = _evalScore.clamp(-maxScore, maxScore);
    final ratio = (clamped + maxScore) / (maxScore * 2); // 0=後手 1=先手
    final p1Width = ratio;
    final label = _evalScore.abs() < 50
        ? '均衡'
        : (_evalScore > 0 ? '先手有利 +$_evalScore' : '後手有利 ${_evalScore}');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('▲先手', style: TextStyle(color: Colors.blue.shade300, fontSize: 10)),
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              Text('△後手', style: TextStyle(color: Colors.red.shade300, fontSize: 10)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: LayoutBuilder(builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                return Stack(children: [
                  // 後手側（赤）
                  Container(color: Colors.red.shade700, width: totalWidth),
                  // 先手側（青）
                  Container(
                    color: Colors.blue.shade700,
                    width: totalWidth * p1Width,
                  ),
                  // 中央線
                  Positioned(
                    left: totalWidth / 2 - 0.5,
                    child: Container(width: 1, height: 6, color: Colors.white30),
                  ),
                ]);
              }),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  // ===== ヒントバー =====
  Widget _hintBar() {
    if (_hintMove == null) {
      return Container(
        color: const Color(0xFF0A2040),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: Colors.yellow, size: 16),
            const SizedBox(width: 8),
            const Text(
              '分析中...',
              style: TextStyle(color: Colors.yellow, fontSize: 13),
            ),
            const SizedBox(width: 8),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.yellow,
              ),
            ),
          ],
        ),
      );
    }
    final mv = _hintMove!;
    final from = mv.drop != null
        ? '持ち駒（${pieceLabel(mv.drop!)}）'
        : _sq(mv.fr, mv.fc);
    final to = _sq(mv.tr, mv.tc);
    return Container(
      color: const Color(0xFF0A3060),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.lightbulb, color: Colors.yellow, size: 16),
          const SizedBox(width: 8),
          Text(
            'ヒント: $from → $to',
            style: const TextStyle(
              color: Colors.yellow,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            '(AIのおすすめ)',
            style: TextStyle(color: Colors.yellow.shade200, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ===== 広告ウィジェット（試合終了時） =====
  Widget _adWidget() {
    if (!_showAds) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      color: const Color(0xFF1E1E2E),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  '広告',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      const Text(
                        'スポンサー広告',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _goToPremium,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          minimumSize: const Size(double.infinity, 36),
                        ),
                        child: const Text(
                          'プレミアムで広告を非表示',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== プレイヤーバー（名前+タイマー）=====
  Widget _playerBar(bool isP1) {
    final active = (p1Turn == isP1) && result == null && !_aiThinking;
    final timeStr = s.timeLimitSec != null
        ? '  ⏱ ${_fmt(isP1 ? p1Time : p2Time)}'
        : '';
    final isAI = vsAI && (isP1 != s.aiIsP2);
    final isHumanPlayer = !isAI;

    // アイコン決定: 人間→自分のアイコン、AI→対戦相手キャラ
    CharacterIcon? charIcon;
    if (isHumanPlayer && _charIconId != null) {
      charIcon = findCharacterById(_charIconId!);
    } else if (isAI && s.opponentCharacterId != null) {
      charIcon = findCharacterById(s.opponentCharacterId!);
    }

    // AI名: キャラ名があれば使用
    final aiLabel = isAI && s.opponentCharacterId != null
        ? ' ${findCharacterById(s.opponentCharacterId!)?.name ?? "CPU"}'
        : isAI ? ' (CPU)' : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // セリフバブル（AIの場合のみ）
        if (isAI && _dialogueVisible && _aiDialogue != null)
          AnimatedOpacity(
            opacity: _dialogueVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 2, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: charIcon != null
                    ? charIcon.bgColor.withAlpha(200)
                    : Colors.blueGrey.shade800,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                _aiDialogue!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        Container(
      color: active ? const Color(0xFF0D3B66) : const Color(0xFF0A2540),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          if (charIcon != null)
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: charIcon.bgColor,
                shape: BoxShape.circle,
                border: isAI
                    ? Border.all(color: Colors.amber.withAlpha(180), width: 1.5)
                    : null,
              ),
              child: Center(
                child: Text(charIcon.emoji, style: const TextStyle(fontSize: 13)),
              ),
            )
          else
            Icon(
              isAI ? Icons.computer : Icons.person,
              color: Colors.white54,
              size: 16,
            ),
          const SizedBox(width: 6),
          Text(
            '${isP1 ? "▲ 先手" : "△ 後手"}$aiLabel$timeStr',
            style: TextStyle(
              color: active ? Colors.white : Colors.white54,
              fontSize: 13,
            ),
          ),
          if (_aiThinking && isAI && active) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.lightBlueAccent,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              '考え中...',
              style: TextStyle(color: Colors.lightBlueAccent, fontSize: 12),
            ),
          ],
          const Spacer(),
          if (s.timeLimitSec != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (isP1 ? p1Time : p2Time) < 30
                    ? Colors.red.shade900
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _fmt(isP1 ? p1Time : p2Time),
                style: TextStyle(
                  color: (isP1 ? p1Time : p2Time) < 30
                      ? Colors.red.shade200
                      : Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
        ],
      ),
        ), // Container (playerBar inner)
      ], // Column children
    ); // Column
  }

  // ===== 持ち駒バー =====
  Widget _handBar(bool isP1) {
    final hand = isP1 ? p1Hand : p2Hand;
    final active = (p1Turn == isP1) && result == null && !_aiThinking;
    final isAI = vsAI && (isP1 != s.aiIsP2);
    return Container(
      height: 44,
      color: active ? const Color(0xFF1F4068) : const Color(0xFF0F2A40),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Text(
            '持駒: ',
            style: TextStyle(
              color: active ? Colors.white60 : Colors.white30,
              fontSize: 11,
            ),
          ),
          Expanded(
            child: hand.isEmpty
                ? Text(
                    'なし',
                    style: TextStyle(color: Colors.white24, fontSize: 11),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: hand.entries.map((e) {
                        final sel = selHand == e.key && p1Turn == isP1 && !isAI;
                        final canSelect = p1Turn == isP1 && !_aiThinking && result == null;
                        return GestureDetector(
                          onTap: () => _onHand(e.key, isP1),
                          child: Opacity(
                            opacity: canSelect ? 1.0 : 0.5,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: sel ? Colors.yellow.shade200 : _cellColor,
                                borderRadius: BorderRadius.circular(4),
                                border: sel
                                    ? Border.all(
                                        color: Colors.orange.shade700,
                                        width: 2,
                                      )
                                    : null,
                                boxShadow: sel
                                    ? [
                                        BoxShadow(
                                          color: Colors.orange.shade300,
                                          blurRadius: 4,
                                        ),
                                      ]
                                    : null,
                              ),
                            child: Text(
                              '${pieceLabel(e.key)}${e.value > 1 ? " ×${e.value}" : ""}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: s.theme == PieceTheme.dark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ===== 将棋盤 =====
  Widget _boardWidget() {
    return AspectRatio(
      aspectRatio: 10 / 11,
      child: LayoutBuilder(
        builder: (_, cs) {
          final boardSize = cs.maxWidth * 0.9;
          final labelSize = cs.maxWidth * 0.05;
          final cellSize = boardSize / 9;

          return Column(
            children: [
              // 筋ラベル（常に9→1）
              Row(
                children: [
                  SizedBox(width: labelSize),
                  ...List.generate(
                    9,
                    (i) => SizedBox(
                      width: cellSize,
                      child: Text(
                        '${9 - i}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: labelSize * 0.7,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 段ラベル（常に一→九）
                  Column(
                    children: List.generate(
                      9,
                      (i) => SizedBox(
                        width: labelSize,
                        height: cellSize,
                        child: Center(
                          child: Text(
                            _rowKanji[i],
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: labelSize * 0.7,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 盤面本体
                  Container(
                    width: boardSize,
                    height: boardSize,
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.brown.shade800,
                        width: 2,
                      ),
                      color: _cellColor,
                    ),
                    child: Stack(
                      children: [
                        // グリッドと星を描画
                        CustomPaint(
                          painter: _BoardPainter(
                            cellColor: _cellColor,
                            borderColor: _cellBorder,
                            theme: s.theme,
                            advantageRatio: _advantageRatio(),
                            gradientTop: _gradientTop,
                            gradientBottom: _gradientBottom,
                          ),
                          size: Size(boardSize, boardSize),
                        ),
                        // 駒とハイライト
                        AnimatedBuilder(
                      animation: _animVal,
                      builder: (_, __) {
                        final av = _animVal.value;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            9,
                            (displayRow) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(9, (displayCol) {
                                // 常に通常の座標（反転なし）
                                final r = displayRow;
                                final c = displayCol;

                                final piece = board[r][c];
                                final isSel = selR == r && selC == c;
                                final isHL = hl[r][c];
                                final isLastTo = lastTR == r && lastTC == c;
                                final isLastFr = lastFR == r && lastFC == c;
                                // 先手/後手の利き数（絶対座標）
                                final p1V = _p1AtkMap?[r][c] ?? 0; // 先手の利き
                                final p2V = _p2AtkMap?[r][c] ?? 0; // 後手の利き
                                // 旧変数名との互換（他の場所で使用中）
                                final myV = p1Turn ? p1V : p2V;
                                final oppV = p1Turn ? p2V : p1V;
                                final isHintFr =
                                    _analysisMode &&
                                    _hintMove != null &&
                                    _hintMove!.drop == null &&
                                    _hintMove!.fr == r &&
                                    _hintMove!.fc == c;
                                final isHintTo =
                                    _analysisMode &&
                                    _hintMove != null &&
                                    _hintMove!.tr == r &&
                                    _hintMove!.tc == c;
                                // ただどり判定：相手に取られうるかつ自分も守っていない
                                final canCapture = piece != null && _canBeCaptured(r, c);
                                // より深刻なただどり（守りがない）
                                final isTadaDori = canCapture && (() {
                                  // 駒の持ち主が先手ならp1V=0(守りなし)かつp2V>0
                                  // 後手ならp2V=0かつp1V>0
                                  if (piece!.isPlayer1) return p1V == 0 && p2V > 0;
                                  return p2V == 0 && p1V > 0;
                                })();

                                // ── セル背景色 ──
                                Color bg = _cellColor;
                                // 利きマップ（駒のないマスのみ強め、駒ありは薄め）
                                if (showAttackMap) {
                                  final hasPiece = piece != null;
                                  // 先手優勢＝青、後手優勢＝赤、拮抗＝紫（薄）
                                  final baseIntensity = hasPiece ? 0.18 : 0.40;
                                  if (p1V > 0 && p2V == 0) {
                                    final t = (baseIntensity + (p1V - 1) * 0.08).clamp(0.0, hasPiece ? 0.25 : 0.55);
                                    bg = Color.lerp(_cellColor, Colors.blue.shade300, t)!;
                                  } else if (p2V > 0 && p1V == 0) {
                                    final t = (baseIntensity + (p2V - 1) * 0.08).clamp(0.0, hasPiece ? 0.25 : 0.55);
                                    bg = Color.lerp(_cellColor, Colors.red.shade300, t)!;
                                  } else if (p1V > 0 && p2V > 0) {
                                    final t = hasPiece ? 0.12 : 0.28;
                                    bg = Color.lerp(_cellColor, Colors.purple.shade300, t)!;
                                  }
                                }
                                // ヒント手
                                if (isHintFr)
                                  bg = Colors.cyan.shade200;
                                else if (isHintTo)
                                  bg = Colors.cyan.shade100;
                                // 直前移動フェード
                                if (av < 1.0) {
                                  if (isLastTo)
                                    bg = Color.lerp(
                                      Colors.yellow.shade200,
                                      bg,
                                      av,
                                    )!;
                                  else if (isLastFr)
                                    bg = Color.lerp(
                                      Colors.yellow.shade100,
                                      bg,
                                      min(1.0, av * 2),
                                    )!;
                                }
                                // 選択・合法手（最優先）
                                if (isSel)
                                  bg = Colors.yellow.shade300;
                                else if (isHL && piece != null)
                                  bg = Colors.red.shade200;
                                else if (isHL)
                                  bg = Colors.lightGreen.shade100;

                                return GestureDetector(
                                  onTap: () => _onCell(r, c),
                                  child: Container(
                                    width: cellSize,
                                    height: cellSize,
                                    decoration: BoxDecoration(
                                      color: bg,
                                      border: isTadaDori
                                        ? Border.all(color: Colors.red.shade600, width: 3.0)
                                        : canCapture
                                          ? Border.all(color: Colors.orange.shade400, width: 1.5)
                                          : Border.all(color: _cellBorder, width: 0.5),
                                      boxShadow: isTadaDori
                                        ? [BoxShadow(color: Colors.red.shade600.withAlpha(160), blurRadius: 6, spreadRadius: 1)]
                                        : null,
                                    ),
                                    child: Stack(
                                      children: [
                                        // 駒または移動可能マーク
                                        if (piece != null)
                                          Center(
                                            child: Transform.scale(
                                              scale: (isLastTo && av < 1.0)
                                                  ? 1.0 + 0.22 * (1.0 - av)
                                                  : 1.0,
                                              child: RotatedBox(
                                                quarterTurns: piece.isPlayer1 ? 0 : 2,
                                                child: Text(
                                                  piece.label,
                                                  style: TextStyle(
                                                    fontSize: cellSize * .62,
                                                    fontWeight: FontWeight.bold,
                                                    color: pieceTextColor(piece),
                                                    height: 1.0,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                        else if (isHL)
                                          Center(
                                            child: Container(
                                              width: cellSize * .35,
                                              height: cellSize * .35,
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade500.withAlpha(170),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        // 利き数表示（先手=正/青、後手=負/赤）
                                        if (showAttackMap && (p1V > 0 || p2V > 0))
                                          Positioned(
                                            right: 1,
                                            bottom: 1,
                                            child: p1V > 0 && p2V > 0
                                              // 両方が利いているマス：左下に後手、右下に先手
                                              ? Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      '-$p2V',
                                                      style: TextStyle(
                                                        fontSize: cellSize * 0.24,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.red.shade400,
                                                      ),
                                                    ),
                                                    Text(
                                                      '$p1V',
                                                      style: TextStyle(
                                                        fontSize: cellSize * 0.24,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.blue.shade400,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : Text(
                                                  p1V > 0 ? '$p1V' : '-$p2V',
                                                  style: TextStyle(
                                                    fontSize: cellSize * 0.28,
                                                    fontWeight: FontWeight.bold,
                                                    color: p1V > 0
                                                      ? Colors.blue.shade400
                                                      : Colors.red.shade400,
                                                    shadows: [
                                                      Shadow(
                                                        color: Colors.black.withAlpha(160),
                                                        blurRadius: 2,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        );
                      },
                    ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ===== 棋譜ビュー =====
  Widget _kifuView() => Container(
    color: const Color(0xFF16213E),
    child: kifu.isEmpty
        ? const Center(
            child: Text('まだ手がありません', style: TextStyle(color: Colors.white54)),
          )
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '棋譜 (${kifu.length}手)',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.file_download, size: 16),
                          label: const Text('エクスポート'),
                          onPressed: _showKifExport,
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.save, size: 16),
                          label: const Text('保存'),
                          onPressed: _saveKifu,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: kifu.length,
                  itemBuilder: (_, i) {
                    final m = kifu[kifu.length - 1 - i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        m.text,
                        style: TextStyle(
                          color: m.p1
                              ? Colors.white
                              : Colors.lightBlue.shade200,
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
  );
}

// ===== 初期盤面 =====
List<List<Piece?>> _initBoard([Handicap handicap = Handicap.none]) {
  final b = List<List<Piece?>>.generate(
    9,
    (_) => List<Piece?>.filled(9, null, growable: false),
  );
  void s(int r, int c, PieceType t, bool p1) => b[r][c] = Piece(t, p1);

  // ---- 後手（上手 / P2）の配置 ----
  // 各駒の除外条件
  final rmLeftLance  = {Handicap.lance, Handicap.four, Handicap.six, Handicap.eight};
  final rmRightLance = {Handicap.four, Handicap.six, Handicap.eight};
  final rmKnight     = {Handicap.six, Handicap.eight};
  final rmSilver     = {Handicap.eight};
  final rmRook       = {Handicap.rook, Handicap.rookBishop, Handicap.four, Handicap.six, Handicap.eight};
  final rmBishop     = {Handicap.bishop, Handicap.rookBishop, Handicap.four, Handicap.six, Handicap.eight};

  if (!rmLeftLance.contains(handicap))  s(0, 0, PieceType.lance,  false);
  if (!rmKnight.contains(handicap))     s(0, 1, PieceType.knight, false);
  if (!rmSilver.contains(handicap))     s(0, 2, PieceType.silver, false);
                                         s(0, 3, PieceType.gold,   false);
                                         s(0, 4, PieceType.king,   false);
                                         s(0, 5, PieceType.gold,   false);
  if (!rmSilver.contains(handicap))     s(0, 6, PieceType.silver, false);
  if (!rmKnight.contains(handicap))     s(0, 7, PieceType.knight, false);
  if (!rmRightLance.contains(handicap)) s(0, 8, PieceType.lance,  false);
  if (!rmRook.contains(handicap))       s(1, 1, PieceType.rook,   false);
  if (!rmBishop.contains(handicap))     s(1, 7, PieceType.bishop, false);

  for (int c = 0; c < 9; c++) s(2, c, PieceType.pawn, false);
  s(8, 0, PieceType.lance, true);
  s(8, 1, PieceType.knight, true);
  s(8, 2, PieceType.silver, true);
  s(8, 3, PieceType.gold, true);
  s(8, 4, PieceType.king, true);
  s(8, 5, PieceType.gold, true);
  s(8, 6, PieceType.silver, true);
  s(8, 7, PieceType.knight, true);
  s(8, 8, PieceType.lance, true);
  s(7, 7, PieceType.rook, true);
  s(7, 1, PieceType.bishop, true);
  for (int c = 0; c < 9; c++) s(6, c, PieceType.pawn, true);
  return b;
}

// ===== Export alias =====
/// 初期盤面を生成（initShogiBoard は _initBoard へのエクスポート）
List<List<Piece?>> initShogiBoard([Handicap handicap = Handicap.none]) =>
    _initBoard(handicap);
