import 'dart:math';

import 'package:flutter/material.dart';

/// 編成の電車イラスト。CustomPainterで直接描画する(ユーザー提供の参考実装の
/// _drawTrain部分を移植)。先頭車(丸い風防+ヘッドライト)+後続車+
/// パンタグラフ+車輪。S-03 ガチャ演出画面とホーム画面の両方で使う共通部品。
class TrainIllustration extends StatelessWidget {
  const TrainIllustration({super.key});

  static const width = 316.0;
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

  static const _ink = Color(0xFF2E2115);
  static const _bodyLight = Color(0xFF4C7A56);
  static const _bodyMid = Color(0xFF3A6647);
  static const _bodyDark = Color(0xFF274A34);
  static const _roofLight = Color(0xFFFFFFFF);
  static const _roofDark = Color(0xFFE9E9E4);
  static const _glassLight = Color(0xFFEAF6F8);
  static const _glassMid = Color(0xFFBFE1E8);
  static const _glassDark = Color(0xFF9FCBD6);
  static const _wheelLight = Color(0xFF5A5A5A);
  static const _wheelDark = Color(0xFF1B1B1B);
  static const _headlight = Color(0xFFFFEDA0);

  @override
  void paint(Canvas canvas, Size size) {
    // 元の実装(_drawTrain)はシーン全体の座標系(パンタグラフ上端y=192〜
    // 車輪下端y=347、車体左端x=-10〜右端x=306+)で描かれていたため、
    // このウィジェット自体のローカル座標(0,0起点)に収まるよう平行移動する。
    canvas.save();
    canvas.translate(10, -192);

    final pantoPaint = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final pantoPath = Path()
      ..moveTo(150, 232)
      ..lineTo(150, 214)
      ..lineTo(130, 214)
      ..lineTo(130, 196)
      ..lineTo(150, 196);
    canvas.drawPath(pantoPath, pantoPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(126, 192, 48, 4), const Radius.circular(2)),
      Paint()..color = _ink,
    );

