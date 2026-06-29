// lib/screens/theme_settings_screen.dart — テーマ設定画面

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// テーマ設定画面
class ThemeSettingsScreen extends StatefulWidget {
  final void Function(bool)? onThemeChanged; // ライト/ダークモード変更コールバック

  const ThemeSettingsScreen({
    super.key,
    this.onThemeChanged,
  });

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  late bool _isDarkMode;
  late bool _useSystemTheme;
  late double _boardSize; // 盤面サイズ（200-400）

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
  }

  Future<void> _loadThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('theme_dark_mode') ?? true;
      _useSystemTheme = prefs.getBool('theme_use_system') ?? false;
      _boardSize = prefs.getDouble('board_size') ?? 280.0;
    });
  }

  Future<void> _saveThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_dark_mode', _isDarkMode);
    await prefs.setBool('theme_use_system', _useSystemTheme);
    widget.onThemeChanged?.call(_isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F3460),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'テーマ設定',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.cyan),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // テーマ選択セクション
          _SectionTitle('テーマモード'),
          const SizedBox(height: 12),
          _ThemeOptionCard(
            title: 'ダークモード',
            description: '目に優しい深色テーマ',
            isSelected: _isDarkMode && !_useSystemTheme,
            onTap: () async {
              setState(() {
                _isDarkMode = true;
                _useSystemTheme = false;
              });
              await _saveThemeSettings();
            },
            preview: _darkModePreview(),
          ),
          const SizedBox(height: 12),
          _ThemeOptionCard(
            title: 'ライトモード',
            description: '明るく見やすいテーマ',
            isSelected: !_isDarkMode && !_useSystemTheme,
            onTap: () async {
              setState(() {
                _isDarkMode = false;
                _useSystemTheme = false;
              });
              await _saveThemeSettings();
            },
            preview: _lightModePreview(),
          ),
          const SizedBox(height: 12),
          _ThemeOptionCard(
            title: 'システム設定に従う',
            description: 'デバイスの設定に自動同期',
            isSelected: _useSystemTheme,
            onTap: () async {
              setState(() {
                _useSystemTheme = true;
              });
              await _saveThemeSettings();
            },
            preview: _autoModePreview(),
          ),
          const SizedBox(height: 32),

          // 現在のテーマ情報
          _SectionTitle('現在のテーマ'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _useSystemTheme
                          ? Icons.phone_android
                          : (_isDarkMode ? Icons.dark_mode : Icons.light_mode),
                      color: Colors.cyan,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _useSystemTheme
                          ? 'システム設定に従う'
                          : (_isDarkMode ? 'ダークモード' : 'ライトモード'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _useSystemTheme
                      ? 'デバイスの設定に自動同期します'
                      : (_isDarkMode
                          ? '目に優しい深色テーマを使用中'
                          : '明るく見やすいテーマを使用中'),
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 盤面サイズ調整
          _SectionTitle('盤面サイズ'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '盤面サイズ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_boardSize.toStringAsFixed(0)}px',
                      style: const TextStyle(
                        color: Colors.cyan,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Slider(
                  value: _boardSize,
                  min: 200,
                  max: 400,
                  divisions: 20,
                  label: '${_boardSize.toStringAsFixed(0)}px',
                  onChanged: (value) async {
                    setState(() => _boardSize = value);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setDouble('board_size', value);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '小←→大',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // テーマプレビュー
          _SectionTitle('盤面プレビュー'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF1A1A2E) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Container(
                width: _boardSize / 2,
                height: _boardSize / 2,
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                  border: Border.all(
                    color: _isDarkMode ? Colors.grey.shade700 : Colors.grey.shade500,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    '♔',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.cyan : Colors.blue,
                      fontSize: _boardSize / 8,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _darkModePreview() => Container(
    width: 60,
    height: 60,
    decoration: BoxDecoration(
      color: const Color(0xFF1A1A2E),
      border: Border.all(color: const Color(0xFF2D4059), width: 2),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Center(
      child: Text(
        '♔',
        style: TextStyle(color: Colors.cyan.shade300, fontSize: 24),
      ),
    ),
  );

  Widget _lightModePreview() => Container(
    width: 60,
    height: 60,
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      border: Border.all(color: Colors.grey.shade400, width: 2),
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Center(
      child: Text(
        '♔',
        style: TextStyle(color: Colors.black87, fontSize: 24),
      ),
    ),
  );

  Widget _autoModePreview() => Container(
    width: 60,
    height: 60,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFF1A1A2E), Colors.grey.shade200],
      ),
      border: Border.all(color: Colors.grey.shade600, width: 2),
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Center(
      child: Text(
        '♔',
        style: TextStyle(color: Colors.cyan, fontSize: 24),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.cyan,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget preview;

  const _ThemeOptionCard({
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          border: Border.all(
            color: isSelected ? Colors.cyan : Colors.grey.shade700,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            preview,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.cyan, size: 24)
            else
              Icon(Icons.radio_button_unchecked, color: Colors.grey.shade600, size: 24),
          ],
        ),
      ),
    );
  }
}
