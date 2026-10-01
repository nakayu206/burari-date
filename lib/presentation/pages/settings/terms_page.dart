import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../widgets/terms_and_privacy_body.dart';

/// 利用規約画面(設定の「利用規約」。Issue #62・#97)。利用規約とプライバシー
/// ポリシーの本文を表示する。お問い合わせは、別画面([ContactPage])。
///
/// Figmaに参照なし。仕様書10.5「規約に『過度な連続利用は制限する場合が
/// ある』旨の一文を入れておく」に対応する(第4条)。文面は[legal_texts.dart]。
class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('利用規約')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          children: TermsAndPrivacyBody.children(),
        ),
      ),
    );
  }
}
