import '../../domain/entities/subscription.dart';
import '../../domain/repositories/purchase_repository.dart';

/// アプリ内課金の処理ができるまでの、仮の実装(Issue #131)。常に購読していない
/// 状態として扱い、購入は「まだ使えない」と返す。実際の購入(ストアの課金)は
/// Issue #132で作り、この実装は、そのとき、置き換える。
class PlaceholderPurchaseRepository implements PurchaseRepository {
  const PlaceholderPurchaseRepository();

  @override
  Future<PurchaseOffer> loadOffer() async =>
      const PurchaseOffer(priceLabel: '月額300円');

  @override
  Future<SubscriptionStatus> loadStatus() async =>
      const SubscriptionStatus.inactive();

  @override
  Future<SubscriptionStatus> purchase() async {
    throw const PurchaseException('購入は、まだ使えません。もうしばらくお待ちください。');
  }

  @override
  Future<SubscriptionStatus> restore() async =>
      const SubscriptionStatus.inactive();
}
