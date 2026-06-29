// lib/widgets/koma_painter.dart
// 将棋駒の五角形描画（game_screen.dart から切り出し）
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
    canvas.drawPath(
      _koma(w, h, 0.8, 1.4),
      Paint()..color = Colors.black.withAlpha(48),
    );
    canvas.drawPath(_koma(w, h, 0, 0), Paint()..color = fill);
    canvas.drawPath(
      _koma(w, h, 0, 0),
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant KomaPainter old) =>
      old.pointsUp != pointsUp || old.fill != fill || old.border != border;
}
