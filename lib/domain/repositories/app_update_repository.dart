import '../entities/app_update.dart';

/// アプリの更新の確認と、案内済みの更新の記録(Issue #224)。
abstract interface class AppUpdateRepository {
  /// 更新できるバージョンを調べる。更新がない、確認できない(Google Play以外から入れた
  /// 端末、通信エラーなど)ときは、null。更新の確認の失敗は、案内を出せないだけで、
  /// アプリの利用を止めないため、例外にしない。
  Future<AppUpdate?> findAvailableUpdate();

  /// 案内済みのビルド番号。まだ案内していないときは、null。
  Future<int?> loadNotifiedVersion();

  /// [versionCode]の更新を案内したことを保存する。
  Future<void> saveNotifiedVersion(int versionCode);

  /// Google Playの、このアプリの商品ページを開く。更新の確定は、利用者がPlay側で行う。
  Future<void> openStorePage(AppUpdate update);
}
