import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/app_update.dart';
import '../../domain/repositories/app_update_repository.dart';

/// Google Playの更新確認(In-App Updates API)で更新を調べ、案内済みのビルド番号を
/// 端末ローカル(SharedPreferences)に保存する。
class AppUpdateRepositoryImpl implements AppUpdateRepository {
  AppUpdateRepositoryImpl({
    Future<AppUpdateInfo> Function()? checkForUpdate,
    bool? isAndroid,
    Future<bool> Function(Uri uri)? launch,
  }) : _checkForUpdate = checkForUpdate ?? InAppUpdate.checkForUpdate,
       _isAndroid =
           isAndroid ?? defaultTargetPlatform == TargetPlatform.android,
       _launch =
           launch ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

  static const _kNotifiedVersion = 'update.notified.versionCode';

  final Future<AppUpdateInfo> Function() _checkForUpdate;
  final bool _isAndroid;
  final Future<bool> Function(Uri uri) _launch;

  /// Playの更新情報から、案内する更新を取り出す。更新がない・ビルド番号が分からない
  /// ときは、null。
  static AppUpdate? toAppUpdate(AppUpdateInfo info) {
    final versionCode = info.availableVersionCode;
    if (info.updateAvailability != UpdateAvailability.updateAvailable ||
        versionCode == null) {
      return null;
    }
    return AppUpdate(versionCode: versionCode, packageName: info.packageName);
  }

  @override
  Future<AppUpdate?> findAvailableUpdate() async {
    // 更新確認はAndroid(Google Play)だけ。iOSには、この仕組みがない。
    if (!_isAndroid) return null;
    try {
      return toAppUpdate(await _checkForUpdate());
    } catch (_) {
      // Google Play以外から入れた端末や、通信エラーでは、確認できない。案内を出せない
      // だけで、アプリの利用には影響しないため、黙って、更新なしとして扱う。
      return null;
    }
  }

  @override
  Future<int?> loadNotifiedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kNotifiedVersion);
  }

  @override
  Future<void> saveNotifiedVersion(int versionCode) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setInt(_kNotifiedVersion, versionCode);
    // 保存できていないと、次の起動で、同じ更新をまた案内してしまう。呼び出し元に伝える。
    if (!saved) throw StateError('案内済みの更新を保存できませんでした');
  }

  @override
  Future<void> openStorePage(AppUpdate update) async {
    final id = update.packageName;
    // Playストアのアプリで開く。開けない端末(ストアのアプリがない等)は、ブラウザで開く。
    try {
      if (await _launch(Uri.parse('market://details?id=$id'))) return;
    } catch (_) {}
    await _launch(
      Uri.parse('https://play.google.com/store/apps/details?id=$id'),
    );
  }
}
