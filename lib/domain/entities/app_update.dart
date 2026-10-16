/// Google Playに出ている、いまのアプリより新しいバージョン(Issue #224)。
class AppUpdate {
  const AppUpdate({required this.versionCode, required this.packageName});

  /// 更新できるバージョンのビルド番号(`pubspec.yaml`の`+`の後ろ)。
  final int versionCode;

  /// Google Playの商品ページを開くための、アプリのパッケージ名。
  final String packageName;

  /// [notifiedVersionCode](案内済みのビルド番号)より新しく、まだ案内していない更新か。
  /// 案内したことがない(null)なら、案内する。同じ更新は、繰り返し案内しない。
  bool isNewerThan(int? notifiedVersionCode) =>
      notifiedVersionCode == null || versionCode > notifiedVersionCode;
}
