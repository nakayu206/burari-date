import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/constants/app_spacing.dart';
import '../pages/settings/legal_texts.dart';

/// 利用規約とプライバシーポリシーの本文。設定の「利用規約」画面と、初回の同意画面で
/// 共用する(Issue #97)。ListViewの`children`に並べて使う。
class TermsAndPrivacyBody extends StatelessWidget {
  const TermsAndPrivacyBody({super.key});

  /// 本文を、ListViewの子として並べるためのWidgetの並び。
  static List<Widget> children() => [
    const LegalHeading('利用規約'),
    ..._sections(termsSections),
    const SizedBox(height: AppSpacing.x2l),
    const LegalHeading('プライバシーポリシー'),
    ..._sections(privacySections),
    const SizedBox(height: AppSpacing.x2l),
  ];

  static List<Widget> _sections(List<LegalSection> sections) => [
    for (final section in sections) LegalSectionView(section),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: children(),
  );
}

/// 大見出し(「利用規約」「プライバシーポリシー」「お問い合わせ」など)。
class LegalHeading extends StatelessWidget {
  const LegalHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: AppFontSizes.bodyLarge,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

/// 見出し(条・項目)と本文の1まとまり。
class LegalSectionView extends StatelessWidget {
  const LegalSectionView(this.section, {super.key});

  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.heading,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppFontSizes.bodyMedium,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          LegalBodyText(section.body),
        ],
      ),
    );
  }
}

/// 本文の文字。
class LegalBodyText extends StatelessWidget {
  const LegalBodyText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: AppFontSizes.bodyMedium,
        height: 1.6,
      ),
    );
  }
}
