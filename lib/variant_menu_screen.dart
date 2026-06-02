// lib/variant_menu_screen.dart — 変則将棋メニュー

import 'package:flutter/material.dart';
import 'game_screen.dart';

class VariantMenuScreen extends StatefulWidget {
  const VariantMenuScreen({super.key});

  @override
  State<VariantMenuScreen> createState() => _VariantMenuScreenState();
}

class _VariantMenuScreenState extends State<VariantMenuScreen> {
  // プレイヤー設定
  GameMode _gameMode = GameMode.pvp;
  AILevel _aiLevel  = AILevel.easy;

  void _startVariant(VariantType v) {
    final settings = GameSettings(
      mode:    _gameMode,
      aiLevel: _aiLevel,
      aiIsP2:  true,
      variant: v,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameScreen(settings: settings)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('変則将棋', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 対局設定 ──
            _SectionCard(
              title: '対局設定',
              child: Column(children: [
                // 対人 / AI 切り替え
                Row(children: [
                  const Text('対局相手', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(width: 16),
                  _modeChip('ローカル', GameMode.pvp),
                  const SizedBox(width: 8),
                  _modeChip('AI', GameMode.vsAI),
                ]),
                if (_gameMode == GameMode.vsAI) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    const Text('AIレベル', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: AILevel.values.map((lv) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(lv.rankLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _aiLevel == lv ? Colors.black : Colors.white70,
                                  )),
                              selected: _aiLevel == lv,
                              selectedColor: Colors.amber,
                              backgroundColor: const Color(0xFF0F3460),
                              onSelected: (_) => setState(() => _aiLevel = lv),
                            ),
                          )).toList(),
                        ),
                      ),
                    ),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 20),

            // ── バリアント一覧 ──
            const Text(
              'ルールを選択',
              style: TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 1),
            ),
            const SizedBox(height: 12),

            ...VariantType.values
                .where((v) => v != VariantType.normal)
                .map((v) => _VariantCard(
                      variant: v,
                      onTap: () => _startVariant(v),
                    )),

            const SizedBox(height: 8),
            // 標準将棋へのリンクも
            OutlinedButton.icon(
              onPressed: () => _startVariant(VariantType.normal),
              icon: const Icon(Icons.sports_esports, color: Colors.white54),
              label: const Text('標準将棋で対局', style: TextStyle(color: Colors.white54)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(String label, GameMode mode) {
    final selected = _gameMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _gameMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.amber.withAlpha(200) : const Color(0xFF0F3460),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.amber : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ── バリアントカード ──────────────────────────────────────
class _VariantCard extends StatelessWidget {
  final VariantType variant;
  final VoidCallback onTap;
  const _VariantCard({required this.variant, required this.onTap});

  Color get _accentColor {
    switch (variant) {
      case VariantType.captureForced: return Colors.red.shade600;
      case VariantType.noDrops:       return Colors.blueGrey.shade500;
      case VariantType.masked:        return Colors.purple.shade600;
      case VariantType.checkForced:   return Colors.orange.shade700;
      case VariantType.hiddenPieces:  return Colors.teal.shade600;
      case VariantType.kagemusha:     return Colors.deepPurple.shade400;
      case VariantType.invader:       return Colors.green.shade600;
      default:                        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF16213E), _accentColor.withAlpha(30)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accentColor.withAlpha(100), width: 1.5),
            ),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _accentColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accentColor.withAlpha(100)),
                ),
                child: Icon(variant.icon, color: _accentColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      variant.label,
                      style: TextStyle(
                        color: _accentColor,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      variant.description,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: _accentColor.withAlpha(150)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── セクションカード ──────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF16213E),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}
