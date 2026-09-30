import 'package:flutter/material.dart';

/// クリーム色と深緑のレトロなドット絵電車。
/// ホームとガチャ演出で共用し、背景は描かず各画面になじませる。
class TrainIllustration extends StatelessWidget {
  const TrainIllustration({super.key});

  /// 既存のシーン配置で使う描画幅。
  static const width = 320.0;

  /// 車輪の接地位置を含む描画高さ。
  static const height = 155.0;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _TrainPainter()),
    );
  }
}

class _TrainPainter extends CustomPainter {
  const _TrainPainter();

  static const _ink = Color(0xFF2E2923);
  static const _cream = Color(0xFFF3E6BC);
  static const _creamShade = Color(0xFFD7C394);
  static const _green = Color(0xFF3F6B4C);
  static const _greenShade = Color(0xFF2D503B);
  static const _roof = Color(0xFF77786C);
  static const _roofLight = Color(0xFF9C9C8C);
  static const _glass = Color(0xFF294955);
  static const _glassLight = Color(0xFF527780);
  static const _metal = Color(0xFF999C91);
  static const _lamp = Color(0xFFFFE9A0);
  static const _red = Color(0xFFB23A1E);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // 80列のグリッド。下端を既存の接地位置に合わせ、配置を維持する。
    canvas.scale(size.width / 80, size.height / 38.75);
    canvas.translate(0, 0.75);
    final paint = Paint()..isAntiAlias = false;

