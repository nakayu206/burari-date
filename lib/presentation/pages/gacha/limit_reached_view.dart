import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/repositories/candidate_repository.dart';
import '../settings/account_page.dart';

/// 利用上限に達したときの表示。
///
/// 上限は、再読み込みしても解消しないため、「再読み込み」は出さず、状況に応じた
/// 案内のボタンを出す。
///
/// | 状況 | ボタン |
/// |---|---|
/// | 無料枠を使い切った・アカウントなし(匿名) | アカウント登録と課金 |
/// | 無料枠を使い切った・アカウントあり | 課金する |
/// | 課金後の月の上限を超えた | 追加課金 |
///
/// アカウント登録・課金の画面は、まだない(Issue #10)ため、ボタンは、既存の
/// アカウント画面につなぐ。実際の流れができたら、この行き先を差し替える。
class LimitReachedView extends StatelessWidget {
  const LimitReachedView({
    super.key,
    required this.error,
    required this.hasAccount,
  });

  final CandidateLimitException error;

  /// アカウントを登録済みか(匿名のままではないか)。
  final bool hasAccount;

  String get _message {
    switch (error.kind) {
      case LimitKind.freeTier:
        // アカウントがないときは、バックエンドの案内(登録と課金)をそのまま出す。
        return hasAccount ? '無料利用の上限に達しました。継続利用には課金が必要です。' : error.message;
      case LimitKind.monthly:
        return '今月の利用上限に達しました。追加でご利用の場合は、追加課金をご利用ください。';
    }
  }

  String get _buttonLabel {
    switch (error.kind) {
      case LimitKind.freeTier:
        return hasAccount ? '課金する' : 'アカウント登録と課金';
      case LimitKind.monthly:
        return '追加課金';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AccountPage())),
              child: Text(_buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
