import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:burari_date/data/datasources/cloud/account_auth.dart';
import 'package:burari_date/data/repositories/firebase_account_repository.dart';
import 'package:burari_date/domain/entities/account_status.dart';
import 'package:burari_date/domain/repositories/account_repository.dart';

/// 実際のログインを行わず、呼ばれた順番を記録する偽の認証。
class _FakeAccountAuth implements AccountAuth {
  _FakeAccountAuth(this.log);

  final List<String> log;
  AccountStatus status = const AccountStatus.guest();
  Object? linkError;
  Object? signInError;
  Object? signOutError;

  @override
  AccountStatus currentStatus() => status;

  @override
  Future<void> linkWithGoogle() async {
    log.add('link');
    if (linkError != null) throw linkError!;
    status = const AccountStatus.registered(
      method: LoginMethod.google,
      email: 'user@example.com',
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    log.add('signIn');
    if (signInError != null) throw signInError!;
    status = const AccountStatus.registered(
      method: LoginMethod.google,
      email: 'existing@example.com',
    );
  }

  @override
  Future<void> signOut() async {
    log.add('signOut');
    if (signOutError != null) throw signOutError!;
    status = const AccountStatus.guest();
  }
}

void main() {
  late List<String> log;
  late _FakeAccountAuth auth;
  Object? ensureSignedInError;

  FirebaseAccountRepository newRepository() => FirebaseAccountRepository(
    auth: auth,
    ensureSignedIn: () async {
      log.add('ensureSignedIn');
      if (ensureSignedInError != null) throw ensureSignedInError!;
    },
  );

  setUp(() {
    log = [];
    auth = _FakeAccountAuth(log);
    ensureSignedInError = null;
  });

  test('いまの状態を返す', () async {
    expect(await newRepository().loadStatus(), const AccountStatus.guest());

    auth.status = const AccountStatus.registered(method: LoginMethod.google);
    expect(
      await newRepository().loadStatus(),
      const AccountStatus.registered(method: LoginMethod.google),
    );
  });

  group('register', () {
    test('ログインを確かめてから、Googleで紐づけて、登録済みの状態を返す', () async {
      final status = await newRepository().register(LoginMethod.google);

      expect(log, ['ensureSignedIn', 'link']);
      expect(
        status,
        const AccountStatus.registered(
          method: LoginMethod.google,
          email: 'user@example.com',
        ),
      );
    });

    test('ログインを確かめられなかったら、紐づけずに、利用者向けのエラーにする', () async {
      ensureSignedInError = Exception('network');

      await expectLater(
        newRepository().register(LoginMethod.google),
        throwsA(isA<AccountException>()),
      );
      expect(log, ['ensureSignedIn']);
    });

    test('利用者が取りやめたときは、取りやめの例外にする', () async {
      auth.linkError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );

      await expectLater(
        newRepository().register(LoginMethod.google),
        throwsA(isA<AccountCancelledException>()),
      );
    });

    test('すでに登録されているGoogleアカウントは、「ログイン」から入るよう案内し、切り替えない', () async {
      auth.linkError = FirebaseAuthException(code: 'credential-already-in-use');

      await expectLater(
        newRepository().register(LoginMethod.google),
        throwsA(
          isA<AccountAlreadyRegisteredException>().having(
            (e) => e.message,
            'message',
            allOf(contains('すでに登録されています'), contains('ログイン')),
          ),
        ),
      );
      expect(auth.status, const AccountStatus.guest());
    });

    test('通信の失敗は、通信を確かめるよう案内する', () async {
      auth.linkError = FirebaseAuthException(code: 'network-request-failed');

      await expectLater(
        newRepository().register(LoginMethod.google),
        throwsA(
          isA<AccountException>().having(
            (e) => e.message,
            'message',
            contains('通信'),
          ),
        ),
      );
    });

    test('想定外のエラーは、内部の表記を出さず、決まった文言にする', () async {
      auth.linkError = StateError('boom');

      await expectLater(
        newRepository().register(LoginMethod.google),
        throwsA(
          isA<AccountException>().having(
            (e) => e.message,
            'message',
            isNot(contains('boom')),
          ),
        ),
      );
    });
  });