    final bodyGradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_bodyLight, _bodyMid, _bodyDark],
      ).createShader(const Rect.fromLTWH(-10, 236, 316, 96));
    final roofGradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_roofLight, _roofDark],
      ).createShader(const Rect.fromLTWH(-10, 236, 316, 18));
    final glassGradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_glassLight, _glassMid, _glassDark],
      ).createShader(const Rect.fromLTWH(0, 262, 40, 28));
    final strokePaint = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final thinStroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final doorSeam = Paint()
      ..color = const Color(0xFF1F3A2A)
      ..strokeWidth = 1.5;
    final mullion = Paint()
      ..color = const Color(0xFF7FAFBB)
      ..strokeWidth = 1;

    // --- 後方車両 ---
    final car2Body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-10, 236, 160, 96),
      const Radius.circular(16),
    );
    canvas.drawRRect(car2Body, bodyGradient);
    canvas.drawRRect(car2Body, strokePaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-10, 236, 160, 18), const Radius.circular(10)),
      roofGradient,
    );
    canvas.drawRect(const Rect.fromLTWH(-10, 322, 160, 10), Paint()..color = const Color(0xFF241A10));

    for (final x in [4.0, 40.0, 76.0, 112.0]) {
      final winRect = RRect.fromRectAndRadius(Rect.fromLTWH(x, 262, 30, 28), const Radius.circular(4));
      canvas.drawRRect(winRect, glassGradient);
      canvas.drawRRect(winRect, thinStroke);
      canvas.drawLine(Offset(x + 15, 262), Offset(x + 15, 290), mullion);
    }
    canvas.drawLine(const Offset(38, 258), const Offset(38, 322), doorSeam);
    canvas.drawLine(const Offset(110, 258), const Offset(110, 322), doorSeam);
    canvas.drawRect(
      const Rect.fromLTWH(-10, 296, 160, 4),
      Paint()..color = _roofLight.withValues(alpha: 0.85),
    );

    // --- 連結部(蛇腹) ---
    canvas.drawRect(const Rect.fromLTWH(148, 256, 16, 66), Paint()..color = const Color(0xFF3A342C));
    canvas.drawRect(const Rect.fromLTWH(148, 256, 16, 66), thinStroke);
    for (final x in [151.0, 156.0, 161.0]) {
      canvas.drawLine(Offset(x, 256), Offset(x, 322), Paint()..color = const Color(0xFF1B1B1B));
    }

    // --- 前方車両(先頭車、鼻先あり) ---
    final car1Path = Path()
      ..moveTo(164, 236)
      ..lineTo(288, 236)
      ..quadraticBezierTo(306, 236, 306, 254)
      ..lineTo(306, 314)
      ..quadraticBezierTo(306, 332, 288, 332)
      ..lineTo(164, 332)
      ..close();
    canvas.drawPath(car1Path, bodyGradient);
    canvas.drawPath(car1Path, strokePaint);

    final roof1Path = Path()
      ..moveTo(164, 236)
      ..lineTo(288, 236)
      ..quadraticBezierTo(300, 236, 300, 248)
      ..lineTo(300, 254)
      ..lineTo(164, 254)
      ..close();
    canvas.drawPath(roof1Path, roofGradient);
    canvas.drawPath(roof1Path, thinStroke);

    canvas.drawRect(const Rect.fromLTWH(164, 322, 142, 10), Paint()..color = const Color(0xFF241A10));

    for (final x in [182.0, 220.0]) {
      final winRect = RRect.fromRectAndRadius(Rect.fromLTWH(x, 262, 34, 28), const Radius.circular(4));
      canvas.drawRRect(winRect, glassGradient);
      canvas.drawRRect(winRect, thinStroke);
      canvas.drawLine(Offset(x + 17, 262), Offset(x + 17, 290), mullion);
    }
    canvas.drawLine(const Offset(254, 258), const Offset(254, 322), doorSeam);

    // 先頭の丸い風防
    final nosePath = Path()
      ..moveTo(258, 262)
      ..lineTo(288, 262)
      ..quadraticBezierTo(300, 262, 300, 274)
      ..lineTo(300, 288)
      ..quadraticBezierTo(300, 296, 292, 298)
      ..lineTo(258, 298)
      ..close();
    canvas.drawPath(nosePath, glassGradient);
    canvas.drawPath(
      nosePath,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // ヘッドライト
    canvas.drawCircle(const Offset(296, 304), 14, Paint()..color = _headlight.withValues(alpha: 0.5));
    canvas.drawCircle(const Offset(296, 304), 6, Paint()..color = _headlight);
    canvas.drawCircle(const Offset(296, 304), 6, thinStroke);
    canvas.drawCircle(const Offset(278, 308), 4, Paint()..color = _bodyMid);
    canvas.drawCircle(
      const Offset(278, 308),
      4,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    canvas.drawRect(
      const Rect.fromLTWH(164, 296, 142, 4),
      Paint()..color = _roofLight.withValues(alpha: 0.85),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(300, 312, 10, 8), const Radius.circular(2)),
      Paint()..color = _ink,
    );

    // --- 車輪 ---
    final wheelGradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_wheelLight, _wheelDark],
      ).createShader(const Rect.fromLTWH(0, 317, 30, 30));
    final wheelRimPaint = Paint()
      ..color = const Color(0xFFB0B0B0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final wheelBoltPaint = Paint()..color = const Color(0xFF3A3A3A);
    for (final cx in [18.0, 70.0, 220.0, 272.0]) {
      final center = Offset(cx, 332);
      canvas.drawCircle(center, 15, wheelGradient);
      canvas.drawCircle(
        center,
        15,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      // 金属のリム(フランジ)を表す明るいリング。
      canvas.drawCircle(center, 11, wheelRimPaint);
      // ハブ周りのボルト。
      for (var i = 0; i < 6; i++) {
        final angle = i * pi / 3;
        canvas.drawCircle(
          center + Offset(cos(angle), sin(angle)) * 7.5,
          1.2,
          wheelBoltPaint,
        );
      }
      canvas.drawCircle(center, 5, Paint()..color = const Color(0xFF8A8A8A));
      canvas.drawCircle(
        center,
        5,
        Paint()
          ..color = Colors.black54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrainPainter oldDelegate) => false;
}
