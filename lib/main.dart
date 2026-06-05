// lib/main.dart — アプリエントリ + BottomNavigation ホーム画面

import 'package:flutter/material.dart';
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
import 'subscription_card.dart';
import 'network_lobby_screen.dart';
import 'network_game_service.dart';
import 'ranking_screen.dart';
import 'badge_screen.dart';
import 'cloud_sync_service.dart';
import 'ai_data_service.dart';
import 'weekly_review_screen.dart';
import 'feedback_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdService.initialize();
  await PurchaseService.initialize();
  // Firebase 初期化（設定済みの場合のみ有効）
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    NetworkGameService.setFirebaseReady();
    CloudSyncService.setReady();
    AiDataService.setReady();
    // 起動時: サーバーデータ取得 + オープニングブック DL（バックグラウンド）
    CloudSyncService.pullAndMerge();
    AiDataService.downloadOpeningBook();
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
  PieceTheme _theme = PieceTheme.standard;
  bool _speechEnabled = false;
  bool _soundEnabled = true;

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
            theme: _theme,
          ),
          const _KifuTab(),
          const _StudyTab(),
          _SettingsTab(
            timeLimitSec: _timeLimitSec,
            byoyomiSec: _byoyomiSec,
            theme: _theme,
            speechEnabled: _speechEnabled,
            soundEnabled: _soundEnabled,
            onTime: (v) => setState(() => _timeLimitSec = v),
            onByoyomi: (v) => setState(() => _byoyomiSec = v),
            onTheme: (v) => setState(() => _theme = v),
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
  final PieceTheme theme;
  const _PlayTab({
    required this.timeLimitSec,
    required this.byoyomiSec,
    required this.theme,
  });
  @override
  State<_PlayTab> createState() => _PlayTabState();
}

class _PlayTabState extends State<_PlayTab> {
  int _rating = 700;
  String _rank = '10級';
  Color _rankColor = Colors.white54;

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
      if (mounted) {
        setState(() {
          _rating = r;
          _rank   = ratingToRank(r);
          _rankColor = ratingToColor(r);
        });
      }
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

            _sectionLabel('局面エディタ'),
            const SizedBox(height: 10),
            _bigButton(
              context, '統計', Icons.bar_chart, Colors.indigo.shade600,
              () => _go(context, const StatsScreen()),
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
            const SizedBox(height: 20),

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
                    Text('12問・4カテゴリの手筋問題', style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 12)),
                  ]),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            _sectionLabel('プレミアム機能'),
            const SizedBox(height: 10),
            _bigButton(context, '週次AI振り返り 👑', Icons.analytics, Colors.purple.shade700,
              () => _go(context, const WeeklyReviewScreen())),
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
  final PieceTheme theme;
  final bool speechEnabled;
  final bool soundEnabled;
  final ValueChanged<int?> onTime;
  final ValueChanged<int?> onByoyomi;
  final ValueChanged<PieceTheme> onTheme;
  final ValueChanged<bool> onSpeech;
  final ValueChanged<bool> onSound;

  static const _timeOptions = [null, 180, 300, 600, 900];
  static const _timeLabels = ['なし', '3分', '5分', '10分', '15分'];

  const _SettingsTab({
    required this.timeLimitSec,
    required this.byoyomiSec,
    required this.theme,
    required this.speechEnabled,
    required this.soundEnabled,
    required this.onTime,
    required this.onByoyomi,
    required this.onTheme,
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

            // ── 課金・広告 ──
            _sectionLabel('課金・広告'),
            const SizedBox(height: 8),
            const SubscriptionCard(),
            const SizedBox(height: 20),

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
          ],
        ),
      ),
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
