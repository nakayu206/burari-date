import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/repositories/candidate_repository.dart';
import '../../providers/purchase_providers.dart';
import '../settings/purchase_page.dart';

/// 利用上限に達したときの表示(Issue #134)。
///
/// 上限は、再読み込みしても解消しないため、通常は「再読み込み」は出さず、状況に応じた
/// 案内のボタンを出す。ボタンは、どの状況でも、プラン画面につなぐ。プラン画面が、
/// アカウント未登録なら、先に登録するよう案内し、アカウント画面につなぐ。
///
/// | 状況 | ボタン |
/// |---|---|
/// | 無料枠を使い切った・アカウントなし(匿名) | アカウント登録と課金 |
/// | 無料枠を使い切った・アカウントあり | 課金する |
/// | 課金後の月の上限を超えた | 追加課金 |
/// | 購入済みなのに、サーバーが、まだ無料枠の上限と答える | もう一度読み込む |
///
/// プラン画面から戻ったとき、購読中になっていれば、[onRetry]で、候補を取り直す
/// (購入の前の、上限のエラーを、そのまま残さない)。購入した直後は、サーバーに
/// 購読の状態が反映されるまで、数秒かかるため、まだ上限と答えることがある。その間は、
/// 反映を待つ案内と、「もう一度読み込む」を出す。
///
/// 追加購入の画面は、価格・単位が決まっていないため、まだない。「追加課金」も、いまは
/// プラン画面につなぐ。
class LimitReachedView extends ConsumerWidget {
  const LimitReachedView({
    super.key,
    required this.error,
    required this.hasAccount,
    this.onRetry,
  });

  final CandidateLimitException error;

  /// アカウントを登録済みか(匿名のままではないか)。
  final bool hasAccount;

  /// 候補を取り直す。プラン画面から、購読中で戻ったときと、「もう一度読み込む」で呼ぶ。
  final VoidCallback? onRetry;

  /// 購入済み(購読中)なのに、無料枠の上限と答えられている状態か。購入の直後に、
  /// サーバーへの反映が、間に合っていないことを表す。
  bool _isWaitingForSync(bool isSubscribed) =>
      isSubscribed && error.kind == LimitKind.freeTier;

  String _message(bool isSubscribed) {
    if (_isWaitingForSync(isSubscribed)) {
      return '購入ありがとうございます。購入の内容が反映されるまで、数秒かかることがあります。';
    }
    switch (error.kind) {
      case LimitKind.freeTier:
        // アカウントがないときは、バックエンドの案内(登録と課金)をそのまま出す。
        return hasAccount ? '無料利用の上限に達しました。継続利用には課金が必要です。' : error.message;
      case LimitKind.monthly:
        return '今月の利用上限に達しました。追加でご利用の場合は、追加課金をご利用ください。';
    }
  }

  String _buttonLabel(bool isSubscribed) {
    if (_isWaitingForSync(isSubscribed)) return 'もう一度読み込む';
    switch (error.kind) {
      case LimitKind.freeTier:
        return hasAccount ? '課金する' : 'アカウント登録と課金';
      case LimitKind.monthly:
        return '追加課金';
    }
  }

  Future<void> _openPurchasePage(BuildContext context, WidgetRef ref) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PurchasePage()));
    if (!context.mounted) return;
    // 購読中で戻ったときだけ、取り直す(購入しないで戻ったときは、上限のまま)。
    final isSubscribed =
        ref.read(subscriptionStatusProvider).value?.isActive ?? false;
    if (isSubscribed) onRetry?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSubscribed = ref
        .watch(subscriptionStatusProvider)
        .maybeWhen(data: (status) => status.isActive, orElse: () => false);
    final isWaiting = _isWaitingForSync(isSubscribed);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _message(isSubscribed),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: isWaiting
                  ? onRetry
                  : () => _openPurchasePage(context, ref),
              child: Text(_buttonLabel(isSubscribed)),
            ),
          ],
        ),
      ),
    );
  }
}
