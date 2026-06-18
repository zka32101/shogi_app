// lib/main.dart — アプリエントリ + BottomNavigation ホーム画面

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_screen.dart';
import 'theme_config.dart';
import 'game_setup_screen.dart';
import 'editor_screen.dart';
import 'rules_screen.dart';
import 'guide_screen.dart';
import 'kifu_history_screen.dart';
import 'castle_patterns_screen.dart';
import 'strategies_screen.dart';
import 'stats_screen.dart';
import 'tutorial_screen.dart';
import 'strength_test_screen.dart';
import 'speech_service.dart';
import 'sound_service.dart';
import 'joseki_screen.dart';
import 'tsume_screen.dart';
import 'tesuji_screen.dart';
import 'proverbs_screen.dart';
import 'ad_service.dart';
import 'purchase_service.dart';
import 'network_lobby_screen.dart';
import 'network_game_service.dart';
import 'ranking_screen.dart';
import 'badge_screen.dart';
import 'cloud_sync_service.dart';
import 'ai_data_service.dart';
import 'weekly_review_screen.dart';
import 'feedback_screen.dart';
import 'screens/premium_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'services/network_service.dart';
import 'shodan_roadmap_screen.dart';
import 'learning_guide_screen.dart';
import 'next_move_screen.dart';
import 'castle_break_screen.dart';
import 'pro_kifu_screen.dart';
import 'study_calendar_screen.dart';
import 'weakness_analysis_screen.dart';
import 'monthly_tournament_screen.dart';
import 'puzzle_generator_screen.dart';
import 'l10n.dart';
import 'weakness_mining_screen.dart';
import 'micro_training_screen.dart';
import 'friend_challenge_screen.dart';
import 'async_training_duel_screen.dart';
import 'voice_io_screen.dart';
import 'spaced_repetition_screen.dart';
import 'coach_personality_screen.dart';
import 'natural_lang_qa_screen.dart';
import 'adaptive_difficulty_screen.dart';
import 'camera_ocr_screen.dart';
import 'playstyle_diagnosis_screen.dart';
import 'ghost_service.dart';
import 'screens/ghost_screen.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdService.initialize();
  await PurchaseService.initialize();
  // Firebase 初期化（設定済みの場合のみ有効）
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Crashlytics: uncaught Flutter エラーを自動報告
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    // ネットワークサービス初期化
    await NetworkService().initFirebase();
    NetworkGameService.setFirebaseReady();
    CloudSyncService.setReady();
    AiDataService.setReady();
    // 起動時: サーバーデータ取得 + オープニングブック DL（バックグラウンド）
    CloudSyncService.pullAndMerge();
    AiDataService.downloadOpeningBook();
    // G1: プッシュ通知初期化（バックグラウンドハンドラはFirebase.initializeApp後に登録必須）
    await FcmService().initialize();
  } catch (_) {
    // Firebase 未設定の場合はスキップ（ネットワーク対局機能は無効）
  }
  runApp(const ShogiApp());
}

class ShogiApp extends StatelessWidget {
  const ShogiApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '効棋',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ja', 'JP'),
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
      useMaterial3: true,
      // 将棋漢字（将・龍・馬・桂など）を日本語フォントで正しく表示
      textTheme: ThemeData.light().textTheme.apply(
        fontFamilyFallback: const ['Noto Serif', 'Noto Sans', 'serif'],
      ),
      // ナビゲーションバーのラベルテキストを白色に
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: Colors.white);
            }
            return const TextStyle(color: Colors.white70);
          },
        ),
      ),
    ),
    home: const HomeScreen(),
  );
}

// ===== ホーム画面（BottomNavigation 4タブ） =====
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  // 設定状態（設定タブから対局タブへ共有）
  int? _timeLimitSec;
  int? _byoyomiSec;
  int _fischerIncrementSec = 0;
  PieceTheme _theme = PieceTheme.standard;
  PieceLabelStyle _labelStyle = PieceLabelStyle.kanji;
  bool _speechEnabled = false;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final launched = prefs.getBool('has_launched') ?? false;
      if (!launched) {
        await prefs.setBool('has_launched', true);
        if (mounted) {
          // 初回起動: チュートリアル画面へ
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TutorialScreen()),
            );
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: IndexedStack(
        index: _tab,
        children: [
          _PlayTab(
            timeLimitSec: _timeLimitSec,
            byoyomiSec: _byoyomiSec,
            fischerIncrementSec: _fischerIncrementSec,
            theme: _theme,
            labelStyle: _labelStyle,
          ),
          const _KifuTab(),
          const _StudyTab(),
          _SettingsTab(
            timeLimitSec: _timeLimitSec,
            byoyomiSec: _byoyomiSec,
            fischerIncrementSec: _fischerIncrementSec,
            theme: _theme,
            labelStyle: _labelStyle,
            speechEnabled: _speechEnabled,
            soundEnabled: _soundEnabled,
            onTime: (v) => setState(() => _timeLimitSec = v),
            onByoyomi: (v) => setState(() => _byoyomiSec = v),
            onFischer: (v) => setState(() => _fischerIncrementSec = v),
            onTheme: (v) => setState(() => _theme = v),
            onLabelStyle: (v) => setState(() => _labelStyle = v),
            onSpeech: (v) {
              setState(() => _speechEnabled = v);
              SpeechService.setEnabled(v);
            },
            onSound: (v) {
              setState(() => _soundEnabled = v);
              SoundService.enabled = v;
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF16213E),
        indicatorColor: Colors.brown.shade700,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sports_esports_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.sports_esports, color: Colors.white),
            label: '対局',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.history, color: Colors.white),
            label: '棋譜',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.school, color: Colors.white),
            label: '学習',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.tune, color: Colors.white),
            label: '設定',
          ),
        ],
      ),
    );
  }
}

