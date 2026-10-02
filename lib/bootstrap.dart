import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/flavor.dart';
import 'core/config/terms_version.dart';
import 'data/datasources/cloud/anonymous_auth.dart';
import 'data/repositories/consent_repository_impl.dart';
import 'firebase_options.dart';

/// 各Flavorのエントリーポイント(main_dev/main_stg/main_prod)から呼び出す
/// 共通の起動処理。
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.setFlavor(flavor);
  await _initializeFirebase();
  runApp(const ProviderScope(child: BurariDateApp()));
}

Future<void> _initializeFirebase() async {
  final isSupported =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (!isSupported) return;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await signInIfConsented(
      loadAcceptedVersion: ConsentRepositoryImpl().loadAcceptedVersion,
      signIn: AnonymousAuth.instance.ensureUid,
    );
  } catch (e) {
    debugPrint('Firebase初期化に失敗しました: $e');
  }
}

/// 起動時の匿名ログイン。現在の規約の版に同意済みのときだけ行う(Issue #117)。
/// 同意の前は、ユーザーのIDを作らない。初めての起動では、同意したあとに、同意画面の
/// 処理(ConsentNotifier.accept)がログインする。
@visibleForTesting
Future<void> signInIfConsented({
  required Future<int?> Function() loadAcceptedVersion,
  required Future<Object?> Function() signIn,
}) async {
  if (await loadAcceptedVersion() == kTermsVersion) await signIn();
}
