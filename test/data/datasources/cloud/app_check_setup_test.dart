import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/core/config/flavor.dart';
import 'package:burari_date/data/datasources/cloud/app_check_setup.dart';

void main() {
  group('appCheckProviderKindFor', () {
    test('本番のリリースビルドだけ、Play Integrityを使う', () {
      expect(
        appCheckProviderKindFor(Flavor.prod, isDebugBuild: false),
        AppCheckProviderKind.playIntegrity,
      );
    });

    test('本番でも、デバッグビルドは、デバッグ用を使う', () {
      expect(
        appCheckProviderKindFor(Flavor.prod, isDebugBuild: true),
        AppCheckProviderKind.debug,
      );
    });

    test('dev・stgは、Play以外から入れるため、リリースビルドでも、デバッグ用を使う', () {
      for (final flavor in [Flavor.dev, Flavor.stg]) {
        expect(
          appCheckProviderKindFor(flavor, isDebugBuild: false),
          AppCheckProviderKind.debug,
        );
      }
    });
  });
}