// ===== タブ 0: 対局 =====
class _PlayTab extends StatefulWidget {
  final int? timeLimitSec;
  final int? byoyomiSec;
  final int fischerIncrementSec;
  final PieceTheme theme;
  final PieceLabelStyle labelStyle;
  const _PlayTab({
    required this.timeLimitSec,
    required this.byoyomiSec,
    required this.fischerIncrementSec,
    required this.theme,
    required this.labelStyle,
  });
  @override
  State<_PlayTab> createState() => _PlayTabState();
}

class _PlayTabState extends State<_PlayTab> {
  int _rating = 700;
  List<int> _ratingHistory = [];
  String _rank = '10級';
  Color _rankColor = Colors.white54;
  int _ghostWins = 0;
  int _ghostLosses = 0;

  @override
  void initState() {
    super.initState();
    _loadRating();
  }

  @override
  void didUpdateWidget(_PlayTab old) {
    super.didUpdateWidget(old);
    _loadRating();
  }

  Future<void> _loadRating() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final r = prefs.getInt('rating_current') ?? 700;
      final record = await GhostService.getTodayRecord();
      if (mounted) {
        setState(() {
          _rating = r;
          _rank   = ratingToRank(r);
          _rankColor = ratingToColor(r);
          _ghostWins = record.wins;
          _ghostLosses = record.losses;
        });
      }
      try {
        final raw = prefs.getString('rating_history') ?? '[]';
        final hist = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        final ratings = hist.map((e) => e['rating'] as int? ?? 700).toList();
        if (mounted) setState(() => _ratingHistory = ratings.reversed.take(20).toList().reversed.toList());
      } catch (_) {}
    } catch (_) {}
  }

  void _go(BuildContext ctx, Widget screen) {
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen))
        .then((_) => _loadRating()); // 対局後に戻ったら更新
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            // タイトル
            const Text(
              '効棋',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
              ),
            ),
            const Text(
              'KOUKI  ·  Learn the Kiki',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white38, fontSize: 11, letterSpacing: 3),
            ),
            const SizedBox(height: 4),
            const Text(
              '好機を見つける将棋の効きを学ぶ',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white24, fontSize: 10, letterSpacing: 2),
            ),
            const SizedBox(height: 12),

            // ── レーティング表示 ──
            GestureDetector(
              onTap: () => _go(context, const StatsScreen()),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF16213E), _rankColor.withAlpha(30)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _rankColor.withAlpha(80), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.military_tech, color: _rankColor, size: 20),
                    const SizedBox(width: 8),
                    Text(_rank,
                        style: TextStyle(color: _rankColor, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Text('$_rating',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    const Text('pts', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── レーティング推移ミニグラフ ──
            if (_ratingHistory.length >= 3)
              GestureDetector(
                onTap: () => _go(context, const StatsScreen()),
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(children: [
                    const Text('推移', style: TextStyle(color: Colors.white24, fontSize: 9, letterSpacing: 1)),
                    const SizedBox(width: 8),
                    Expanded(child: CustomPaint(
                      painter: _RatingMiniGraphPainter(history: _ratingHistory, currentRating: _rating),
                    )),
                    const SizedBox(width: 8),
                    const Icon(Icons.open_in_new, color: Colors.white24, size: 12),
                  ]),
                ),
              ),

            // ── 全ランク一覧（横スクロール） ──
            GestureDetector(
              onTap: () => _go(context, const StatsScreen()),
              child: SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: rankTable.length,
                  itemBuilder: (ctx, i) {
                    final rr = rankTable[rankTable.length - 1 - i]; // 低級から高段へ
                    final isCurrent = _rank == rr.rank;
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? rr.color.withAlpha(40)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isCurrent ? rr.color : Colors.white12,
                          width: isCurrent ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        rr.rank,
                        style: TextStyle(
                          color: isCurrent ? rr.color : Colors.white38,
                          fontSize: 11,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── 現在の対局設定サマリー ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.brown.shade900.withAlpha(100),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  // 持ち時間行
                  Row(children: [
                    Icon(Icons.timer_outlined, size: 13, color: Colors.lightBlue.shade300),
                    const SizedBox(width: 4),
                    const Text('持ち時間: ',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                    _settingChip(
                      widget.timeLimitSec == null ? 'なし' : '${widget.timeLimitSec! ~/ 60}分',
                      widget.timeLimitSec == null ? Colors.white24 : Colors.green.shade700,
                    ),
                    if (widget.byoyomiSec != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.timer, size: 13, color: Colors.lightBlue.shade300),
                      const SizedBox(width: 4),
                      const Text('秒読み: ',
                          style: TextStyle(color: Colors.white38, fontSize: 11)),
                      _settingChip('${widget.byoyomiSec}秒', Colors.cyan.shade700),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: const Text('設定タブで変更できます',
                        style: TextStyle(color: Colors.white24, fontSize: 10)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _sectionLabel('対局モード'),
            const SizedBox(height: 10),
            // PvP + AI
            Row(children: [
              Expanded(
                child: _bigButton(
                  context, 'ローカル対局', Icons.people, Colors.brown.shade700,
                  () => _go(context, const GameSetupScreen(mode: GameMode.pvp)),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            _bigButton(
              context, 'AI対局', Icons.computer, Colors.blueGrey.shade700,
              () => _go(context, const GameSetupScreen(mode: GameMode.vsAI)),
            ),
            const SizedBox(height: 8),
            _bigButton(
              context, 'ネットワーク対局', Icons.wifi, const Color(0xFF1A5276),
              () => _go(context, const NetworkLobbyScreen()),
            ),
            const SizedBox(height: 20),

            _sectionLabel('統計・ツール'),
            const SizedBox(height: 10),
            _bigButton(
              context, '統計', Icons.bar_chart, Colors.indigo.shade600,
              () => _go(context, const StatsScreen()),
            ),
            const SizedBox(height: 8),
            // ゴースト棋士カード
            GestureDetector(
              onTap: () => _go(context, const GhostScreen()),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1A237E), Colors.deepPurple.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.withAlpha(80)),
                ),
                child: Row(children: [
                  const Text('👻', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('ゴースト棋士', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      Text(
                        (_ghostWins + _ghostLosses) == 0
                            ? '棋風ゴーストで自動対戦'
                            : '今日 $_ghostWins勝 $_ghostLosses敗',
                        style: TextStyle(
                          color: (_ghostWins + _ghostLosses) == 0
                              ? Colors.white38
                              : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ]),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            _sectionLabel('局面エディタ'),
            const SizedBox(height: 10),
            _bigButton(
              context, '局面エディタ', Icons.edit_note, Colors.teal.shade700,
              () => _go(context, EditorScreen(
                    gameSettings: GameSettings(
                      mode: GameMode.pvp,
                      timeLimitSec: widget.timeLimitSec,
                      fischerIncrementSec: widget.fischerIncrementSec,
                      theme: widget.theme,
                    ))),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ===== タブ 1: 棋譜 =====
class _KifuTab extends StatelessWidget {
  const _KifuTab();
  @override
  Widget build(BuildContext context) {
    // タブに埋め込み（戻るボタン非表示）
    return const KifuHistoryScreen(showBackButton: false);
  }
}

// ===== タブ 2: 学習 =====
class _StudyTab extends StatelessWidget {
  const _StudyTab();

  void _go(BuildContext ctx, Widget screen) {
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const Text(
              '学習',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            // レベル凡例
            Row(children: [
              _levelChip('全員', Colors.green),
              const SizedBox(width: 6),
              _levelChip('10〜5級', Colors.blue),
              const SizedBox(width: 6),
              _levelChip('4級〜', Colors.orange),
            ]),
            const SizedBox(height: 12),

            // ── 全員向けセクション ──
            _studyLevelHeader('全員向け', Colors.greenAccent, Icons.people),

            // ── 初段ロードマップ ──
            GestureDetector(
              onTap: () => _go(context, const LearningGuideScreen()),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1F3A5F), const Color(0xFF16213E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withAlpha(120), width: 2),
                ),
                child: Row(children: [
                  const Icon(Icons.explore, color: Colors.amber, size: 32),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('学習ガイド', style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('状況別おすすめ学習ルート', style: TextStyle(color: Colors.amber.shade200, fontSize: 12)),
                  ]),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                ]),
              ),
            ),
            const SizedBox(height: 10),

            // ── 初級者向けセクション ──
            _studyLevelHeader('初級者向け（10〜5級）', Colors.lightBlueAccent, Icons.school),

            // ── 定跡練習 ──
            GestureDetector(
              onTap: () => _go(context, const JosekiScreen()),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade900, Colors.indigo.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.withAlpha(120)),
                ),
                child: Row(children: [
                  Icon(Icons.sports_martial_arts, color: Colors.indigo.shade300, size: 32),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('定跡練習', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('矢倉・四間飛車など8種 盤面ガイド付き', style: TextStyle(color: Colors.indigo.shade200, fontSize: 12)),
                  ]),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                ]),
              ),
            ),
            const SizedBox(height: 10),

            // ── 次の一手 ──
            GestureDetector(
              onTap: () => _go(context, const NextMoveScreen()),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade900, Colors.amber.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withAlpha(100)),
                ),
                child: Row(children: [
                  const Icon(Icons.lightbulb, color: Colors.amber, size: 32),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('次の一手', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('中盤・終盤の好手を見つけよう 15問【10〜5級推奨】', style: TextStyle(color: Colors.amber.shade200, fontSize: 12)),
                  ]),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                ]),
              ),
            ),
            const SizedBox(height: 10),

            // ── 中級者以上セクション ──
            _studyLevelHeader('中級者以上（4級〜）', Colors.orangeAccent, Icons.trending_up),

            // ── 囲い崩し道場 ──
            GestureDetector(
              onTap: () => _go(context, const CastleBreakScreen()),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade900, Colors.orange.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withAlpha(100)),
                ),
                child: Row(children: [
                  const Icon(Icons.shield_outlined, color: Colors.orange, size: 32),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('囲い崩し道場', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('美濃・矢倉・穴熊の崩し方 12問【4級〜推奨】', style: TextStyle(color: Colors.orange.shade200, fontSize: 12)),
                  ]),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                ]),
              ),
            ),
            const SizedBox(height: 10),

            // ── 詰将棋 ── (バナー)
            GestureDetector(
              onTap: () => _go(context, const TsumeScreen()),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueGrey.withAlpha(80)),
                ),
                child: Row(children: [
                  const Icon(Icons.extension, color: Colors.blueGrey, size: 32),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('詰将棋', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('1〜3手詰め 6問', style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 12)),
                  ]),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                ]),
              ),
            ),
            const SizedBox(height: 10),

            // ── デイリー詰将棋 ──
            GestureDetector(
              onTap: () => _go(context, const DailyTsumeScreen()),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade900, Colors.teal.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withAlpha(80)),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today, color: Colors.greenAccent, size: 32),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('デイリー詰将棋', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('今日の問題 • 1日3回まで', style: TextStyle(color: Colors.green.shade200, fontSize: 12)),
                  ]),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                ]),
              ),
            ),
            const SizedBox(height: 10),

            // ── ローグライト ──
            GestureDetector(
              onTap: () => _go(context, const TsumeRogueliteScreen()),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade900, Colors.orange.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withAlpha(80)),
                ),
                child: Row(children: [
                  const Icon(Icons.favorite, color: Colors.redAccent, size: 32),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('ローグライト', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('ライフ3つ・難易度上昇・自己ベスト更新', style: TextStyle(color: Colors.orange.shade200, fontSize: 12)),
                  ]),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                ]),
              ),
            ),
            const SizedBox(height: 10),

            // ── タイムアタック ──
            GestureDetector(
              onTap: () => _go(context, const TsumeTimeAttackScreen()),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.cyan.shade900, Colors.teal.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyan.withAlpha(80)),
                ),
                child: Row(children: [
                  const Icon(Icons.timer, color: Colors.cyan, size: 32),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('タイムアタック', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('3分間で何問解ける？', style: TextStyle(color: Colors.cyan.shade200, fontSize: 12)),
                  ]),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                ]),
              ),
            ),
            const SizedBox(height: 10),

            // ── 棋風診断 ──
            GestureDetector(
              onTap: () => _go(context, const PlaystyleDiagnosisScreen()),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade900, Colors.indigo.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withAlpha(80)),
                ),
                child: Row(children: [
                  const Icon(Icons.psychology, color: Colors.purpleAccent, size: 32),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('棋風診断', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('対局データからあなたの棋風を分析', style: TextStyle(color: Colors.purple.shade200, fontSize: 12)),
                  ]),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                ]),
              ),
            ),
            const SizedBox(height: 10),

            // ── 棋力診断 ── (バナー)
            GestureDetector(
              onTap: () => _go(context, const StrengthTestScreen()),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey.shade800, Colors.blueGrey.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withAlpha(80)),
                ),
                child: Row(children: [
                  const Icon(Icons.military_tech, color: Colors.white70, size: 32),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('棋力診断', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('5問で実力を測定', style: TextStyle(color: Colors.grey.shade300, fontSize: 12)),
                  ]),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                ]),
              ),
            ),
            const SizedBox(height: 10),

            // ── 手筋トレーニング ──
            GestureDetector(
              onTap: () => _go(context, const TesujiScreen()),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueGrey.withAlpha(80)),
                ),
                child: Row(children: [
                  const Icon(Icons.psychology, color: Colors.blueGrey, size: 32),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('手筋トレーニング', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('12問・4カテゴリの手筋問題【4級〜推奨】', style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 12)),
                  ]),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            _sectionLabel('コンテンツ'),
            const SizedBox(height: 10),
            // 弱点分析
            GestureDetector(
              onTap: () => _go(context, const WeaknessAnalysisScreen()),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade900, Colors.purple.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withAlpha(100)),
                ),
                child: Row(children: [
                  const Icon(Icons.analytics, color: Colors.purple, size: 32),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('弱点分析', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('レーダーチャートで苦手を把握', style: TextStyle(color: Colors.purple.shade200, fontSize: 12)),
                  ]),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _bigButton(context, 'プロ棋譜', Icons.video_library, Colors.red.shade800,
                  () => _go(context, const ProKifuScreen())),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _bigButton(context, '学習カレンダー', Icons.calendar_month, Colors.green.shade800,
                  () => _go(context, const StudyCalendarScreen())),
              ),
            ]),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _go(context, const MonthlyTournamentScreen()),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF3D2A00), const Color(0xFF5C3D00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD700).withAlpha(120), width: 1),
                ),
                child: Row(children: [
                  const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 32),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('月例トーナメント', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const Text('毎月開催の棋力別トーナメント', style: TextStyle(color: Color(0xFFFFD700), fontSize: 12)),
                  ]),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            _sectionLabel('革新機能（Free）'),
            const SizedBox(height: 10),
            // 弱点採掘
            GestureDetector(
              onTap: () => _go(context, const WeaknessMiningScreen()),
              child: _bannerButton(context, '弱点採掘', Icons.analytics, Colors.teal.shade700, '繰り返す失敗パターンを検出'),
            ),
            const SizedBox(height: 10),
            // 3分筋トレ
            GestureDetector(
              onTap: () => _go(context, const MicroTrainingScreen()),
              child: _bannerButton(context, '3分筋トレ', Icons.timer, Colors.cyan.shade700, '毎日3分で手筋をマスター'),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _bigButton(context, '友達対戦', Icons.people, Colors.orange.shade700, () => _go(context, const FriendChallengeScreen()))),
              const SizedBox(width: 10),
              Expanded(child: _bigButton(context, 'レース対戦', Icons.speed, Colors.purple.shade700, () => _go(context, const AsyncTrainingDuelScreen()))),
            ]),
            const SizedBox(height: 10),
            _bigButton(context, '音声入出力', Icons.mic, Colors.blue.shade700, () => _go(context, const VoiceIOScreen())),
            const SizedBox(height: 20),

            _sectionLabel('プレミアム機能'),
            const SizedBox(height: 10),
            _bigButton(context, '週次AI振り返り 👑', Icons.analytics, Colors.purple.shade700,
              () => _go(context, const WeeklyReviewScreen())),
            const SizedBox(height: 10),
            _bigButton(context, 'AI詰将棋ジェネレーター 👑', Icons.auto_fix_high, Colors.deepPurple.shade700,
              () => _go(context, const PuzzleGeneratorScreen())),
            const SizedBox(height: 10),
            _bigButton(context, '忘却曲線AI 👑', Icons.calendar_today, Colors.deepOrange.shade700, () => _go(context, const SpacedRepetitionScreen())),
            const SizedBox(height: 10),
            _bigButton(context, 'AI棋風コーチ 👑', Icons.person, Colors.red.shade700, () => _go(context, const CoachPersonalityScreen())),
            const SizedBox(height: 10),
            _bigButton(context, '自然言語Q&A 👑', Icons.chat, Colors.indigo.shade700, () => _go(context, const NaturalLangQAScreen())),
            const SizedBox(height: 10),
            _bigButton(context, '難易度自動調整 👑', Icons.trending_up, Colors.green.shade700, () => _go(context, const AdaptiveDifficultyScreen(userId: 'user_default'))),
            const SizedBox(height: 10),
            _bigButton(context, 'カメラOCR 👑', Icons.camera_alt, Colors.amber.shade700, () => _go(context, const CameraOCRScreen())),
            const SizedBox(height: 20),

            _sectionLabel('将棋を学ぶ'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _bigButton(
                  context, 'チュートリアル', Icons.school, Colors.blueGrey.shade700,
                  () => _go(context, const TutorialScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _bigButton(
                  context, '駒の動き', Icons.book, Colors.blueGrey.shade700,
                  () => _go(context, const RulesScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _bigButton(
                  context, '使い方', Icons.help_outline, Colors.blueGrey.shade700,
                  () => _go(context, const GuideScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _bigButton(
                  context, 'ランキング', Icons.leaderboard, Colors.blueGrey.shade700,
                  () => _go(context, const RankingScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            _bigButton(
              context, 'バッジ', Icons.military_tech, Colors.blueGrey.shade700,
              () => _go(context, const BadgeScreen()),
            ),
            const SizedBox(height: 20),


            _sectionLabel('戦術・囲い'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _bigButton(
                  context, '囲いパターン', Icons.security, Colors.blueGrey.shade700,
                  () => _go(context, const CastlePatternsScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _bigButton(
                  context, '戦法', Icons.trending_up, Colors.blueGrey.shade700,
                  () => _go(context, const StrategiesScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            _bigButton(
              context, '定跡ガイド', Icons.route, Colors.blueGrey.shade700,
              () => _go(context, const JosekiScreen()),
            ),
            const SizedBox(height: 10),
            _bigButton(
              context, '将棋の格言', Icons.menu_book, Colors.blueGrey.shade700,
              () => _go(context, const ProverbsScreen()),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ===== タブ 3: 設定 =====
class _SettingsTab extends StatelessWidget {
  final int? timeLimitSec;
  final int? byoyomiSec;
  final int fischerIncrementSec;
  final PieceTheme theme;
  final PieceLabelStyle labelStyle;
  final bool speechEnabled;
  final bool soundEnabled;
  final ValueChanged<int?> onTime;
  final ValueChanged<int?> onByoyomi;
  final ValueChanged<int> onFischer;
  final ValueChanged<PieceTheme> onTheme;
  final ValueChanged<PieceLabelStyle> onLabelStyle;
  final ValueChanged<bool> onSpeech;
  final ValueChanged<bool> onSound;

  static const _timeOptions = [null, 180, 300, 600, 900, 1800];
  static const _timeLabels = ['なし', '3分', '5分', '10分', '15分', '30分'];
  static const _fischerOptions = [0, 5, 10, 15, 30];
  static const _fischerLabels = ['なし', '+5秒', '+10秒', '+15秒', '+30秒'];

  const _SettingsTab({
    required this.timeLimitSec,
    required this.byoyomiSec,
    required this.fischerIncrementSec,
    required this.theme,
    required this.labelStyle,
    required this.speechEnabled,
    required this.soundEnabled,
    required this.onTime,
    required this.onByoyomi,
    required this.onFischer,
    required this.onTheme,
    required this.onLabelStyle,
    required this.onSpeech,
    required this.onSound,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const Text(
              '設定',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // ── プレミアム ──
            _sectionLabel('プレミアム'),
            const SizedBox(height: 8),
            _buildPremiumCard(context),
            const SizedBox(height: 20),

            // ── 持ち時間プリセット ──
            _sectionLabel('持ち時間プリセット'),
            const SizedBox(height: 8),
            _buildTimePresets(context),
            const SizedBox(height: 12),

            _settingCard([
              // ── 持ち時間 ──
              _settingRow(
                '持ち時間',
                DropdownButton<int?>(
                  value: timeLimitSec,
                  dropdownColor: const Color(0xFF16213E),
                  style: const TextStyle(color: Colors.white),
                  underline: const SizedBox(),
                  items: List.generate(
                    _timeOptions.length,
                    (i) => DropdownMenuItem(
                      value: _timeOptions[i],
                      child: Text(_timeLabels[i],
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                  onChanged: onTime,
                ),
              ),
              const Divider(color: Colors.white12, height: 16),
              // ── 秒読み ──
              _settingRow(
                '秒読み',
                DropdownButton<int?>(
                  value: byoyomiSec,
                  dropdownColor: const Color(0xFF16213E),
                  style: const TextStyle(color: Colors.white),
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('なし', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 30,   child: Text('30秒', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 60,   child: Text('60秒', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 120,  child: Text('2分',  style: TextStyle(color: Colors.white))),
                  ],
                  onChanged: onByoyomi,
                ),
              ),
              const Divider(color: Colors.white12, height: 16),
              // ── フィッシャー加算 ──
              _settingRow(
                'フィッシャー加算',
                DropdownButton<int>(
                  value: fischerIncrementSec,
                  dropdownColor: const Color(0xFF16213E),
                  style: const TextStyle(color: Colors.white),
                  underline: const SizedBox(),
                  items: List.generate(
                    _fischerOptions.length,
                    (i) => DropdownMenuItem(
                      value: _fischerOptions[i],
                      child: Text(_fischerLabels[i],
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                  onChanged: (v) { if (v != null) onFischer(v); },
                ),
              ),
              const Divider(color: Colors.white12, height: 24),

              // ── 盤面テーマ ──
              _sectionLabel('盤面テーマ'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: PieceTheme.values.map((t) {
                  final cfg = boardThemeConfig(t);
                  final sel = theme == t;
                  return GestureDetector(
                    onTap: () => onTheme(t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 90,
                      decoration: BoxDecoration(
                        color: cfg.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel ? Colors.amber : Colors.white24,
                          width: sel ? 2.5 : 1,
                        ),
                        boxShadow: sel
                            ? [BoxShadow(
                                color: Colors.amber.withAlpha(80),
                                blurRadius: 6)]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: cfg.cell,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                    color: cfg.boardBorder, width: 2),
                              ),
                              child: CustomPaint(
                                  painter: _ThemePreviewPainter(cfg: cfg)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              cfg.label,
                              style: TextStyle(
                                color: sel ? Colors.amber : Colors.white70,
                                fontSize: 11,
                                fontWeight: sel
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Divider(color: Colors.white12, height: 24),

              // ── 駒ラベルスタイル ──
              _sectionLabel('駒ラベルスタイル'),
              const SizedBox(height: 10),
              Row(
                children: PieceLabelStyle.values.map((style) {
                  final sel = labelStyle == style;
                  final label = style == PieceLabelStyle.kanji ? '漢字' : '英字 (K/B/R...)';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => onLabelStyle(style),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? Colors.amber.withAlpha(40) : Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sel ? Colors.amber : Colors.white24,
                            width: sel ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: sel ? Colors.amber : Colors.white70,
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Divider(color: Colors.white12, height: 24),

              // ── 音声読み上げ ──
              _settingRow(
                '音声読み上げ',
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    speechEnabled ? Icons.volume_up : Icons.volume_off,
                    color: speechEnabled ? Colors.greenAccent : Colors.white38,
                    size: 18,
                  ),
                  Switch(
                    value: speechEnabled,
                    activeColor: Colors.greenAccent,
                    onChanged: onSpeech,
                  ),
                ]),
              ),
              const Divider(color: Colors.white12, height: 16),
              // ── 駒の音 ──
              _settingRow(
                '駒の音',
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    soundEnabled ? Icons.music_note : Icons.music_off,
                    color: soundEnabled ? Colors.orangeAccent : Colors.white38,
                    size: 18,
                  ),
                  Switch(
                    value: soundEnabled,
                    activeColor: Colors.orangeAccent,
                    onChanged: onSound,
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 20),

            // ── 言語設定 ──
            _sectionLabel('言語 / Language'),
            const SizedBox(height: 8),
            _settingCard([
              Builder(builder: (ctx) => LanguageSettingsWidget(onChanged: () {})),
            ]),
            const SizedBox(height: 20),

            // ── フィードバック ──
            _sectionLabel('フィードバック'),
            const SizedBox(height: 8),
            _settingCard([
              _feedbackTile(
                context,
                icon: Icons.bug_report_outlined,
                color: Colors.redAccent,
                title: 'バグを報告する',
                subtitle: '不具合・おかしな動作を教えてください',
                type: FeedbackType.bug,
              ),
              const Divider(color: Colors.white12, height: 16),
              _feedbackTile(
                context,
                icon: Icons.lightbulb_outline,
                color: Colors.amber,
                title: '改善要望を送る',
                subtitle: 'こんな機能が欲しい！をお聞かせください',
                type: FeedbackType.request,
              ),
              const Divider(color: Colors.white12, height: 16),
              _feedbackTile(
                context,
                icon: Icons.chat_bubble_outline,
                color: Colors.blueAccent,
                title: 'その他のご意見',
                subtitle: 'ご感想・お問い合わせ',
                type: FeedbackType.other,
              ),
            ]),
            const SizedBox(height: 24),

            // ── アプリについて ──
            _sectionLabel('アプリについて'),
            const SizedBox(height: 8),
            _settingCard([
              const Text(
                '参考資料',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _SourceLink(
                title: '将棋講座.com',
                subtitle: '将棋の格言・定跡・囲いの総合情報',
                url: 'https://xn--pet04dr1n5x9a.com/',
              ),
              const SizedBox(height: 10),
              _SourceLink(
                title: '将棋研究',
                subtitle: '定跡・戦法・手筋の詳細解説',
                url: 'https://www.shougi.jp/',
              ),
            ]),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePresets(BuildContext context) {
    // (label, timeLimitSec, byoyomiSec)
    const presets = [
      ('⚡ 早指し', 180, 30),
      ('⏱ 標準', 600, 60),
      ('🕐 長考', 1800, 120),
    ];
    return Row(
      children: presets.map((p) {
        final active = timeLimitSec == p.$2 && byoyomiSec == p.$3;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () {
                onTime(p.$2);
                onByoyomi(p.$3);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? Colors.brown.shade700 : Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active ? Colors.amber : Colors.white24,
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  p.$1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? Colors.amber : Colors.white70,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ===== 共通ウィジェット =====

Widget _sectionLabel(String text) => Text(
  text,
  style: const TextStyle(
    color: Colors.white70,
    fontSize: 13,
    letterSpacing: 2,
    fontWeight: FontWeight.w500,
  ),
);

// レベルバッジ: 学習機能の対象レベルを示す小さなチップ
Widget _levelChip(String label, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(
    color: color.withAlpha(40),
    borderRadius: BorderRadius.circular(4),
    border: Border.all(color: color.withAlpha(120), width: 1),
  ),
  child: Text(
    label,
    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
  ),
);

// 学習カテゴリ見出し
Widget _studyLevelHeader(String level, Color color, IconData icon) => Padding(
  padding: const EdgeInsets.only(top: 16, bottom: 6),
  child: Row(
    children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 6),
      Text(
        level,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
      ),
      const SizedBox(width: 8),
      Expanded(child: Container(height: 1, color: color.withAlpha(60))),
    ],
  ),
);

Widget _bigButton(BuildContext context, String label, IconData icon,
    Color color, VoidCallback onTap) {
  return ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
    ),
    onPressed: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

Widget _bannerButton(BuildContext context, String label, IconData icon,
    Color color, String subtitle) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [color.withAlpha(180), color.withAlpha(220)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withAlpha(100)),
    ),
    child: Row(children: [
      Icon(icon, color: Colors.white, size: 28),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(subtitle, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 12)),
      ]),
      const Spacer(),
      const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
    ]),
  );
}

Widget _settingCard(List<Widget> children) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: const Color(0xFF16213E),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.white12),
  ),
  child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: children),
);

Widget _settingChip(String text, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  decoration: BoxDecoration(
    color: color.withAlpha(50),
    border: Border.all(color: color, width: 0.8),
    borderRadius: BorderRadius.circular(10),
  ),
  child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
);

Widget _settingRow(String label, Widget control) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    children: [
      Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 14)),
      const Spacer(),
      control,
    ],
  ),
);

Widget _buildPremiumCard(BuildContext context) => Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: const Color(0xFF16213E),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: PurchaseService.isPremium ? Colors.amber.shade700 : Colors.white12,
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(Icons.diamond, color: PurchaseService.isPremium ? Colors.amber.shade400 : Colors.white54, size: 18),
          const SizedBox(width: 8),
          Text(
            PurchaseService.isPremium ? 'プレミアム購入済み' : 'プレミアムプラン',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (!PurchaseService.isPremium) ...[
        const Text(
          '300円・500円のプランから選択',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              minimumSize: const Size(double.infinity, 36),
            ),
            child: const Text('プレミアムプランを購入', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    ],
  ),
);

Widget _feedbackTile(
  BuildContext context, {
  required IconData icon,
  required Color color,
  required String title,
  required String subtitle,
  required FeedbackType type,
}) {
  return InkWell(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FeedbackScreen(initialType: type),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withAlpha(80)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
        ],
      ),
    ),
  );
}

class _SourceLink extends StatelessWidget {
  final String title;
  final String subtitle;
  final String url;

  const _SourceLink({
    required this.title,
    required this.subtitle,
    required this.url,
  });

  Future<void> _openUrl() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _openUrl,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blue.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.withAlpha(80), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.link, color: Colors.blue.shade400, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.blue.shade400,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.open_in_new, color: Colors.blue.withAlpha(150), size: 14),
          ],
        ),
      ),
    );
  }
}

// ===== テーマプレビュー CustomPainter =====
class _ThemePreviewPainter extends CustomPainter {
  final BoardThemeConfig cfg;
  const _ThemePreviewPainter({required this.cfg});

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 3;
    // 3×3 グリッド
    final gridP = Paint()..color = cfg.cellBorder..strokeWidth = 0.5;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), gridP);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), gridP);
    }
    // 星目
    final dotP = Paint()..color = cfg.starPoint..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cell, cell), 3, dotP);
    // 王
    final tp = TextPainter(
      text: TextSpan(
        text: '王',
        style: TextStyle(
            color: cfg.pieceNormal, fontSize: cell * 0.7,
            fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset(cell * 2 - tp.width / 2, cell * 2 - tp.height / 2));
  }

  @override
  bool shouldRepaint(_ThemePreviewPainter old) => old.cfg != cfg;
}

class _RatingMiniGraphPainter extends CustomPainter {
  final List<int> history;
  final int currentRating;
  const _RatingMiniGraphPainter({required this.history, required this.currentRating});

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;
    final mn = history.reduce((a, b) => a < b ? a : b) - 50;
    final mx = history.reduce((a, b) => a > b ? a : b) + 50;
    final range = (mx - mn).toDouble();
    if (range <= 0) return;

    final pts = <Offset>[];
    for (int i = 0; i < history.length; i++) {
      final x = (i / (history.length - 1)) * size.width;
      final y = size.height - ((history[i] - mn) / range) * size.height;
      pts.add(Offset(x, y));
    }

    // Draw filled area
    final path = Path()..moveTo(pts.first.dx, size.height);
    for (final p in pts) path.lineTo(p.dx, p.dy);
    path..lineTo(pts.last.dx, size.height)..close();
    canvas.drawPath(path, Paint()
      ..color = Colors.lightBlueAccent.withAlpha(20)
      ..style = PaintingStyle.fill);

    // Draw line
    final linePaint = Paint()
      ..color = Colors.lightBlueAccent.withAlpha(160)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) linePath.lineTo(pts[i].dx, pts[i].dy);
    canvas.drawPath(linePath, linePaint);

    // Last point dot
    canvas.drawCircle(pts.last, 3, Paint()..color = Colors.lightBlueAccent);
  }

  @override
  bool shouldRepaint(_RatingMiniGraphPainter old) =>
      old.history != history || old.currentRating != currentRating;
}