    void block(double x, double y, double w, double h, Color color) {
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint..color = color);
    }

    // 集電装置も階段状の矩形だけで描き、曲線やぼかしを使わない。
    block(30, 1, 15, 1, _ink);
    block(32, 2, 1, 2, _ink);
    block(33, 4, 2, 1, _ink);
    block(35, 5, 2, 1, _ink);
    block(37, 6, 1, 3, _ink);
    block(33, 9, 9, 1, _ink);

    // 連結器は車体の後ろに置く。
    block(38, 17, 5, 15, _ink);
    block(39, 18, 1, 12, _roof);
    block(41, 18, 1, 12, _roof);

    void carriage(double x, double w) {
      // 屋根の段差と太い輪郭で低解像度でも車体を読み取れるようにする。
      block(x + 2, 11, w - 4, 1, _ink);
      block(x + 1, 12, w - 2, 1, _ink);
      block(x, 13, w, 20, _ink);
      block(x + 2, 12, w - 4, 1, _roofLight);
      block(x + 1, 13, w - 2, 2, _roof);
      block(x + 1, 15, w - 2, 10, _cream);
      block(x + 1, 25, w - 2, 6, _green);
      block(x + 1, 30, w - 2, 1, _greenShade);
      block(x + 1, 31, w - 2, 1, _creamShade);
      block(x + 2, 33, w - 4, 1, _ink);
      // 段階的な陰影で、ドットの輪郭を保ったまま屋根と鋼板に厚みを出す。
      block(x + 3, 12, w - 6, 0.5, const Color(0xFFBCBCAF));
      block(x + 1, 14, w - 2, 1, const Color(0xFF5B6059));
      block(x + 1, 15, w - 2, 0.5, _creamShade);
      block(x + 1, 24, w - 2, 1, _creamShade);
      block(x + 1, 25, w - 2, 0.5, const Color(0xFF638467));
      block(x + 1, 29, w - 2, 1, const Color(0xFF365E43));
      block(x + 2, 31, w - 4, 0.5, _cream);
      for (final offset in [5.0, 19.0, 27.0]) {
        block(x + offset, 10, 5, 1, _ink);
        block(x + offset + 0.5, 9.5, 4, 1, _roofLight);
        block(x + offset + 1, 10.5, 3, 0.5, _roof);
      }
      // 床下の機器箱と通風スリット。
      block(x + 12, 33, 11, 2.5, _ink);
      block(x + 13, 33.5, 9, 1, _roof);
      for (var i = 0; i < 4; i++) {
        block(x + 14 + i * 2, 33.5, 0.5, 1, _ink);
      }
    }

    carriage(1, 37);
    carriage(43, 35);

    void window(double x, double w) {
      block(x, 17, w, 7, _ink);
      block(x + 1, 18, w - 2, 5, _glass);
      block(x + 1, 18, w - 2, 1, _glassLight);
      block(x + 1, 19, 1, 3, _glassLight);
      block(x + 1, 23, w - 2, 1, _creamShade);
      block(x + 0.5, 17.5, w - 1, 0.5, _metal);
      block(x + 0.5, 18, 0.5, 5, _metal);
      block(x + 1, 20.5, w - 2, 0.5, _metal);
      block(x + w - 2.5, 18.5, 1, 1.5, _glassLight);
      block(x + w - 3.5, 20, 1, 1, _glassLight);
      block(x + 1, 23, w - 2, 0.5, _metal);
    }

    for (final x in [4.0, 12.0, 20.0, 28.0]) {
      window(x, 7);
    }
    window(46, 7);
    window(55, 7);
    window(66, 10);

    // 客用扉の継ぎ目・取っ手・乗降ステップを細かいドットで添える。
    for (final x in [11.5, 54.5]) {
      block(x, 16, 8, 0.5, _creamShade);
      block(x, 16, 0.5, 9, _creamShade);
      block(x + 7.5, 16, 0.5, 9, _creamShade);
      block(x, 25, 0.5, 6, _greenShade);
      block(x + 7.5, 25, 0.5, 6, _greenShade);
      block(x + 3.5, 17, 0.5, 14, _ink);
      block(x + 2.5, 25.5, 0.5, 1.5, _metal);
      block(x + 4.5, 25.5, 0.5, 1.5, _metal);
      block(x - 0.5, 31.5, 9, 0.5, _metal);
    }
    // 車体の点検蓋と小さな銘板。
    for (final x in [5.0, 25.0, 47.0]) {
      block(x, 26.5, 4, 0.5, _greenShade);
      block(x, 27, 0.5, 2, _greenShade);
      block(x + 4, 27, 0.5, 2, _greenShade);
      block(x, 29, 4.5, 0.5, _greenShade);
    }
    block(22, 26, 3, 1, _creamShade);
    // 先頭窓のワイパーも段階状にしてピクセル感を維持する。
    for (var i = 0; i < 4; i++) {
      block(69 + i * 0.5, 22.5 - i * 0.5, 1, 0.5, _ink);
    }

    // 運転席の扉と、先頭の小さな行先表示。
    block(64, 16, 1, 15, _creamShade);
    block(65, 25, 1, 5, _greenShade);
    block(66, 26, 1, 1, _cream);
    block(68, 15, 6, 1, _creamShade);
    block(69, 15, 4, 1, _ink);

    // 段差のついた灯具。淡色の芯を置いて夜景でも目立たせる。
    block(73, 25, 3, 1, _creamShade);
    block(72, 26, 5, 3, _creamShade);
    block(73, 29, 3, 1, _creamShade);
    block(73, 26, 3, 3, _lamp);
    block(74, 26, 1, 2, const Color(0xFFFFF8DE));
    block(69, 28, 2, 2, _ink);
    block(69, 28, 1, 1, _red);
    block(77, 31, 3, 2, _ink);

    // 八角形の車輪もピクセル単位。4輪の下端は全て線路にそろえる。
    for (final x in [6.0, 27.0, 47.0, 68.0]) {
      block(x, 32.5, 8, 1, _roof);
      block(x + 1, 33.5, 6, 0.5, _metal);
      // 0.5単位の段差で丸みを表し、縁・タイヤ・ハブを描き分ける。
      block(x + 2, 32, 4, 6, _ink);
      block(x + 1, 33, 6, 4, _ink);
      block(x + 0.5, 34, 7, 2, _ink);
      block(x + 2, 32.5, 4, 5, _metal);
      block(x + 1.5, 33, 5, 4, _metal);
      block(x + 1, 34, 6, 2, _metal);
      block(x + 2.5, 33, 3, 4, _roof);
      block(x + 2, 33.5, 4, 3, _roof);
      block(x + 2.5, 34, 3, 2, _ink);
      block(x + 3, 33.5, 2, 3, _ink);
      block(x + 3, 34, 2, 2, _metal);
      block(x + 3, 34, 1, 0.5, _cream);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrainPainter oldDelegate) => false;
}
