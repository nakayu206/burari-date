import '../entities/subscription.dart';

/// 購入・復元に失敗した理由を、利用者向けの文言で持つ例外。
///
/// [toString]も文言だけを返し、「Exception:」などの内部用の表記が画面に出ない
/// ようにしている。
class PurchaseException implements Exception {
  const PurchaseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 利用者が、購入の途中で取りやめたことを表す例外。失敗ではないので、画面は、
/// エラーを出さない。
class PurchaseCancelledException extends PurchaseException {
  const PurchaseCancelledException() : super('キャンセルしました');
}

/// 月額サブスクの案内・購入・復元(Issue #131・#132)。
abstract class PurchaseRepository {
  /// 購入できるプランの案内(価格など)。
  Future<PurchaseOffer> loadOffer();

  /// いまの購読の状態。
  Future<SubscriptionStatus> loadStatus();

  /// 購読の状態を、ストアの最新に、取り直す(保存してある状態を使わない)。Google Playの
  /// 「定期購入」で、解約・更新された、アプリの外の変更を、反映するために使う。
  /// 失敗したときは[PurchaseException]を投げる。
  Future<SubscriptionStatus> refreshStatus();

  /// 月額サブスクを購入する。購入後の状態を返す。取りやめたときは
  /// [PurchaseCancelledException]、失敗したときは[PurchaseException]を投げる。
  Future<SubscriptionStatus> purchase();

  /// 過去の購入を復元する(別の端末・再インストール用)。復元できる購入がなければ、
  /// 購読していない状態を返す。失敗したときは[PurchaseException]を投げる。
  Future<SubscriptionStatus> restore();
}
