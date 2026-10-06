import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/entities/subscription.dart';
import '../../../domain/repositories/purchase_repository.dart';
import '../../providers/auth_providers.dart';
import '../../providers/purchase_providers.dart';
import 'account_page.dart';

/// launchUrlと同じ形の関数型。実機では実際のurl_launcher.launchUrlを使うが、
/// テストでは実プラットフォーム呼び出し(ストアアプリの起動)を避けるため差し替える。
typedef SubscriptionUrlLauncher =
    Future<bool> Function(Uri url, {LaunchMode mode});

/// Google Playの「定期購入」の画面。解約・支払い方法の変更は、ここから行う。
/// いまはAndroidのみ。iOSに出すときは、App Storeの定期購入の画面に切り替える。
final kManageSubscriptionsUrl = Uri.parse(
  'https://play.google.com/store/account/subscriptions',
);

/// プラン(月額サブスク)の画面(Issue #131)。
///
/// プランの案内と、購入・購入の復元を出す。購入は、アカウントの登録が済んでから
/// (購入を、アカウントに紐づけるため)。購読中のときは、状態と次回の更新日を出す。
/// 購入・復元の処理は[PurchaseRepository]に任せる。
class PurchasePage extends ConsumerStatefulWidget {
  const PurchasePage({
    super.key,
    @visibleForTesting this.launchUrlOverride = launchUrl,
  });

  final SubscriptionUrlLauncher launchUrlOverride;

  @override
  ConsumerState<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends ConsumerState<PurchasePage>
    with WidgetsBindingObserver {
  /// 購入・復元の処理中は、ボタンを押せなくする。
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 画面を開き直したときに、前に取得した状態(解約・更新の前のもの)を、そのまま
    // 出さないよう、最新に取り直す。初めて開くときは、読み込みが、これから走るので、
    // 取り直さない。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(subscriptionStatusProvider).hasValue) _refreshStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// アプリに戻ってきたとき(Google Playの「定期購入」の画面で、解約した・支払い方法を
  /// 変えたあとなど)に、購読の状態を、最新に取り直す。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshStatus();
  }

  void _refreshStatus() {
    ref.read(subscriptionStatusProvider.notifier).refresh();
  }

  Future<void> _purchase() async {
    await _run(
      errorTitle: 'ご購入を完了できませんでした',
      action: () => ref.read(subscriptionStatusProvider.notifier).purchase(),
      onDone: (status) => status.isActive
          ? _showInfo('ご購入ありがとうございます', 'プランをご利用いただけます。')
          : Future<void>.value(),
    );
  }

  Future<void> _restore() async {
    await _run(
      errorTitle: '購入を復元できませんでした',
      action: () => ref.read(subscriptionStatusProvider.notifier).restore(),
      onDone: (status) => status.isActive
          ? _showInfo('購入を復元しました', 'プランをご利用いただけます。')
          : _showInfo('復元できる購入がありません', 'この端末のアカウントでは、購入の履歴が見つかりませんでした。'),
    );
  }

