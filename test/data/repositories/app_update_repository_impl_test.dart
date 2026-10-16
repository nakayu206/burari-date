import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:burari_date/data/repositories/app_update_repository_impl.dart';
import 'package:burari_date/domain/entities/app_update.dart';

AppUpdateInfo _info({
  UpdateAvailability availability = UpdateAvailability.updateAvailable,
  int? versionCode = 5,
}) {
  return AppUpdateInfo(
    updateAvailability: availability,
    immediateUpdateAllowed: true,
    immediateAllowedPreconditions: null,
    flexibleUpdateAllowed: true,
    flexibleAllowedPreconditions: null,
    availableVersionCode: versionCode,
    installStatus: InstallStatus.unknown,
    packageName: 'com.buraridate.burari_date',
    clientVersionStalenessDays: null,
    updatePriority: 0,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AppUpdateRepositoryImpl', () {
    group('toAppUpdate', () {
      test('更新があるときは、ビルド番号とパッケージ名を取り出す', () {
        final update = AppUpdateRepositoryImpl.toAppUpdate(_info());

        expect(update!.versionCode, 5);
        expect(update.packageName, 'com.buraridate.burari_date');
      });

      test('更新がない・不明なときは、null', () {
        for (final availability in [
          UpdateAvailability.updateNotAvailable,
          UpdateAvailability.unknown,
          UpdateAvailability.developerTriggeredUpdateInProgress,
        ]) {
          expect(
            AppUpdateRepositoryImpl.toAppUpdate(
              _info(availability: availability),
            ),
            isNull,
          );
        }
      });

      test('ビルド番号が分からないときは、null(案内済みの比較ができないため)', () {
        expect(
          AppUpdateRepositoryImpl.toAppUpdate(_info(versionCode: null)),
          isNull,
        );
      });
    });

    group('findAvailableUpdate', () {
      test('Playに更新があれば、その更新を返す', () async {
        final repository = AppUpdateRepositoryImpl(
          checkForUpdate: () async => _info(versionCode: 7),
          isAndroid: true,
        );

        expect((await repository.findAvailableUpdate())!.versionCode, 7);
      });

      test('確認に失敗したときは、例外にせず、更新なしとして扱う', () async {
        final repository = AppUpdateRepositoryImpl(
          checkForUpdate: () async => throw Exception('not from Play'),
          isAndroid: true,
        );

        expect(await repository.findAvailableUpdate(), isNull);
      });

      test('Android以外では、Playに問い合わせない', () async {
        var called = false;
        final repository = AppUpdateRepositoryImpl(
          checkForUpdate: () async {
            called = true;
            return _info();
          },
          isAndroid: false,
        );

        expect(await repository.findAvailableUpdate(), isNull);
        expect(called, isFalse);
      });
    });

    group('案内済みのビルド番号', () {
      test('保存するまでは、null', () async {
        expect(await AppUpdateRepositoryImpl().loadNotifiedVersion(), isNull);
      });

      test('保存した番号を、読み込める', () async {
        final repository = AppUpdateRepositoryImpl();

        await repository.saveNotifiedVersion(5);

        expect(await repository.loadNotifiedVersion(), 5);
      });
    });

    group('openStorePage', () {
      const update = AppUpdate(
        versionCode: 5,
        packageName: 'com.buraridate.burari_date',
      );

      test('Playストアのアプリで、商品ページを開く', () async {
        final opened = <Uri>[];
        final repository = AppUpdateRepositoryImpl(
          launch: (uri) async {
            opened.add(uri);
            return true;
          },
        );

        await repository.openStorePage(update);

        expect(opened.map((u) => u.toString()), [
          'market://details?id=com.buraridate.burari_date',
        ]);
      });

      test('ストアのアプリで開けなければ、ブラウザで開く', () async {
        final opened = <Uri>[];
        final repository = AppUpdateRepositoryImpl(
          launch: (uri) async {
            opened.add(uri);
            return uri.scheme == 'https';
          },
        );

        await repository.openStorePage(update);

        expect(opened.last.toString(), startsWith('https://play.google.com/'));
        expect(opened.length, 2);
      });

      test('ストアのアプリを開く処理が例外でも、ブラウザで開く', () async {
        final opened = <Uri>[];
        final repository = AppUpdateRepositoryImpl(
          launch: (uri) async {
            opened.add(uri);
            if (uri.scheme == 'market') throw Exception('no handler');
            return true;
          },
        );

        await repository.openStorePage(update);

        expect(opened.last.scheme, 'https');
      });
    });
  });
}
