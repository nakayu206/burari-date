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
  const SubscriptionStatus.inactive()
    : isActive = false,
      renewsOn = null,
      endsOn = null;

  /// 購読中の状態。
  ///
  /// - [renewsOn]: 自動で更新されるときの、次回の更新日(その日に、次の1か月分の料金が
  ///   かかる)。
  /// - [endsOn]: 解約済みで、更新されず、この日で終わるときの、終わる日(有効期限)。
  ///
  /// どちらも、分からないときは、null。両方が入ることは、ない。
  const SubscriptionStatus.active({this.renewsOn, this.endsOn})
    : assert(renewsOn == null || endsOn == null),
      isActive = true;

  final bool isActive;
  final DateTime? renewsOn;
  final DateTime? endsOn;

  @override
  bool operator ==(Object other) =>
      other is SubscriptionStatus &&
      other.isActive == isActive &&
      other.renewsOn == renewsOn &&
      other.endsOn == endsOn;

  @override
  int get hashCode => Object.hash(isActive, renewsOn, endsOn);
}
