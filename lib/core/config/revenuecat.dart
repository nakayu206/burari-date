/// RevenueCat(課金サービス)の、Androidアプリ用の公開APIキー(Issue #132)。
///
/// RevenueCatのダッシュボードの、Android(Google Play)のアプリの設定にある、`goog_`
/// で始まるキー。アプリに入れてよい、公開用のキー(秘密のキー(Secret API key)では
/// ない。そちらは、バックエンドのSecretにだけ置く)。Google Playのデベロッパー
/// アカウントの確認と、RevenueCatへのアプリの追加が済んでから、設定する。
///
/// 空の間、リリースのビルドでは、課金を使えない扱いにする(プラン画面は開けるが、
/// 購入は「課金の設定が、まだ済んでいません」と案内する)。
const kRevenueCatAndroidApiKey = '';

/// RevenueCatの「Test Store」の公開APIキー(`test_`で始まる)。Google Playなしで、
/// 擬似的な購入を試すためのもの。公開用のキーで、秘密ではない。
///
/// **リリースのビルドでは、使ってはいけない**(RevenueCatのSDKが、アプリを落とす)。
/// [resolveRevenueCatApiKey]が、デバッグなどのビルドでだけ、使う。
const kRevenueCatTestStoreApiKey = 'test_qJoxtQIJwxINiebfBDTLgtXCMiL';

/// 月額プランの、RevenueCatのEntitlement(権利)のID。バックエンド
/// (`functions/src/subscription.ts`の`PREMIUM_ENTITLEMENT_ID`)と、同じにする。
/// RevenueCatのプロジェクトを作ったときに、自動で作られた名前。
const kPremiumEntitlementId = 'burari_date_pro';

/// ビルドの種類に応じて、使うRevenueCatのAPIキーを決める(Issue #132)。
///
/// - **リリースのビルド**: 本番のキーだけ。空なら、空(課金を使えない)。Test Storeの
///   キーは、リリースで使うとアプリが落ちるため、決して返さない。
/// - **デバッグなど、リリース以外のビルド**: Test Storeのキーがあれば、それ(Google Play
///   のアプリのパッケージ名が違うdev・stgでも、擬似的な購入を試せる)。なければ、本番のキー。
String resolveRevenueCatApiKey({
  required bool isReleaseMode,
  String production = kRevenueCatAndroidApiKey,
  String testStore = kRevenueCatTestStoreApiKey,
}) {
  if (isReleaseMode) return production;
  return testStore.isNotEmpty ? testStore : production;
}
