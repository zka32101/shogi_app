// lib/widgets/koma_painter.dart
// 将棋駒の五角形描画（光沢グラデーション付き）

import 'package:flutter/material.dart';

class KomaPainter extends CustomPainter {
  final bool pointsUp;
  final Color fill;
  final Color border;
  const KomaPainter({
    required this.pointsUp,
    required this.fill,
    required this.border,
  });

  Path _koma(double w, double h, double dx, double dy) {
    final cx = w / 2 + dx;
    final apexY = (pointsUp ? 0.05 : 0.95) * h + dy;
    final shoulderY = (pointsUp ? 0.26 : 0.74) * h + dy;
    final baseY = (pointsUp ? 0.96 : 0.04) * h + dy;
    final halfTop = w * 0.34;
    final halfBottom = w * 0.44;
    return Path()
      ..moveTo(cx, apexY)
      ..lineTo(cx + halfTop, shoulderY)
      ..lineTo(cx + halfBottom, baseY)
      ..lineTo(cx - halfBottom, baseY)
      ..lineTo(cx - halfTop, shoulderY)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── 1. 影（ソフトシャドウ：2レイヤー） ───────────────────────────────
    canvas.drawPath(
      _koma(w, h, 1.5, 2.5),
      Paint()..color = Colors.black.withAlpha(28),
    );
    canvas.drawPath(
      _koma(w, h, 0.7, 1.2),
      Paint()..color = Colors.black.withAlpha(42),
    );

    // ── 2. 駒本体 ─────────────────────────────────────────────────────────
    final komaPath = _koma(w, h, 0, 0);
    canvas.drawPath(komaPath, Paint()..color = fill);

    // ── 3. 光沢グラデーション（上部1/3に白ハイライト） ───────────────────
    final glowTop = pointsUp ? 0.0 : 0.6;
    final glowBot = pointsUp ? 0.45 : 1.0;
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(0, pointsUp ? -1.0 : 1.0),
        end: Alignment(0, pointsUp ? 0.2 : -0.2),
        colors: [
          Colors.white.withAlpha(100),
          Colors.white.withAlpha(0),
        ],
      ).createShader(
        Rect.fromLTWH(0, h * glowTop, w, h * (glowBot - glowTop)),
      );
    canvas.drawPath(komaPath, glossPaint);

    // ── 4. 縁取り ─────────────────────────────────────────────────────────
    canvas.drawPath(
      komaPath,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // ── 5. 内側の細い縁（立体感） ─────────────────────────────────────────
    canvas.drawPath(
      _koma(w * 0.88, h * 0.88, w * 0.06, h * (pointsUp ? 0.05 : 0.06)),
      Paint()
        ..color = Colors.white.withAlpha(55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant KomaPainter old) =>
      old.pointsUp != pointsUp || old.fill != fill || old.border != border;
}
