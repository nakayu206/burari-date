import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/contact.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import 'legal_texts.dart';

/// launchUrlと同じ形の関数型。実機では実際のurl_launcher.launchUrlを使うが、
/// テストでは実プラットフォーム呼び出し(ブラウザ起動等)を避けるため差し替える。
typedef ContactUrlLauncher = Future<bool> Function(Uri url, {LaunchMode mode});

/// 利用規約・プライバシーポリシー・お問い合わせ画面(Issue #62)。
///
/// Figmaに参照なし。仕様書10.5「規約に『過度な連続利用は制限する場合が
/// ある』旨の一文を入れておく」に対応する(第4条)。文面は[legal_texts.dart]。
class TermsPage extends StatelessWidget {
  const TermsPage({
    super.key,
    this.contactUrl = kContactFormUrl,
    @visibleForTesting this.launchUrlOverride = launchUrl,
  });

  /// お問い合わせフォームのURL。空のときは「準備中」と表示する。
  final String contactUrl;

  final ContactUrlLauncher launchUrlOverride;

  Future<void> _openContactForm(BuildContext context) async {
    bool launched;
    try {
      launched = await launchUrlOverride(
        Uri.parse(contactUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }
    if (launched || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('お問い合わせフォームを開けませんでした'),
        content: const Text('時間をおいて、もう一度お試しください。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('利用規約・お問い合わせ')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          children: [
            const _Heading('利用規約'),
            for (final section in termsSections) _Section(section),
            const SizedBox(height: AppSpacing.x2l),
            const _Heading('プライバシーポリシー'),
            for (final section in privacySections) _Section(section),
            const SizedBox(height: AppSpacing.x2l),
            const _Heading('お問い合わせ'),
            const SizedBox(height: AppSpacing.md),
            if (contactUrl.isEmpty)
              const _Body('お問い合わせ窓口は準備中です。')
            else ...[
              const _Body('ご質問・ご要望・情報の削除のご依頼などは、下のフォームからご連絡ください。'),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () => _openContactForm(context),
                child: const Text('お問い合わせフォームを開く'),
              ),
            ],
            const SizedBox(height: AppSpacing.x2l),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

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

class _Section extends StatelessWidget {
  const _Section(this.section);

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
          _Body(section.body),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);

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
