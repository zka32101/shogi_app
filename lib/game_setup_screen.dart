// lib/game_setup_screen.dart — 対局前設定 UI

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'game_screen.dart';
import 'purchase_service.dart';
import 'castle_guide_service.dart';
import 'theme_config.dart';

class GameSetupScreen extends StatefulWidget {
  final GameMode mode; // pvp or vsAI
  const GameSetupScreen({super.key, required this.mode});

  @override
  State<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen> {
  // ── 設定値 ──
  AILevel _aiLevel = AILevel.easy;
  bool _aiIsP2 = true; // AI が後手か
  int? _timeLimitSec;
  int? _byoyomiSec;
  Handicap _handicap = Handicap.none;
  PieceTheme _theme = PieceTheme.standard;
  VariantType _variant = VariantType.normal;
  bool _aiRated = true;

  // 囲いガイドモード
  bool _castleGuideEnabled = false;
  String _castleGuideName = 'mino';
  int _castleGuideMaxPly = 30;

  // 持ち時間の選択肢
  static const _timeOptions = <int?>[null, 180, 300, 600, 900, 1800];
  static const _timeLabels = ['なし', '3分', '5分', '10分', '15分', '30分'];

  void _startGame() {
    final settings = GameSettings(
      mode: widget.mode,
      aiLevel: _aiLevel,
      aiIsP2: _aiIsP2,
      timeLimitSec: _timeLimitSec,
      byoyomiSec: _byoyomiSec,
      theme: _theme,
      handicap: _handicap,
      variant: _variant,
      aiRated: _aiRated,
      castleGuideEnabled: _castleGuideEnabled,
      castleGuideName: _castleGuideName,
      castleGuideMaxPly: _castleGuideMaxPly,
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => GameScreen(settings: settings)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVsAI = widget.mode == GameMode.vsAI;
    final title = isVsAI ? 'AI対局 - 設定' : 'ローカル対局 - 設定';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── AI 難易度セクション ──────────────────
                if (isVsAI) ...[
                  _sectionHeader(Icons.computer, 'AI難易度'),
                  const SizedBox(height: 10),
                  _aiLevelSection(),
                  const SizedBox(height: 6),
                  Text(
                    _aiLevel.rankDesc,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  _sectionHeader(Icons.swap_horiz, 'AIの担当'),
                  const SizedBox(height: 10),
                  _aiSideSection(),
                  const SizedBox(height: 20),
                  // ── レーティング戦 ──────────────────
                  Row(children: [
                    const Icon(Icons.military_tech, size: 14, color: Colors.amber),
                    const SizedBox(width: 6),
                    const Text('レーティング戦', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const Spacer(),
                    Switch(
                      value: _aiRated,
                      activeColor: Colors.amber,
                      onChanged: (v) => setState(() => _aiRated = v),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  // ── 変則将棋（vsAI） ──────────────────
                  _sectionHeader(Icons.auto_awesome, '変則ルール'),
                  const SizedBox(height: 10),
                  _variantSection(),
                  const SizedBox(height: 20),
                  // ── 囲いガイドモード ──────────────────
                  _sectionHeader(Icons.castle, '囲いガイドモード'),
                  const SizedBox(height: 10),
                  _castleGuideSection(),
                  const SizedBox(height: 20),
                ],

                // ── pvp 専用セクション ──────────────────
                if (!isVsAI) ...[
                  // 駒落ち
                  _sectionHeader(Icons.layers_outlined, '駒落ち'),
                  const SizedBox(height: 10),
                  _handicapSection(),
                  const SizedBox(height: 10),
                  _handicapPreview(),
                  const SizedBox(height: 20),
                  // 変則将棋（pvp）
                  _sectionHeader(Icons.auto_awesome, '変則ルール'),
                  const SizedBox(height: 10),
                  _variantSection(),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),

          // ── 固定フッター「対局を始める」ボタン ──────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: const Color(0xFF16213E),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                onPressed: _startGame,
                icon: const Icon(Icons.play_arrow, size: 24),
                label: const Text(
                  '対局を始める',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI難易度カード ──────────────────────────────────────
  Widget _aiLevelSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AILevel.values.map((lv) {
        final sel = _aiLevel == lv;
        return GestureDetector(
          onTap: () => setState(() => _aiLevel = lv),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: sel ? Colors.brown.shade800 : const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: sel ? Colors.amber : Colors.white24,
                width: sel ? 2 : 1,
              ),
              boxShadow: sel
                  ? [BoxShadow(color: Colors.amber.withAlpha(60), blurRadius: 6)]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lv.rankLabel,
                  style: TextStyle(
                    color: sel ? Colors.amber : Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lv.rankDesc.split(' · ').first,
                  style: TextStyle(
                    color: sel ? Colors.amber.shade200 : Colors.white38,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── AI担当（先手/後手） ──────────────────────────────────
  Widget _aiSideSection() {
    return Row(
      children: [
        _sideChip('先手（▲）', !_aiIsP2, () => setState(() => _aiIsP2 = false)),
        const SizedBox(width: 10),
        _sideChip('後手（△）', _aiIsP2, () => setState(() => _aiIsP2 = true)),
      ],
    );
  }

  Widget _sideChip(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.blueGrey.shade800 : const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? Colors.amber : Colors.white24,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.amber : Colors.white54,
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // ── 持ち時間 ──────────────────────────────────────
  Widget _timeSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_timeOptions.length, (i) {
        final val = _timeOptions[i];
        final sel = _timeLimitSec == val;
        return ChoiceChip(
          label: Text(_timeLabels[i]),
          selected: sel,
          onSelected: (_) => setState(() {
            _timeLimitSec = val;
            // 時間なしなら秒読みもクリア
            if (val == null) _byoyomiSec = null;
          }),
          selectedColor: Colors.green.shade700,
          backgroundColor: const Color(0xFF16213E),
          labelStyle: TextStyle(
            color: sel ? Colors.white : Colors.white54,
            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
          ),
          side: BorderSide(color: sel ? Colors.green.shade400 : Colors.white24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        );
      }),
    );
  }

  // ── 秒読み ──────────────────────────────────────
  Widget _byoyomiSection() {
    final enabled = _timeLimitSec != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.alarm, size: 14, color: Colors.white54),
            const SizedBox(width: 6),
            Text(
              '秒読み${enabled ? '' : '（持ち時間設定時のみ）'}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _byoyomiChip('なし', null, enabled),
              _byoyomiChip('30秒', 30, enabled),
              _byoyomiChip('60秒', 60, enabled),
            ],
          ),
        ],
      ),
    );
  }

  Widget _byoyomiChip(String label, int? val, bool enabled) {
    final sel = _byoyomiSec == val;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      onSelected: enabled ? (_) => setState(() => _byoyomiSec = val) : null,
      selectedColor: Colors.cyan.shade800,
      backgroundColor: const Color(0xFF16213E),
      labelStyle: TextStyle(
        color: sel ? Colors.white : Colors.white54,
        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: sel ? Colors.cyan.shade400 : Colors.white24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  // ── 駒落ち ──────────────────────────────────────
  Widget _handicapSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButton<Handicap>(
        value: _handicap,
        isExpanded: true,
        dropdownColor: const Color(0xFF16213E),
        underline: const SizedBox(),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        items: Handicap.values.map((h) => DropdownMenuItem(
          value: h,
          child: Text(h.label, style: const TextStyle(color: Colors.white)),
        )).toList(),
        onChanged: (h) { if (h != null) setState(() => _handicap = h); },
      ),
    );
  }

  // ── 駒落ちプレビュー ──────────────────────────────────────
  Widget _handicapPreview() {
    final board = initShogiBoard(_handicap);
    final cfg = boardThemeConfig(_theme);
    const cellSize = 22.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.grid_on, size: 12, color: Colors.white38),
          const SizedBox(width: 4),
          const Text('配置プレビュー', style: TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: cfg.background,
              border: Border.all(color: cfg.boardBorder, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(9, (row) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(9, (col) {
                    final piece = board[row][col];
                    return Container(
                      width: cellSize,
                      height: cellSize,
                      decoration: BoxDecoration(
                        color: cfg.cell,
                        border: Border.all(color: cfg.cellBorder.withAlpha(80), width: 0.5),
                      ),
                      child: piece == null
                          ? null
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Transform.rotate(
                                angle: piece.isPlayer1 ? 0 : 3.14159,
                                child: Text(
                                  piece.label,
                                  style: TextStyle(
                                    color: piece.isPlayer1 ? cfg.pieceNormal : cfg.pieceP2,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                    );
                  }),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  // ── 変則将棋選択 ──────────────────────────────────────
  Widget _variantSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: VariantType.values.map((v) {
        final sel = _variant == v;
        return ChoiceChip(
          label: Text(v.label),
          selected: sel,
          onSelected: (_) => setState(() => _variant = v),
          selectedColor: Colors.deepPurple.shade700,
          backgroundColor: const Color(0xFF16213E),
          labelStyle: TextStyle(
            color: sel ? Colors.white : Colors.white54,
            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
          side: BorderSide(
            color: sel ? Colors.deepPurple.shade300 : Colors.white24,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        );
      }).toList(),
    );
  }

  // ── プレミアムテーマ判定 ──────────────────────────────────────
  bool _isPremiumTheme(PieceTheme t) =>
      t == PieceTheme.textured || t == PieceTheme.emerald || t == PieceTheme.cherry;

  // ── テーマ選択タップ ──────────────────────────────────────
  void _onThemeTap(PieceTheme t) {
    if (_isPremiumTheme(t) && !PurchaseService.hasThemePack) {
      _showThemePackDialog();
      return;
    }
    setState(() => _theme = t);
  }

  // ── テーマパック購入ダイアログ ──────────────────────────────────────
  void _showThemePackDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Row(children: [
          Icon(Icons.palette, color: Colors.purple),
          SizedBox(width: 8),
          Text('テーマパック', style: TextStyle(color: Colors.white)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🌿 エメラルド  🌸 桜\n2つのプレミアムテーマを解放します。',
              style: TextStyle(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 12),
            Text(
              PurchaseService.themePackProduct?.price ?? '¥120',
              style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル',
                style: TextStyle(color: Colors.white54)),
          ),
          if (!kIsWeb && PurchaseService.isAvailable)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700),
              onPressed: () async {
                Navigator.pop(context);
                await PurchaseService.purchaseThemePack();
                if (mounted) setState(() {});
              },
              child: const Text('購入する',
                  style: TextStyle(color: Colors.white)),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('※ このデバイスでは購入できません',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  // ── 駒テーマ ──────────────────────────────────────
  Widget _themeSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PieceTheme.values.map((t) {
        final cfg = boardThemeConfig(t);
        final sel = _theme == t;
        final locked = _isPremiumTheme(t) && !PurchaseService.hasThemePack;
        return GestureDetector(
          onTap: () => _onThemeTap(t),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 88,
                decoration: BoxDecoration(
                  color: cfg.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: sel ? Colors.amber : Colors.white24,
                    width: sel ? 2.5 : 1,
                  ),
                  boxShadow: sel
                      ? [BoxShadow(color: Colors.amber.withAlpha(70), blurRadius: 6)]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(5),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: cfg.cell,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: cfg.boardBorder, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            '王',
                            style: TextStyle(
                              color: cfg.pieceNormal,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        cfg.label,
                        style: TextStyle(
                          color: sel ? Colors.amber : Colors.white70,
                          fontSize: 11,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              if (locked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(130),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.lock, color: Colors.white70, size: 20),
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── 囲いガイドモード ──────────────────────────────────────
  Widget _castleGuideSection() {
    final castleOptions = ['yagura', 'mino', 'anaguma', 'kinmusou'];
    final plyOptions = [20, 30, 40];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _castleGuideEnabled ? Colors.amber.withAlpha(120) : Colors.white12,
          width: _castleGuideEnabled ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // トグルスイッチ行
          Row(
            children: [
              Switch(
                value: _castleGuideEnabled,
                onChanged: (v) => setState(() => _castleGuideEnabled = v),
                activeColor: Colors.amber,
              ),
              const SizedBox(width: 8),
              Text(
                '囲いガイドモード',
                style: TextStyle(
                  color: _castleGuideEnabled ? Colors.amber : Colors.white70,
                  fontSize: 14,
                  fontWeight: _castleGuideEnabled ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          // 詳細設定（ON時のみ表示）
          if (_castleGuideEnabled) ...[
            const SizedBox(height: 12),
            const Text(
              'どの囲いを練習しますか？',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: castleOptions.map((key) {
                final sel = _castleGuideName == key;
                return GestureDetector(
                  onTap: () => setState(() => _castleGuideName = key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                    decoration: BoxDecoration(
                      color: sel ? Colors.amber.withAlpha(40) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel ? Colors.amber : Colors.white24,
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      CastleGuideService.castleName(key),
                      style: TextStyle(
                        color: sel ? Colors.amber : Colors.white70,
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text(
              '目標手数:',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: plyOptions.map((ply) {
                final sel = _castleGuideMaxPly == ply;
                return ChoiceChip(
                  label: Text('${ply}手'),
                  selected: sel,
                  onSelected: (_) => setState(() => _castleGuideMaxPly = ply),
                  selectedColor: Colors.amber.shade700,
                  backgroundColor: const Color(0xFF0F1729),
                  labelStyle: TextStyle(
                    color: sel ? Colors.white : Colors.white54,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: sel ? Colors.amber : Colors.white24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              '対局開始後 ${_castleGuideMaxPly}手まで、盤面に囲いへの誘導矢印を表示します。',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  // ── ヘルパー ──────────────────────────────────────
  Widget _sectionHeader(IconData icon, String label) {
    return Row(children: [
      Icon(icon, size: 16, color: Colors.amber.shade300),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          color: Colors.amber.shade200,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    ]);
  }
}
