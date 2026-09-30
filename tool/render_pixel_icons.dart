import 'dart:io';

import 'package:burari_date/presentation/widgets/pixel_icon_data.dart';
import 'package:image/image.dart' as img;

/// ドット絵アイコンを、並べた1枚の画像に書き出す(見た目の確認用)。
/// 使い方: dart run tool/render_pixel_icons.dart <出力するPNGのパス> [倍率]
void main(List<String> args) {
  final scale = args.length > 1 ? int.parse(args[1]) : 8;
  final kinds = PixelIconKind.values;
  const columns = 9;
  final rows = (kinds.length / columns).ceil();
  const gap = 2; // マス単位の余白
  final cell = (pixelIconGrid + gap) * scale;
  final out = img.Image(width: columns * cell, height: rows * cell);
  img.fill(out, color: img.ColorRgb8(0xF3, 0xEE, 0xDC));

  for (var i = 0; i < kinds.length; i++) {
    final rowsData = pixelIconPatterns[kinds[i]]!;
    if (rowsData.length != pixelIconGrid) {
      stderr.writeln('${kinds[i]}: 行数が${rowsData.length}($pixelIconGrid のはず)');
    }
    final ox = (i % columns) * cell + gap * scale ~/ 2;
    final oy = (i ~/ columns) * cell + gap * scale ~/ 2;
    for (var y = 0; y < rowsData.length; y++) {
      final row = rowsData[y];
      if (row.length != pixelIconGrid) {
        stderr.writeln(
          '${kinds[i]} 行$y: ${row.length}文字($pixelIconGrid のはず) "$row"',
        );
      }
      for (var x = 0; x < row.length; x++) {
        final ch = row[x];
        if (ch == '.') continue;
        final color = pixelIconPalette[ch];
        if (color == null) {
          stderr.writeln('${kinds[i]} 行$y 列$x: 未定義の文字 "$ch"');
          continue;
        }
        img.fillRect(
          out,
          x1: ox + x * scale,
          y1: oy + y * scale,
          x2: ox + (x + 1) * scale - 1,
          y2: oy + (y + 1) * scale - 1,
          color: img.ColorRgb8(
            (color >> 16) & 0xFF,
            (color >> 8) & 0xFF,
            color & 0xFF,
          ),
        );
      }
    }
  }
  File(args[0]).writeAsBytesSync(img.encodePng(out));
}
