/// 購入できるプランの案内(Issue #131)。価格は、ストアから受け取った表示用の文字列
/// (通貨や端数が、国ごとに違うため)。
class PurchaseOffer {
  const PurchaseOffer({required this.priceLabel});

  /// 画面に出す価格。例: 月額300円。
  final String priceLabel;
}

/// 月額サブスクの状態(Issue #131)。
class SubscriptionStatus {
  /// 購読していない状態。
  const SubscriptionStatus.inactive() : isActive = false, renewsOn = null;

  /// 購読中の状態。[renewsOn]は、次回の更新日(分からないときはnull)。
  const SubscriptionStatus.active({this.renewsOn}) : isActive = true;

  final bool isActive;
  final DateTime? renewsOn;

  @override
  bool operator ==(Object other) =>
      other is SubscriptionStatus &&
      other.isActive == isActive &&
      other.renewsOn == renewsOn;

  @override
  int get hashCode => Object.hash(isActive, renewsOn);
}
