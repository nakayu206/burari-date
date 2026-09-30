import 'dart:io';

import 'package:image/image.dart' as img;

/// Android 12のスプラッシュは中央の円形しか表示されないため、アイコンに余白を
/// 付けた専用画像を作る。
void main() {
  final src = img.decodePng(File('assets/images/icon.png').readAsBytesSync())!;
  const canvas = 1152;
  const inner = 576;
  final out = img.Image(width: canvas, height: canvas, numChannels: 4);
  img.fill(out, color: img.ColorRgba8(0xF3, 0xEE, 0xDC, 0xFF));
  final scaled = img.copyResize(
    src,
    width: inner,
    height: inner,
    interpolation: img.Interpolation.nearest,
  );
  img.compositeImage(
    out,
    scaled,
    dstX: (canvas - inner) ~/ 2,
    dstY: (canvas - inner) ~/ 2,
  );
  File(
    'assets/images/splash_android12.png',
  ).writeAsBytesSync(img.encodePng(out));
}
