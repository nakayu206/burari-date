import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/placeholder_purchase_repository.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/repositories/purchase_repository.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  return const PlaceholderPurchaseRepository();
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
