import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/flavor.dart';
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
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (e) {
    debugPrint('Firebase初期化に失敗しました: $e');
  }
}
