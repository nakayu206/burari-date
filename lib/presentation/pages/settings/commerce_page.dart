import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../widgets/terms_and_privacy_body.dart';
import 'legal_texts.dart';

/// 特定商取引法に基づく表記の画面(設定と購入画面から開く。Issue #205)。
/// 公式サイトの「特定商取引法に基づく表記」のページと、同じ文面([commerceSections])。
class CommercePage extends StatelessWidget {
  const CommercePage({super.key});

  static const title = '特定商取引法に基づく表記';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          children: [
            for (final section in commerceSections) LegalSectionView(section),
            const SizedBox(height: AppSpacing.x2l),
          ],
        ),
      ),
    );
  }
}
