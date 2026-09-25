/// アプリの実行環境(Flavor)
enum Flavor {
  /// 開発環境
  dev,

  /// テスト・ステージング環境
  stg,

  /// 本番(リリース)環境
  prod,
}

/// 実行中の環境に応じた設定値を提供する。
///
/// エントリーポイント(main_dev / main_stg / main_prod)で
/// [AppConfig.setFlavor]を設定してから[runApp]を呼び出すこと。
abstract class AppConfig {
  static Flavor _flavor = Flavor.dev;

  /// 現在の実行環境
  static Flavor get flavor => _flavor;

  /// エントリーポイントから一度だけ呼び出す
  static void setFlavor(Flavor flavor) {
    _flavor = flavor;
  }

  /// 画面に表示するアプリ名
  static String get appName {
    switch (_flavor) {
      case Flavor.dev:
        return 'ぶらりデートガチャ Dev';
      case Flavor.stg:
        return 'ぶらりデートガチャ Stg';
      case Flavor.prod:
        return 'ぶらりデートガチャ';
    }
  }
}
