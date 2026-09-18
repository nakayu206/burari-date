import 'package:flutter/material.dart';

/// 昭和レトロPOP トンマナ(docs/デザイントークン.md 参照)。
/// Figmaデザイン案から抽出したカラーパレット。マジックナンバー禁止のため、
/// 色は必ずこの定数を経由する。
class AppColors {
  const AppColors._();

  static const primary = Color(0xFFB23A1E); // ベンガラ色。主要ボタン・アクセント
  static const primaryLight = Color(0xFFFAF5E6); // 入力欄・カードの淡い背景
  static const secondary = Color(0xFF3F6B4C); // 差し色(検索欄・候補カードの枠)。電車イラストの深緑と統一
  static const background = Color(0xFFF3EEDC); // 背景。電車イラストのクリーム色と統一
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF2E2115); // 見出し・濃いテキスト、枠線
  static const textSecondary = Color(0xFF8A5A2E); // サブテキスト
}
