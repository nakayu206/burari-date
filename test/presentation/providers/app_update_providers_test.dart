import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/app_update.dart';
import 'package:burari_date/domain/repositories/app_update_repository.dart';
import 'package:burari_date/presentation/providers/app_update_providers.dart';

/// 更新と案内済みの番号を、指定するだけのリポジトリ。
class FakeAppUpdateRepository implements AppUpdateRepository {
  FakeAppUpdateRepository({
    this.update,
    this.notified,
    this.failsToLoadNotified = false,
  });

  final AppUpdate? update;
  int? notified;
  final bool failsToLoadNotified;
  final opened = <AppUpdate>[];

  @override
  Future<AppUpdate?> findAvailableUpdate() async => update;

  @override
  Future<int?> loadNotifiedVersion() async {
    if (failsToLoadNotified) throw StateError('load failed');
    return notified;
  }

  @override
  Future<void> saveNotifiedVersion(int versionCode) async {
    notified = versionCode;
  }

  @override
  Future<void> openStorePage(AppUpdate update) async => opened.add(update);
}

void main() {
  const update = AppUpdate(versionCode: 5, packageName: 'com.example');

  Future<AppUpdate?> read(FakeAppUpdateRepository repository) {
    final container = ProviderContainer(
      overrides: [appUpdateRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container.read(updateToNotifyProvider.future);
  }

  group('updateToNotifyProvider', () {
    test('更新がなければ、案内しない', () async {
      expect(await read(FakeAppUpdateRepository()), isNull);
    });

    test('まだ案内していない更新は、案内する', () async {
      expect(await read(FakeAppUpdateRepository(update: update)), update);
    });

    test('案内済みの更新は、案内しない(同じ更新で繰り返さない)', () async {
      expect(
        await read(FakeAppUpdateRepository(update: update, notified: 5)),
        isNull,
      );
    });

    test('次の更新(より新しい番号)は、また案内する', () async {
      expect(
        await read(FakeAppUpdateRepository(update: update, notified: 4)),
        update,
      );
    });

    test('案内済みの番号を読めないときは、案内しない', () async {
      expect(
        await read(
          FakeAppUpdateRepository(update: update, failsToLoadNotified: true),
        ),
        isNull,
      );
    });
  });
}
