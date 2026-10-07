import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/constants/app_spacing.dart';

/// 「登録」と「ログイン」を、別のまとまりとして、見せるための見出し(Issue #152・#153)。
/// 「はじめての方」「すでに登録済みの方」のように使い、2つのボタンが、近すぎて、押し間違え
/// たり、意味が混ざったりしないようにする。アカウント画面と、プラン画面で、共通。
class AuthSectionHeading extends StatelessWidget {
  const AuthSectionHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppFontSizes.bodyLarge,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// 2つのまとまりの間の、「または」の線。上下に、大きく、間をあける。
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.x2l),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.textSecondary)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'または',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.labelSmall,
              ),
            ),
          ),
          Expanded(child: Divider(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
