import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/data/datasources/cloud/anonymous_auth.dart';

void main() {
  test('ログイン済みなら、ログインし直さずにそのUIDを返す', () async {
    var signInCount = 0;
    final auth = AnonymousAuth(
      currentUid: () => 'uid-1',
      signIn: () async {
        signInCount++;
        return 'uid-2';
      },
    );

    expect(await auth.ensureUid(), 'uid-1');
    expect(signInCount, 0);
  });

  test('まだログインしていなければ、その場で匿名ログインしてUIDを返す', () async {
    final auth = AnonymousAuth(
      currentUid: () => null,
      signIn: () async => 'uid-2',
    );

    expect(await auth.ensureUid(), 'uid-2');
  });

  test('起動時のログインに失敗しても、通信が戻ったあとの呼び出しでやり直せる', () async {
    var isOnline = false;
    String? uid;
    final auth = AnonymousAuth(
      currentUid: () => uid,
      signIn: () async {
        if (!isOnline) throw Exception('network');
        return uid = 'uid-1';
      },
    );

    await expectLater(auth.ensureUid(), throwsException);

    isOnline = true;
    expect(await auth.ensureUid(), 'uid-1');
  });

  test('ログイン中に呼び出しが重なっても、ログインは1回だけ', () async {
    var signInCount = 0;
    final auth = AnonymousAuth(
      currentUid: () => null,
      signIn: () async {
        signInCount++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 'uid-1';
      },
    );

    final results = await Future.wait([auth.ensureUid(), auth.ensureUid()]);

    expect(results, ['uid-1', 'uid-1']);
    expect(signInCount, 1);
  });
}