  Future<void> _run({
    required String errorTitle,
    required Future<SubscriptionStatus> Function() action,
    required Future<void> Function(SubscriptionStatus status) onDone,
  }) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    SubscriptionStatus? status;
    String? errorMessage;
    try {
      status = await action();
    } on PurchaseCancelledException {
      // 利用者が取りやめただけなので、何も出さない。
    } on PurchaseException catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = '時間をおいて、もう一度お試しください。';
    }
    if (!mounted) return;
    // ダイアログの裏で、進行中の表示が回り続けないよう、処理中の状態を先に戻す。
    // ダイアログは画面全体を覆うので、この間に、もう一度押されることはない。
    setState(() => _isBusy = false);
    if (errorMessage != null) {
      await _showInfo(errorTitle, errorMessage);
    } else if (status != null) {
      await onDone(status);
    }
  }

  /// Google Playの「定期購入」の画面を開く(解約・支払い方法の変更のため)。
  Future<void> _manageSubscription() async {
    bool launched;
    try {
      launched = await widget.launchUrlOverride(
        kManageSubscriptionsUrl,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }
    if (launched || !mounted) return;
    await _showInfo('Google Playを開けませんでした', 'Google Playアプリの「定期購入」から、ご確認ください。');
  }

  Future<void> _showInfo(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _reload() {
    ref.invalidate(purchaseOfferProvider);
    ref.invalidate(subscriptionStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final offer = ref.watch(purchaseOfferProvider);
    final status = ref.watch(subscriptionStatusProvider);
    final hasAccount = ref.watch(hasAccountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('プラン')),
      body: SafeArea(
        child: offer.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _LoadError(onRetry: _reload),
          data: (offer) => status.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _LoadError(onRetry: _reload),
            data: (subscription) => ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                _PlanCard(
                  offer: offer,
                  // 自動更新と解約の案内は、購入の前だけ。購読中は、状態の表示(更新日・
                  // 有効期限)と、管理のボタンがあり、解約済みの画面で、「自動で更新
                  // されます」と、矛盾して出ないようにする。
                  showRenewalNotice: !subscription.isActive,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (subscription.isActive)
                  _ActiveBody(
                    subscription: subscription,
                    onManage: _manageSubscription,
                  )
                else if (!hasAccount)
                  const _NeedsAccountBody()
                else
                  _PurchaseBody(
                    offer: offer,
                    isBusy: _isBusy,
                    onPurchase: _purchase,
                    onRestore: _restore,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// プランの案内。
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.offer, required this.showRenewalNotice});

  final PurchaseOffer offer;

  /// 自動更新と解約のしかたの案内を出すか(購入の前だけ)。
  final bool showRenewalNotice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.secondary, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            offer.priceLabel,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: AppFontSizes.displayLarge * 0.7,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'ガチャを、使い放題でお楽しみいただけます。',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppFontSizes.bodyLarge,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            '過度な連続利用など、運営者が不適切と判断した利用があった場合は、'
            '利用規約にもとづき、機能を制限することがあります。',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSizes.labelSmall,
              height: 1.6,
            ),
          ),
          if (showRenewalNotice) ...[
            const SizedBox(height: AppSpacing.md),
            // 定期購入の、期間・自動更新・解約のしかたを、購入の前に、はっきり伝える。
            const Text(
              '毎月、自動で更新されます。次回の更新日の前までに解約しないと、'
              '次の1か月分の料金がかかります。\n'
              '解約は、Google Playの「定期購入」から、いつでもできます'
              '(アプリの中からは、解約できません)。',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.labelSmall,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 購入できるときの、購入・復元のボタン。
class _PurchaseBody extends StatelessWidget {
  const _PurchaseBody({
    required this.offer,
    required this.isBusy,
    required this.onPurchase,
    required this.onRestore,
  });

  final PurchaseOffer offer;
  final bool isBusy;
  final VoidCallback onPurchase;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: isBusy ? null : onPurchase,
          child: isBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('${offer.priceLabel}で購入する'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: isBusy ? null : onRestore,
          child: const Text('購入を復元する'),
        ),
      ],
    );
  }
}

/// アカウントが未登録のとき。購入は、アカウントに紐づけるため、先に登録してもらう。
class _NeedsAccountBody extends StatelessWidget {
  const _NeedsAccountBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BodyText('ご購入には、アカウントの登録が必要です。'),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AccountPage())),
          child: const Text('アカウントを登録する'),
        ),
      ],
    );
  }
}

/// 購読中のとき。
class _ActiveBody extends StatelessWidget {
  const _ActiveBody({required this.subscription, required this.onManage});

  final SubscriptionStatus subscription;
  final VoidCallback onManage;

  static String _dateText(DateTime date) =>
      '${date.year}年${date.month}月${date.day}日';

  @override
  Widget build(BuildContext context) {
    final renewsOn = subscription.renewsOn;
    final endsOn = subscription.endsOn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ご利用中のプランです',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: AppFontSizes.bodyLarge,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (renewsOn != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _BodyText('次回の更新日: ${_dateText(renewsOn)}(自動で更新されます)'),
        ] else if (endsOn != null) ...[
          // 解約済みで、更新されない。更新と、誤解させない。
          const SizedBox(height: AppSpacing.xs),
          _BodyText('有効期限: ${_dateText(endsOn)}(自動では更新されません)'),
        ],
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton(
          onPressed: onManage,
          child: const Text('定期購入を管理する(解約など)'),
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BodyText('プランの情報を取得できませんでした。'),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('もう一度読み込む')),
          ],
        ),
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  const _BodyText(this.text);

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