  group('signIn(ログイン)', () {
    test('Googleでログインして、ログイン後の状態を返す(紐づけは、しない)', () async {
      final status = await newRepository().signIn(LoginMethod.google);

      expect(
        status,
        const AccountStatus.registered(
          method: LoginMethod.google,
          email: 'existing@example.com',
        ),
      );
      expect(log, contains('signIn'));
      expect(log, isNot(contains('link')), reason: '登録(紐づけ)とは、別の処理');
    });

    test('利用者が取りやめたときは、取りやめの例外にする', () async {
      auth.signInError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );

      await expectLater(
        newRepository().signIn(LoginMethod.google),
        throwsA(isA<AccountCancelledException>()),
      );
    });

    test('通信の失敗は、通信を確かめるよう案内する', () async {
      auth.signInError = FirebaseAuthException(code: 'network-request-failed');

      await expectLater(
        newRepository().signIn(LoginMethod.google),
        throwsA(
          isA<AccountException>().having(
            (e) => e.message,
            'message',
            contains('通信'),
          ),
        ),
      );
    });

    test('想定外のエラーは、内部の表記を出さず、決まった文言にする', () async {
      auth.signInError = StateError('boom');

      await expectLater(
        newRepository().signIn(LoginMethod.google),
        throwsA(
          isA<AccountException>().having(
            (e) => e.message,
            'message',
            isNot(contains('boom')),
          ),
        ),
      );
    });

    test('ログインのあとの、サインインの確認に失敗しても、ログインは成功にする', () async {
      ensureSignedInError = Exception('network');

      final status = await newRepository().signIn(LoginMethod.google);

      expect(status.isRegistered, isTrue);
    });
  });

  group('signOut', () {
    test('ログアウトしたあと、匿名でログインし直し、ゲストの状態を返す', () async {
      auth.status = const AccountStatus.registered(method: LoginMethod.google);

      final status = await newRepository().signOut();

      expect(log, ['signOut', 'ensureSignedIn']);
      expect(status, const AccountStatus.guest());
    });

    test('匿名のログインし直しに失敗しても、ログアウトは成功にする', () async {
      ensureSignedInError = Exception('network');

      final status = await newRepository().signOut();

      expect(status, const AccountStatus.guest());
    });

    test('ログアウトに失敗したら、利用者向けのエラーにして、ログインし直さない', () async {
      auth.signOutError = FirebaseAuthException(code: 'network-request-failed');

      await expectLater(
        newRepository().signOut(),
        throwsA(isA<AccountException>()),
      );
      expect(log, ['signOut']);
    });
  });

  group('accountExceptionFrom', () {
    test('Googleの設定の問題は、設定に問題があると案内する', () {
      for (final code in [
        GoogleSignInExceptionCode.clientConfigurationError,
        GoogleSignInExceptionCode.providerConfigurationError,
      ]) {
        expect(
          accountExceptionFrom(GoogleSignInException(code: code)).message,
          contains('設定に問題があります'),
          reason: '$code',
        );
      }
    });

    test('ログイン画面を開けなかったときは、もう一度試すよう案内する', () {
      expect(
        accountExceptionFrom(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.uiUnavailable,
          ),
        ).message,
        contains('ログイン画面を開けませんでした'),
      );
    });

    test('すでにGoogleで登録済みのときは、その旨を知らせる', () {
      expect(
        accountExceptionFrom(
          FirebaseAuthException(code: 'provider-already-linked'),
        ).message,
        contains('すでにGoogleで登録済み'),
      );
    });

    test('例外は、すでに利用者向けなら、そのまま返す', () {
      const original = AccountException('そのまま');
      expect(identical(accountExceptionFrom(original), original), isTrue);
    });
  });
}
