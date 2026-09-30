import 'package:flutter/material.dart';

/// クリーム色と深緑のドット絵の駅舎。電車イラストと同じ配色で、ホーム画面の
/// 背景に添える。三角屋根の駅舎本体+ホーム上家(片流れの庇)を描く。
class StationSilhouette extends StatelessWidget {
  const StationSilhouette({super.key, this.width = 130});

  final double width;

  /// 24×17マスのグリッドを等倍で拡大するための縦横比。
  static const _aspect = 17 / 24;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * _aspect,
      child: const CustomPaint(painter: _StationPainter()),
    );
  }
}

class _StationPainter extends CustomPainter {
  const _StationPainter();

  static const _ink = Color(0xFF2E2923);
  static const _cream = Color(0xFFF3E6BC);
  static const _creamShade = Color(0xFFD7C394);
  static const _green = Color(0xFF3F6B4C);
  static const _greenShade = Color(0xFF2D503B);
  static const _glass = Color(0xFF294955);
  static const _glassLight = Color(0xFF527780);
  static const _lamp = Color(0xFFFFE9A0);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 17);
    final paint = Paint()..isAntiAlias = false;

    void block(double x, double y, double w, double h, Color color) {
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint..color = color);
    }

    // 三角屋根は階段状に積み、輪郭→本体色の順で塗る。
    block(11, 0, 2, 1, _ink);
    block(9, 1, 6, 1, _ink);
    block(7, 2, 10, 1, _ink);
    block(6, 3, 12, 1, _ink);
    block(11.5, 0.5, 1, 0.5, _green);
    block(9.5, 1.5, 5, 0.5, _green);
    block(7.5, 2.5, 9, 0.5, _green);
    block(6.5, 3.5, 11, 0.5, _greenShade);

    // 壁と、巾木の深緑。
    block(7, 4, 10, 13, _ink);
    block(8, 4, 8, 12, _cream);
    block(8, 14, 8, 2, _green);
    block(8, 15.5, 8, 0.5, _greenShade);
    block(8, 12, 8, 0.5, _creamShade);

    // 時計・窓・入口。
    block(11, 5, 2, 2, _ink);
    block(11.5, 5.5, 1, 1, _lamp);
    block(8.5, 8, 2, 3, _ink);
    block(9, 8.5, 1, 2, _glass);
    block(9, 8.5, 1, 0.5, _glassLight);
    block(13.5, 8, 2, 3, _ink);
    block(14, 8.5, 1, 2, _glass);
    block(14, 8.5, 1, 0.5, _glassLight);
    block(11, 11, 2, 6, _ink);
    block(11.5, 11.5, 1, 5, _glass);
    block(11.5, 11.5, 1, 1, _glassLight);

    // ホーム上家: 片流れの庇と柱2本。
    block(0, 8, 8, 1, _ink);
    block(0, 8, 7, 0.5, _green);
    block(0, 9, 7, 1, _greenShade);
    block(1, 10, 1, 7, _ink);
    block(5, 10, 1, 7, _ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StationPainter oldDelegate) => false;
}
