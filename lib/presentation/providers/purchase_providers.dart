import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/revenuecat_purchase_repository.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/repositories/purchase_repository.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  return RevenueCatPurchaseRepository();
});

/// 購入できるプランの案内(価格など)。
final purchaseOfferProvider = FutureProvider<PurchaseOffer>((ref) {
  return ref.read(purchaseRepositoryProvider).loadOffer();
});

/// 月額サブスクの状態(購読中か)。購入・復元に追従する。
///
/// 購入・復元に失敗したときは、状態を変えず、例外を呼び出し元(画面)へ伝える
/// (画面でダイアログを出す)。
class SubscriptionNotifier extends AsyncNotifier<SubscriptionStatus> {
  @override
  Future<SubscriptionStatus> build() {
    return ref.read(purchaseRepositoryProvider).loadStatus();
  }

  /// 購読の状態を、ストアの最新に、取り直す。Google Playの「定期購入」で、解約・更新
  /// されたあとの表示を、そろえるため。読み込み中の表示には戻さず、いまの表示のまま、
  /// 静かに更新する。取り直しに失敗したときは、いまの表示を残す(エラーにしない)。
  Future<void> refresh() async {
    try {
      final status = await ref.read(purchaseRepositoryProvider).refreshStatus();
      state = AsyncData(status);
    } catch (_) {
      // いまの表示を残す。
    }
  }

  /// 購入する。購入後の状態を返す。
  Future<SubscriptionStatus> purchase() async {
    final status = await ref.read(purchaseRepositoryProvider).purchase();
    state = AsyncData(status);
    return status;
  }

  /// 過去の購入を復元する。復元後の状態を返す。
  Future<SubscriptionStatus> restore() async {
    final status = await ref.read(purchaseRepositoryProvider).restore();
    state = AsyncData(status);
    return status;
  }
}

final subscriptionStatusProvider =
    AsyncNotifierProvider<SubscriptionNotifier, SubscriptionStatus>(
      SubscriptionNotifier.new,
    );
