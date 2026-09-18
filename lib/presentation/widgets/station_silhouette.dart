import 'package:flutter/material.dart';

/// 駅舎のシルエット(単色フラット)。電車イラストの背景に添える、控えめな
/// 装飾用パーツ。三角屋根の駅舎本体+ホーム上家(片流れの庇)の簡易シルエット。
class StationSilhouette extends StatelessWidget {
  const StationSilhouette({super.key, this.width = 130, this.color = const Color(0xFF3F6B4C)});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 0.72,
      child: CustomPaint(painter: _StationPainter(color)),
    );
  }
}

class _StationPainter extends CustomPainter {
  const _StationPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final w = size.width;
    final h = size.height;

    // 駅舎本体(三角屋根+四角い建物)。
    final bodyLeft = w * 0.28;
    final bodyWidth = w * 0.44;
    final bodyTop = h * 0.32;
    final path = Path()
      ..moveTo(bodyLeft, bodyTop)
      ..lineTo(bodyLeft + bodyWidth / 2, h * 0.06)
      ..lineTo(bodyLeft + bodyWidth, bodyTop)
      ..lineTo(bodyLeft + bodyWidth, h)
      ..lineTo(bodyLeft, h)
      ..close();
    canvas.drawPath(path, paint);

    // ホーム上家(左側に伸びる片流れの庇)を支える柱2本+屋根。
    const canopyPoleCount = 2;
    final canopyLeft = 0.0;
    final canopyRight = bodyLeft + 4;
    final canopyTop = h * 0.5;
    canvas.drawRect(Rect.fromLTRB(canopyLeft, canopyTop, canopyRight, canopyTop + h * 0.06), paint);
    for (var i = 0; i < canopyPoleCount; i++) {
      final x = canopyLeft + (canopyRight - canopyLeft) * (0.2 + i * 0.55);
      canvas.drawRect(Rect.fromLTWH(x, canopyTop + h * 0.06, w * 0.02, h * 0.44), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StationPainter oldDelegate) => oldDelegate.color != color;
}
