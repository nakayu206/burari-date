import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/core/config/flavor.dart';

void main() {
  group('AppConfig', () {
    tearDown(() => AppConfig.setFlavor(Flavor.dev));

    test('デフォルトのflavorはdev', () {
      expect(AppConfig.flavor, Flavor.dev);
      expect(AppConfig.appName, 'ぶらりデートガチャ Dev');
    });

    test('stg環境に切り替えるとflavorとappNameが変わる', () {
      AppConfig.setFlavor(Flavor.stg);
      expect(AppConfig.flavor, Flavor.stg);
      expect(AppConfig.appName, 'ぶらりデートガチャ Stg');
    });

    test('prod環境に切り替えるとflavorとappNameが変わる', () {
      AppConfig.setFlavor(Flavor.prod);
      expect(AppConfig.flavor, Flavor.prod);
      expect(AppConfig.appName, 'ぶらりデートガチャ');
    });
  });
}
