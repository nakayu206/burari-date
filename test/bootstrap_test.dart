import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/bootstrap.dart';
import 'package:burari_date/core/config/terms_version.dart';

void main() {
  group('signInIfConsented', () {
    test('現在の版に同意済みなら、起動時に匿名ログインする', () async {
      var signInCount = 0;
      await signInIfConsented(
        loadAcceptedVersion: () async => kTermsVersion,
        signIn: () async {
          signInCount++;
          return 'uid';
        },
      );
      expect(signInCount, 1);
    });

    test('まだ同意していなければ、ログインしない(IDを作らない)', () async {
      var signInCount = 0;
      await signInIfConsented(
        loadAcceptedVersion: () async => null,
        signIn: () async {
          signInCount++;
          return 'uid';
        },
      );
      expect(signInCount, 0);
    });

    test('古い版にしか同意していなければ、ログインしない', () async {
      var signInCount = 0;
      await signInIfConsented(
        loadAcceptedVersion: () async => kTermsVersion - 1,
        signIn: () async {
          signInCount++;
          return 'uid';
        },
      );
      expect(signInCount, 0);
    });
  });
}
