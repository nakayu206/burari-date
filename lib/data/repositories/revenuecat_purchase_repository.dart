import '../../domain/entities/subscription.dart';
import '../../domain/repositories/purchase_repository.dart';
import '../datasources/cloud/anonymous_auth.dart';
import '../datasources/cloud/purchases_gateway.dart';

/// RevenueCatで、月額サブスクの案内・購入・復元を行う、本物の[PurchaseRepository]
/// (Issue #132)。
///
/// RevenueCatのユーザーには、FirebaseのUIDを使う(匿名から登録に変わっても、UIDは
/// 変わらないので、購入が引き継がれる)。ログアウトでUIDが変わったときは、次の操作の
/// 前に、付け替える。購読の状態の正は、サーバー(RevenueCatの通知で保存。#133)で、
/// ここで読む状態は、画面の表示に使う。
///
/// 公開APIキーが設定されていない間は、価格は既定の表示、状態は「購読していない」、
/// 購入は「課金の設定が、まだ済んでいません」と返す(プラン画面を、開けるようにする)。
class RevenueCatPurchaseRepository implements PurchaseRepository {
  RevenueCatPurchaseRepository({
    PurchasesGateway? gateway,
    Future<String> Function()? currentUid,
  }) : _gateway = gateway ?? RevenueCatGateway(),
       _currentUid = currentUid ?? AnonymousAuth.instance.ensureUid;

  final PurchasesGateway _gateway;
  final Future<String> Function() _currentUid;

  /// 設定が済む前に出す、既定の価格の表示。
  static const defaultPriceLabel = '月額300円';

  /// RevenueCatのユーザーを、いまのFirebaseのUIDにそろえる。
  Future<void> _prepare() async {
    final String uid;
    try {
      uid = await _currentUid();
    } catch (_) {
      throw const PurchaseException('サインインできませんでした。通信状況を確認して、もう一度お試しください。');
    }
    await _gateway.prepare(uid);
  }

  /// ゲートウェイの失敗を、利用者向けの文言の例外にする。
  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PurchasesGatewayException catch (e) {
      throw _exceptionOf(e.kind);
    } on PurchaseException {
      rethrow;
    } catch (_) {
      throw _exceptionOf(PurchaseFailureKind.other);
    }
  }

  static PurchaseException _exceptionOf(PurchaseFailureKind kind) {
    switch (kind) {
      case PurchaseFailureKind.cancelled:
        return const PurchaseCancelledException();
      case PurchaseFailureKind.network:
        return const PurchaseException('通信できませんでした。通信状況を確認して、もう一度お試しください。');
      case PurchaseFailureKind.notAllowed:
        return const PurchaseException('この端末では、購入できません。');
      case PurchaseFailureKind.store:
        return const PurchaseException('ストアに接続できませんでした。しばらくしてから、もう一度お試しください。');
      case PurchaseFailureKind.alreadyPurchased:
        return const PurchaseException('すでに購入済みです。「購入を復元する」をお試しください。');
      case PurchaseFailureKind.planNotFound:
        return const PurchaseException(
          '購入できるプランが見つかりませんでした。しばらくしてから、もう一度お試しください。',
        );
      case PurchaseFailureKind.other:
        return const PurchaseException('時間をおいて、もう一度お試しください。');
    }
  }

  /// 自動で更新されるときだけ、「次回の更新日」として、期限を渡す(解約済みで、期限で
  /// 終わるときに、更新と表示しないため)。
  static SubscriptionStatus _statusOf(EntitlementState state) {
    if (!state.isActive) return const SubscriptionStatus.inactive();
    return SubscriptionStatus.active(
      renewsOn: state.willRenew ? state.expiresAt : null,
    );
  }

  @override
  Future<PurchaseOffer> loadOffer() async {
    if (!_gateway.isAvailable) {
      return const PurchaseOffer(priceLabel: defaultPriceLabel);
    }
    return _run(() async {
      await _prepare();
      return PurchaseOffer(priceLabel: await _gateway.loadPriceLabel());
    });
  }

  @override
  Future<SubscriptionStatus> loadStatus() async {
    if (!_gateway.isAvailable) return const SubscriptionStatus.inactive();
    return _run(() async {
      await _prepare();
      return _statusOf(await _gateway.loadState());
    });
  }

  @override
  Future<SubscriptionStatus> purchase() async {
    if (!_gateway.isAvailable) {
      throw const PurchaseException('課金の設定が、まだ済んでいません。もうしばらくお待ちください。');
    }
    return _run(() async {
      await _prepare();
      return _statusOf(await _gateway.purchase());
    });
  }

  @override
  Future<SubscriptionStatus> restore() async {
    if (!_gateway.isAvailable) return const SubscriptionStatus.inactive();
    return _run(() async {
      await _prepare();
      return _statusOf(await _gateway.restore());
    });
  }
}
