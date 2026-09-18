import 'package:flutter/material.dart';

/// 電車イラスト(S-03 ガチャ演出 / S-04 到着駅決定)専用の配色。
/// ユーザー提供の参考画像(クリーム×深緑の昭和レトロな電車)から抽出した、
/// アプリ全体のAppColorsとは独立した配色。
class AppTrainColors {
  const AppTrainColors._();

  static const cream = Color(0xFFF3EEDC);
  static const green = Color(0xFF3F6B4C);
  static const roofGrey = Color(0xFF5B6165);
  static const rail = Color(0xFF6B7176);
  static const window = Color(0xFFBFE0E6);
  static const windowDark = Color(0xFF1E2A28);
  static const outline = Color(0xFF2E2115);
}
