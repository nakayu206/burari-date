import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:burari_date/core/config/terms_version.dart';
import 'package:burari_date/domain/repositories/consent_repository.dart';
import 'package:burari_date/presentation/providers/consent_providers.dart';

/// 保存だけ常に失敗させるリポジトリ。
class _FailingSaveRepository implements ConsentRepository {
  @override
  Future<int?> loadAcceptedVersion() async => null;

  @override
  Future<void> saveAcceptedVersion(int version) =>
      Future.error(StateError('save failed'));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('まだ同意していなければ、未同意', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(consentProvider.future), isFalse);
  });

  test('同意すると同意済みになり、作り直したContainerでも保持される', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(consentProvider.future);

    await container.read(consentProvider.notifier).accept();

    expect(container.read(consentProvider).value, isTrue);

    final reopened = ProviderContainer();
    addTearDown(reopened.dispose);
    expect(await reopened.read(consentProvider.future), isTrue);
  });

  test('現在の版に同意済みなら、同意済み', () async {
    SharedPreferences.setMockInitialValues({
      'consent.terms.version': kTermsVersion,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(consentProvider.future), isTrue);
  });

  test('規約が更新されて版が上がったら(古い版にしか同意していなければ)、未同意に戻る', () async {
    SharedPreferences.setMockInitialValues({
      'consent.terms.version': kTermsVersion - 1,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(consentProvider.future), isFalse);
  });

  test('保存に失敗したら、同意済みにせず、例外を伝える', () async {
    final container = ProviderContainer(
      overrides: [
        consentRepositoryProvider.overrideWithValue(_FailingSaveRepository()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(consentProvider.future);

    await expectLater(
      container.read(consentProvider.notifier).accept(),
      throwsStateError,
    );

    expect(container.read(consentProvider).value, isFalse);
  });

  test('規約の版は、1以上の番号', () {
    expect(kTermsVersion, greaterThanOrEqualTo(1));
  });
}
