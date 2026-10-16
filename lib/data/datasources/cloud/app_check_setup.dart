import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/flavor.dart';

/// App Checkで使う、アプリの正当性の証明の方法の区分(Issue #222)。
enum AppCheckProviderKind {
  /// ストアから入れた本番のアプリ向け。Androidは、Google Play Integrity(Google Playが、
  /// 正規のアプリであることを保証する)。iOSは、DeviceCheck。
  production,

  /// デバッグ用。ストア以外から入れたアプリ(開発・テスト用)や、シミュレータでも、動かせる。
  /// 端末ごとのデバッグトークンを、Firebaseコンソールに登録して使う。
  debug,
}

/// 実行環境に合う証明の方法を選ぶ。
///
/// 本番向けの証明が使えるのは、ストアから入れた本番のアプリだけ。開発・テスト用の環境
/// (dev・stg)や、デバッグビルドでは、ストア以外から入れるため、デバッグ用にする。
/// 本番の環境で、デバッグ用を使うことは、リリースビルドでは、ない。
AppCheckProviderKind appCheckProviderKindFor(
  Flavor flavor, {
  required bool isDebugBuild,
}) {
  if (flavor == Flavor.prod && !isDebugBuild) {
    return AppCheckProviderKind.production;
  }
  return AppCheckProviderKind.debug;
}

/// App Checkを有効にする。有効にしたあと、Cloud Functionsの呼び出しには、自動で
/// 証明のトークンが付く。AndroidとiOSで、同じ区分のプロバイダーを使う。
///
/// 失敗しても、アプリの起動は止めない(呼び出し側で、例外を受け止める)。サーバーが
/// 必須にするまでは、トークンがなくても、動く。
Future<void> activateAppCheck(Flavor flavor) {
  final kind = appCheckProviderKindFor(flavor, isDebugBuild: kDebugMode);
  return FirebaseAppCheck.instance.activate(
    providerAndroid: switch (kind) {
      AppCheckProviderKind.production => const AndroidPlayIntegrityProvider(),
      AppCheckProviderKind.debug => const AndroidDebugProvider(),
    },
    providerApple: switch (kind) {
      AppCheckProviderKind.production => const AppleDeviceCheckProvider(),
      AppCheckProviderKind.debug => const AppleDebugProvider(),
    },
  );
}
