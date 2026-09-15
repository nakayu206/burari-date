/// フォントサイズのスケール(docs/デザイントークン.md 参照)。
/// Figmaデザイン案の実測値(get_design_context)から抽出。
class AppFontSizes {
  const AppFontSizes._();

  /// 34px。ロゴ(S-01)・到着駅名(S-04)などの最大見出し。
  static const displayLarge = 34.0;

  /// 24px。ガチャ演出のキャプション大(S-03「3駅隣…?」)。
  static const headlineLarge = 24.0;

  /// 16px。候補詳細の店名(S-06)。
  static const titleMedium = 16.0;

  /// 15px。主要ボタンのラベル文字。
  static const buttonLabel = 15.0;

  /// 14px。本文標準・入力文字。
  static const bodyLarge = 14.0;

  /// 13px。本文小・サブキャプション。
  static const bodyMedium = 13.0;

  /// 11px。補足ラベル(入力欄のラベル等)。
  static const labelSmall = 11.0;

  /// 10px。ボトムナビラベル・徒歩分数・日付。
  static const caption = 10.0;

  /// 9px。画面最小の注意書き。
  static const footnote = 9.0;
}
