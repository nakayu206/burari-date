import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/core/config/revenuecat.dart';

void main() {
  group('resolveRevenueCatApiKey', () {
    test('リリースのビルドでは、Test Storeのキーを使わない(本番のキーだけ)', () {
      expect(
        resolveRevenueCatApiKey(
          isReleaseMode: true,
          production: 'goog_prod',
          testStore: 'test_key',
        ),
        'goog_prod',
      );
    });

    test('リリースで、本番のキーが空なら、空のまま(Test Storeに切り替えない)', () {
      expect(
        resolveRevenueCatApiKey(
          isReleaseMode: true,
          production: '',
          testStore: 'test_key',
        ),
        '',
      );
    });

    test('リリース以外では、Test Storeのキーがあれば、それを使う', () {
      expect(
        resolveRevenueCatApiKey(
          isReleaseMode: false,
          production: 'goog_prod',
          testStore: 'test_key',
        ),
        'test_key',
      );
    });

    test('リリース以外で、Test Storeのキーがなければ、本番のキーを使う', () {
      expect(
        resolveRevenueCatApiKey(
          isReleaseMode: false,
          production: 'goog_prod',
          testStore: '',
        ),
        'goog_prod',
      );
    });
  });

  test('Test Storeのキーは、Test Storeのものだとわかる形(test_で始まる)', () {
    expect(kRevenueCatTestStoreApiKey, startsWith('test_'));
  });

  test('本番のキーを設定するときは、Android用(goog_で始まる)にする', () {
    // 空の間は、リリースで、課金を使えない扱い。設定したあとは、Android用のキー。
    if (kRevenueCatAndroidApiKey.isNotEmpty) {
      expect(kRevenueCatAndroidApiKey, startsWith('goog_'));
    }
  });

  test('リリースで使う本番のキーに、Test Storeのキーを入れていない', () {
    expect(kRevenueCatAndroidApiKey, isNot(startsWith('test_')));
  });
}
