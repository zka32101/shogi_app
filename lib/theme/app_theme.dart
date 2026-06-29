// lib/theme/app_theme.dart
// アプリ全体のデザイントークン（色・余白・角丸・影）を一元管理する。
// 主色=藍、背景=濃ネイビー。各画面はここを参照して見た目を統一する。

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── カラー ────────────────────────────────────────────────
  static const bg          = Color(0xFF1A1A2E); // 画面背景
  static const surface     = Color(0xFF16213E); // カード/バー
  static const surfaceHigh = Color(0xFF22305A); // 強調面
  static const primary     = Color(0xFF3B82F6); // 藍（対局・主操作）
  static const primaryDark = Color(0xFF1D4ED8);
  static const accent      = Color(0xFFF59E0B); // アンバー（手番・注意）
  static const danger      = Color(0xFFEF4444); // 投了・残り時間少
  static const success     = Color(0xFF34D399); // 再開・勝利

  static const textHigh = Color(0xFFF5F5F7);
  static const textMid  = Color(0xB3FFFFFF); // white70相当
  static const textLow  = Color(0x61FFFFFF); // white38相当

  // ── 余白（8グリッド）─────────────────────────────────────
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 24.0;
  static const s6 = 32.0;

  // ── 角丸 ──────────────────────────────────────────────────
  static const rCard = 12.0;
  static const rBtn  = 10.0;
  static const rChip = 8.0;

  // ── 影 ────────────────────────────────────────────────────
  static List<BoxShadow> glow(Color c, {double blur = 12, double spread = 1}) =>
      [BoxShadow(color: c.withAlpha(70), blurRadius: blur, spreadRadius: spread)];

  static List<BoxShadow> get cardShadow =>
      [const BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 2))];

  // ── 機能カテゴリ → アクセント色 ──────────────────────────
  static const catPlay   = primary;            // 対局系
  static const catGrow   = Color(0xFFA78BFA);  // 育成・実績系（紫）
  static const catSocial = Color(0xFF60A5FA);  // 交流系（青）
  static const catConfig = Color(0xFF94A3B8);  // 設定・課金系（グレー）
}
