import 'package:flutter/material.dart';

/// 寄り添う二人のシルエット+小さなハート。ホーム画面の電車イラストに
/// 「デート」らしさを添えるための装飾パーツ(ユーザーフィードバック:
/// 「デートがメインだから電車とデート感も入れたい」)。
class CoupleSilhouette extends StatelessWidget {
  const CoupleSilhouette({
    super.key,
    this.width = 34,
    this.color = const Color(0xFF3F6B4C),
  });

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 1.5,
      child: CustomPaint(painter: _CoupleSilhouettePainter(color)),
    );
  }
}

class _CoupleSilhouettePainter extends CustomPainter {
  const _CoupleSilhouettePainter(this.color);

  final Color color;

  static const _heartColor = Color(0xFFB23A1E);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final w = size.width;
    final h = size.height;

    _drawPerson(
      canvas,
      paint,
      centerX: w * 0.32,
      baseY: h,
      headRadius: w * 0.15,
      bodyWidth: w * 0.34,
      bodyHeight: h * 0.5,
    );
    _drawPerson(
      canvas,
      paint,
      centerX: w * 0.68,
      baseY: h,
      headRadius: w * 0.17,
      bodyWidth: w * 0.38,
      bodyHeight: h * 0.58,
    );

    _drawHeart(
      canvas,
      Paint()..color = _heartColor,
      center: Offset(w * 0.5, h * 0.14),
      size: w * 0.22,
    );
  }

  void _drawPerson(
    Canvas canvas,
    Paint paint, {
    required double centerX,
    required double baseY,
    required double headRadius,
    required double bodyWidth,
    required double bodyHeight,
  }) {
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, baseY - bodyHeight / 2),
        width: bodyWidth,
        height: bodyHeight,
      ),
      Radius.circular(bodyWidth / 2),
    );
    canvas.drawRRect(bodyRect, paint);
    final headCenter = Offset(centerX, baseY - bodyHeight - headRadius * 0.8);
    canvas.drawCircle(headCenter, headRadius, paint);
  }

  void _drawHeart(
    Canvas canvas,
    Paint paint, {
    required Offset center,
    required double size,
  }) {
    final path = Path()
      ..moveTo(center.dx, center.dy + size * 0.35)
      ..cubicTo(
        center.dx - size,
        center.dy - size * 0.4,
        center.dx - size * 0.5,
        center.dy - size * 1.1,
        center.dx,
        center.dy - size * 0.3,
      )
      ..cubicTo(
        center.dx + size * 0.5,
        center.dy - size * 1.1,
        center.dx + size,
        center.dy - size * 0.4,
        center.dx,
        center.dy + size * 0.35,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CoupleSilhouettePainter oldDelegate) =>
      oldDelegate.color != color;
}
