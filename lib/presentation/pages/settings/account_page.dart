import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_spacing.dart';

/// アカウント画面。
///
/// Figmaに参照なし。ユーザー登録・ログインの要否は未決定(仕様書9章 /
/// Issue #9)のため、現時点ではゲスト利用中の表示のみのプレースホルダー。
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アカウント')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: AppSizes.iconLg,
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.textSecondary,
                      size: AppSizes.iconLg,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ゲスト利用中',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppFontSizes.bodyLarge,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ログイン機能は未実装です',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppFontSizes.labelSmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x2l),
              const Text(
                'ログイン無しでも履歴・お気に入りをこの端末に保存できます。'
                '複数端末での引き継ぎや、他の人との共有機能は今後のアップデートで検討します。',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFontSizes.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
