import 'package:flutter/material.dart';

/// 寄り添う二人+ハートのドット絵。アイコンの二人に合わせた配色で、ホーム画面の
/// 電車イラストに「デート」らしさを添えるための装飾パーツ(ユーザー
/// フィードバック:「デートがメインだから電車とデート感も入れたい」)。
class CoupleSilhouette extends StatelessWidget {
  const CoupleSilhouette({super.key, this.width = 34});

  final double width;

  /// 12×18マスのグリッドを等倍で拡大するための縦横比。
  static const _aspect = 1.5;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * _aspect,
      child: const CustomPaint(painter: _CouplePainter()),
    );
  }
}

class _CouplePainter extends CustomPainter {
  const _CouplePainter();

  static const _ink = Color(0xFF2E2923);
  static const _skin = Color(0xFFF2C9A0);
  static const _hair = Color(0xFF5A3A28);
  static const _green = Color(0xFF3F6B4C);
  static const _greenShade = Color(0xFF2D503B);
  static const _red = Color(0xFFB23A1E);
  static const _redShade = Color(0xFF8A2C16);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 12, size.height / 18);
    final paint = Paint()..isAntiAlias = false;

    void block(double x, double y, double w, double h, Color color) {
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint..color = color);
    }

    // 頭と体は輪郭(0.5マス外側)→本体色の順で描く。
    void person({
      required double x,
      required double top,
      required Color hair,
      required Color body,
      required Color bodyShade,
    }) {
      block(x - 0.5, top - 0.5, 6, 5, _ink);
      block(x - 0.5, top + 3.5, 6, 8.5, _ink);
      block(x, top, 5, 2, hair);
      block(x, top + 2, 5, 2, _skin);
      block(x + 1, top + 2, 1, 1, _ink);
      block(x + 3, top + 2, 1, 1, _ink);
      block(x, top + 4, 5, 8, body);
      block(x, top + 4, 1, 8, bodyShade);
    }

    person(x: 1, top: 6, hair: _hair, body: _green, bodyShade: _greenShade);
    person(x: 6, top: 7, hair: _hair, body: _red, bodyShade: _redShade);

    // ハート(5×4マス)。
    block(4, 0, 2, 1, _red);
    block(7, 0, 2, 1, _red);
    block(4, 1, 5, 1, _red);
    block(5, 2, 3, 1, _red);
    block(6, 3, 1, 1, _red);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CouplePainter oldDelegate) => false;
}
