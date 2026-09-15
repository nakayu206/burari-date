import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';

/// 利用規約・お問い合わせ画面。
///
/// Figmaに参照なし。仕様書10.5「規約に『過度な連続利用は制限する場合が
/// ある』旨の一文を入れておく」に対応するプレースホルダーテキストを含む。
class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

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
            const Text(
              '利用規約',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.bodyLarge,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              '本アプリは「ぶらりデートガチャ」の利用に関する規約(たたき台)です。'
              '正式な規約は今後整備します。\n\n'
              '・本アプリがAIで生成するお店・観光地の紹介文は参考情報であり、'
              '営業状況や内容を保証するものではありません。ご利用の際は最新情報を'
              'ご自身でもご確認ください。\n'
              '・過度な連続利用(フェアユース上限超過)がある場合、機能を制限させて'
              'いただく場合があります(仕様書10.5)。',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.x2l),
            const Text(
              'お問い合わせ',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.bodyLarge,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'お問い合わせ窓口は準備中です。',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
