import 'package:flutter/material.dart';

import '../../domain/entities/candidate.dart';
import 'pixel_icon_data.dart';

/// ドット絵アイコン。電車・駅・背景と同じ配色のブロックだけで描き、曲線や
/// ぼかしを使わない(絵のデータは[pixelIconPatterns])。
///
/// [size]は12の倍数(24・36・48など)にすると、1マスがきれいな整数pxになる。
class PixelIcon extends StatelessWidget {
  const PixelIcon(this.kind, {super.key, this.size = 24});

  final PixelIconKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PixelIconPainter(kind)),
    );
  }
}

class _PixelIconPainter extends CustomPainter {
  const _PixelIconPainter(this.kind);

  final PixelIconKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / pixelIconGrid;
    final paint = Paint()..isAntiAlias = false;
    final rows = pixelIconPatterns[kind]!;
    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      for (var x = 0; x < row.length; x++) {
        final argb = pixelIconPalette[row[x]];
        if (argb == null) continue; // '.'は透明
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell, cell),
          paint..color = Color(argb),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PixelIconPainter oldDelegate) =>
      oldDelegate.kind != kind;
}

/// 候補のジャンルに合うドット絵アイコン。ジャンル名が分からない場合や、対応
/// 表にないジャンルは、カテゴリ(グルメ/観光)ごとの既定のアイコンにする。
class GenreIcon extends StatelessWidget {
  const GenreIcon({
    super.key,
    required this.category,
    this.categoryName,
    this.size = 24,
  });

  final CandidateCategory category;
  final String? categoryName;
  final double size;

  @override
  Widget build(BuildContext context) {
    return PixelIcon(pixelIconKindFor(category, categoryName), size: size);
  }
}

/// ジャンル名から、アイコンの種類を選ぶ。
///
/// グルメはホットペッパーのジャンル名(「中華」「カフェ・スイーツ」など)、観光は
/// Foursquareのカテゴリ名(英語・日本語のどちらでも)を、部分一致で見る。
/// 「Amusement Park」を「Park」より先に判定するなど、判定の順序に意味がある。
PixelIconKind pixelIconKindFor(CandidateCategory category, String? name) {
  final text = (name ?? '').toLowerCase();
  bool has(List<String> words) => words.any(text.contains);

  if (category == CandidateCategory.gourmet) {
    if (has(['ラーメン', '中華'])) return PixelIconKind.ramen;
    if (has(['和食', '寿司', '鮨', '刺身'])) return PixelIconKind.sushi;
    if (has(['イタリアン', 'フレンチ', '洋食', 'ピザ'])) return PixelIconKind.pizza;
    if (has(['カフェ', '喫茶'])) return PixelIconKind.coffee;
    if (has(['スイーツ', 'ケーキ', 'デザート'])) return PixelIconKind.cake;
    if (has(['居酒屋', 'バー', 'バル', 'ダイニング'])) return PixelIconKind.beer;
    if (has(['焼肉', 'ホルモン', 'ステーキ', '肉'])) return PixelIconKind.meat;
    return PixelIconKind.dining;
  }

  if (has(['aquarium', '水族館'])) return PixelIconKind.fish;
  if (has(['amusement', 'theme park', '遊園地', 'テーマパーク'])) {
    return PixelIconKind.ferrisWheel;
  }
  if (has(['arcade', 'game', 'ゲーム'])) return PixelIconKind.ufoCatcher;
  if (has(['museum', 'gallery', '博物館', '美術館', 'ミュージアム']) ||
      RegExp(r'\bart\b').hasMatch(text)) {
    return PixelIconKind.museum;
  }
  if (has(['shrine', 'temple', '神社', '寺', '鳥居'])) return PixelIconKind.torii;
  if (has(['hot spring', 'onsen', '温泉', '銭湯', 'スパ']) ||
      RegExp(r'\b(spa|bath)\b').hasMatch(text)) {
    return PixelIconKind.onsen;
  }
  if (has(['garden', '庭園', '植物園', '花'])) return PixelIconKind.flower;
  return PixelIconKind.tree;
}
