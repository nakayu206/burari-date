import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:burari_date/data/repositories/consent_repository_impl.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('まだ同意していなければ、nullを返す', () async {
    expect(await ConsentRepositoryImpl().loadAcceptedVersion(), isNull);
  });

  test('同意した版を保存して、読み込める', () async {
    await ConsentRepositoryImpl().saveAcceptedVersion(1);

    expect(await ConsentRepositoryImpl().loadAcceptedVersion(), 1);
  });

  test('新しい版に同意すると、保存した版が新しい番号になる', () async {
    final repository = ConsentRepositoryImpl();
    await repository.saveAcceptedVersion(1);
    await repository.saveAcceptedVersion(2);

    expect(await repository.loadAcceptedVersion(), 2);
  });
}
