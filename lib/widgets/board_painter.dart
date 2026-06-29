// lib/widgets/board_painter.dart
// 将棋盤のグリッド・星・テクスチャを描く CustomPainter（game_screen.dart から切り出し）

import 'package:flutter/material.dart';

class BoardPainter extends CustomPainter {
  final Color cellColor;
  final Color borderColor;
  final Color starColor;
  final bool textured;
  final Color? gradientTop;
  final Color? gradientBottom;
  final double? advantageRatio;

  const BoardPainter({
    required this.cellColor,
    required this.borderColor,
    this.starColor = const Color(0xDD000000),
    this.textured = false,
    this.gradientTop,
    this.gradientBottom,
    this.advantageRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / 9;
    final cellH = size.height / 9;

    // 有利度に応じた背景色（AI対局のみ使用: P1有利=青系、P2有利=赤系）
    if (advantageRatio != null && advantageRatio != 0.5) {
      final Color advantageColor;
      if (advantageRatio! > 0.5) {
        final blend = ((advantageRatio! - 0.5) * 2).clamp(0.0, 1.0);
        advantageColor = Color.lerp(
          Colors.transparent, Colors.blue.shade900.withAlpha(40), blend)!;
      } else {
        final blend = ((0.5 - advantageRatio!) * 2).clamp(0.0, 1.0);
        advantageColor = Color.lerp(
          Colors.transparent, Colors.red.shade900.withAlpha(40), blend)!;
      }
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = advantageColor,
      );
    }

    // 質感テーマ用グラデーション背景
    if (textured && gradientTop != null && gradientBottom != null) {
      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [gradientTop!, gradientBottom!],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), gradientPaint);
    }

    final linePaint = Paint()
      ..color = borderColor
      ..strokeWidth = 0.5;

    // テクスチャテーマ用シャドウライン
    if (textured) {
      final shadowPaint = Paint()
        ..color = Colors.black.withAlpha(40)
        ..strokeWidth = 1.5;
      for (int i = 0; i <= 9; i++) {
        canvas.drawLine(Offset(i * cellW + 0.5, 0), Offset(i * cellW + 0.5, size.height), shadowPaint);
        canvas.drawLine(Offset(0, i * cellH + 0.5), Offset(size.width, i * cellH + 0.5), shadowPaint);
      }
    }

    // グリッドライン
    for (int i = 0; i <= 9; i++) {
      canvas.drawLine(Offset(i * cellW, 0), Offset(i * cellW, size.height), linePaint);
      canvas.drawLine(Offset(0, i * cellH), Offset(size.width, i * cellH), linePaint);
    }

    // 星（ほし）— 将棋盤の4交点マーク
    final starPaint = Paint()
      ..color = starColor
      ..style = PaintingStyle.fill;
    final hoshiRadius = cellW * 0.13;

    const hoshiPositions = [(3, 3), (3, 6), (6, 3), (6, 6)];
    for (final (row, col) in hoshiPositions) {
      final x = col * cellW;
      final y = row * cellH;
      if (textured) {
        canvas.drawCircle(
          Offset(x - 0.8, y - 0.8),
          hoshiRadius * 0.55,
          Paint()..color = Colors.white.withAlpha(80)..style = PaintingStyle.fill,
        );
      }
      canvas.drawCircle(Offset(x, y), hoshiRadius, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) =>
      old.cellColor != cellColor ||
      old.borderColor != borderColor ||
      old.starColor != starColor ||
      old.textured != textured ||
      old.advantageRatio != advantageRatio;
}
