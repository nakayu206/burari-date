import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/config/revenuecat.dart';

/// 購入が、うまくいかなかった理由の種類(Issue #132)。画面に出す文言は、リポジトリが、
/// この種類から作る。
enum PurchaseFailureKind {
  /// 利用者が、取りやめた。
  cancelled,

  /// 通信できなかった。
  network,

  /// この端末・このアカウントでは、購入できない。
  notAllowed,

  /// ストアに、問題があった(接続できない、商品が使えないなど)。
  store,

  /// すでに購入済み(購入の復元で、使えるようにできる)。
  alreadyPurchased,

  /// 購入できるプランが、見つからなかった(RevenueCatの設定の途中など)。
  planNotFound,

  /// そのほか。
  other,
}

/// ゲートウェイが投げる例外。
class PurchasesGatewayException implements Exception {
  const PurchasesGatewayException(this.kind);

  final PurchaseFailureKind kind;

  @override
  String toString() => 'PurchasesGatewayException($kind)';
}

/// 月額プランの権利の状態。
class EntitlementState {
  const EntitlementState({
    required this.isActive,
    this.expiresAt,
    this.willRenew = false,
  });

  const EntitlementState.inactive() : this(isActive: false);

  final bool isActive;

  /// 期限(分からない・期限がないときはnull)。
  final DateTime? expiresAt;

  /// 自動で更新されるか(解約していれば、false)。
  final bool willRenew;
}

/// RevenueCatのSDK(`purchases_flutter`)の操作(Issue #132)。
///
/// 本物([RevenueCatGateway])は、実機のストアにつながる。テストでは偽物に差し替え、
/// 実際の購入を行わずに、リポジトリの流れと、失敗の扱いを確かめる。
abstract class PurchasesGateway {
  /// 課金を使える状態か(公開APIキーが設定済みで、対応している端末か)。
  bool get isAvailable;

  /// SDKを準備し、RevenueCatのユーザーを[uid](FirebaseのUID)にする。すでに同じ
  /// ユーザーなら、何もしない。ログアウトなどで、UIDが変わったときは、付け替える。
  Future<void> prepare(String uid);

  /// 画面に出す、プランの価格(例: 月額￥300)。
  Future<String> loadPriceLabel();

  /// いまの権利の状態。
  Future<EntitlementState> loadState();

  /// 保存してある状態(SDKのキャッシュ)を捨てて、最新の権利の状態を、取り直す。
  /// Google Playの「定期購入」で、解約・更新されたなど、アプリの外の変更を、反映する。
  Future<EntitlementState> refreshState();

  /// 月額プランを購入する。購入後の権利の状態を返す。
  Future<EntitlementState> purchase();

  /// 過去の購入を復元する。復元後の権利の状態を返す。
  Future<EntitlementState> restore();
}

/// `purchases_flutter`を使う、本物の[PurchasesGateway]。
class RevenueCatGateway implements PurchasesGateway {
  RevenueCatGateway({String? apiKey})
    : apiKey = apiKey ?? resolveRevenueCatApiKey(isReleaseMode: kReleaseMode);

  /// RevenueCatの公開APIキー。リリースのビルドでは、本番のキーだけ(Test Storeの
  /// キーは、リリースで使うとアプリが落ちるため、使わない)。
  final String apiKey;

  bool _isConfigured = false;

  @override
  bool get isAvailable =>
      apiKey.isNotEmpty &&
      !kIsWeb &&
      // いまはAndroidのみ。iOSに出すときに、iOS用のキーと一緒に、足す。
      defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> prepare(String uid) => _guard(() async {
    if (!_isConfigured) {
      if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);
      // 最初から、FirebaseのUIDで準備する(RevenueCatの匿名ユーザーを作らない)。
      await Purchases.configure(
        PurchasesConfiguration(apiKey)..appUserID = uid,
      );
      _isConfigured = true;
      return;
    }
    if (await Purchases.appUserID != uid) await Purchases.logIn(uid);
  });

  Future<Package> _monthlyPackage() async {
    final offering = (await Purchases.getOfferings()).current;
    final package =
        offering?.monthly ??
        (offering != null && offering.availablePackages.isNotEmpty
            ? offering.availablePackages.first
            : null);
    if (package == null) {
      throw const PurchasesGatewayException(PurchaseFailureKind.planNotFound);
    }
    return package;
  }

  @override
  Future<String> loadPriceLabel() => _guard(() async {
    final package = await _monthlyPackage();
    return '月額${package.storeProduct.priceString}';
  });

  @override
  Future<EntitlementState> loadState() => _guard(() async {
    return _stateOf(await Purchases.getCustomerInfo());
  });

  @override
  Future<EntitlementState> refreshState() => _guard(() async {
    await Purchases.invalidateCustomerInfoCache();
    return _stateOf(await Purchases.getCustomerInfo());
  });

  @override
  Future<EntitlementState> purchase() => _guard(() async {
    final package = await _monthlyPackage();
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return _stateOf(result.customerInfo);
  });

  @override
  Future<EntitlementState> restore() => _guard(() async {
    return _stateOf(await Purchases.restorePurchases());
  });

  static EntitlementState _stateOf(CustomerInfo info) {
    final entitlement = info.entitlements.active[kPremiumEntitlementId];
    if (entitlement == null) return const EntitlementState.inactive();
    return EntitlementState(
      isActive: true,
      expiresAt: DateTime.tryParse(entitlement.expirationDate ?? '')?.toLocal(),
      willRenew: entitlement.willRenew,
    );
  }

  /// SDKのエラーを、[PurchasesGatewayException]にそろえる。
  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PurchasesGatewayException {
      rethrow;
    } on PlatformException catch (e) {
      throw PurchasesGatewayException(
        _kindOf(PurchasesErrorHelper.getErrorCode(e)),
      );
    }
  }

  static PurchaseFailureKind _kindOf(PurchasesErrorCode code) {
    switch (code) {
      case PurchasesErrorCode.purchaseCancelledError:
        return PurchaseFailureKind.cancelled;
      case PurchasesErrorCode.networkError:
      case PurchasesErrorCode.offlineConnectionError:
        return PurchaseFailureKind.network;
      case PurchasesErrorCode.purchaseNotAllowedError:
        return PurchaseFailureKind.notAllowed;
      case PurchasesErrorCode.storeProblemError:
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        return PurchaseFailureKind.store;
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return PurchaseFailureKind.alreadyPurchased;
      default:
        return PurchaseFailureKind.other;
    }
  }
}
