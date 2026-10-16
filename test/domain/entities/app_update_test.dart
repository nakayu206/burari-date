import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/app_update.dart';

void main() {
  group('AppUpdate.isNewerThan', () {
    const update = AppUpdate(versionCode: 5, packageName: 'com.example');

    test('まだ案内していない(null)なら、案内する', () {
      expect(update.isNewerThan(null), isTrue);
    });

    test('案内済みより新しい更新なら、案内する', () {
      expect(update.isNewerThan(4), isTrue);
    });

    test('同じ更新は、繰り返し案内しない', () {
      expect(update.isNewerThan(5), isFalse);
    });

    test('案内済みより古い番号は、案内しない', () {
      expect(update.isNewerThan(6), isFalse);
    });
  });
}
