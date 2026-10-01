import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/contact.dart';
import '../../../core/constants/app_spacing.dart';
import '../../widgets/terms_and_privacy_body.dart';

/// launchUrlと同じ形の関数型。実機では実際のurl_launcher.launchUrlを使うが、
/// テストでは実プラットフォーム呼び出し(ブラウザ起動等)を避けるため差し替える。
typedef ContactUrlLauncher = Future<bool> Function(Uri url, {LaunchMode mode});

/// お問い合わせ画面(設定の「お問い合わせ」。Issue #62・#97)。
///
/// お問い合わせフォームのURL([kContactFormUrl])が設定されていれば、フォームを
/// 外部のアプリで開くボタンを出す。空の間は「準備中」と表示する。
class ContactPage extends StatelessWidget {
  const ContactPage({
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
      appBar: AppBar(title: const Text('お問い合わせ')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          children: [
            if (contactUrl.isEmpty)
              const LegalBodyText('お問い合わせ窓口は準備中です。')
            else ...[
              const LegalBodyText('ご質問・ご要望・情報の削除のご依頼などは、下のフォームからご連絡ください。'),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () => _openContactForm(context),
                child: const Text('お問い合わせフォームを開く'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
