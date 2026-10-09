import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/account_status.dart';
import 'package:burari_date/domain/repositories/account_repository.dart';
import 'package:burari_date/presentation/pages/settings/account_page.dart';
import 'package:burari_date/presentation/providers/account_providers.dart';

/// 状態を持つだけの偽のリポジトリ。[registerError]・[signOutError]を設定すると、その
/// 例外で失敗する。[registerGate]を設定すると、登録の完了を、それが完了するまで遅らせる。
class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository([this.status = const AccountStatus.guest()]);

  AccountStatus status;
  Object? loadError;
  Object? registerError;
  Object? signOutError;
  Object? deleteError;
  int deleteCount = 0;
  Completer<void>? registerGate;
  final registered = <LoginMethod>[];
  int signOutCount = 0;

  @override
  Future<AccountStatus> loadStatus() async {
    if (loadError != null) throw loadError!;
    return status;
  }

  @override
  Future<AccountStatus> register(LoginMethod method) async {
    registered.add(method);
    await registerGate?.future;
    if (registerError != null) throw registerError!;
    return status = AccountStatus.registered(
      method: method,
      email: 'user@example.com',
    );
  }

  /// ログインの呼び出し。
  final signedIn = <LoginMethod>[];
  Object? signInError;
  Completer<void>? signInGate;

  @override
  Future<AccountStatus> signIn(LoginMethod method) async {
    signedIn.add(method);
    await signInGate?.future;
    if (signInError != null) throw signInError!;
    return status = AccountStatus.registered(
      method: method,
      email: 'existing@example.com',
    );
  }

  @override
  Future<AccountStatus> signOut() async {
    signOutCount++;
    if (signOutError != null) throw signOutError!;
    return status = const AccountStatus.guest();
  }

  @override
  Future<AccountStatus> deleteAccount() async {
    deleteCount++;
    if (deleteError != null) throw deleteError!;
    return status = const AccountStatus.guest();
  }
}

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    _FakeAccountRepository repository,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [accountRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: AccountPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('ゲスト', () {
    testWidgets('ゲスト利用中と、登録の案内・登録のボタンを表示する', (tester) async {
      await pumpPage(tester, _FakeAccountRepository());

      expect(find.text('ゲスト利用中'), findsOneWidget);
      expect(find.text('アカウントは、まだ登録していません'), findsOneWidget);
      expect(find.textContaining('履歴とお気に入りを、そのまま引き継げます'), findsOneWidget);
      expect(find.text('Googleで登録する'), findsOneWidget);
      expect(find.text('ログアウト'), findsNothing);
    });

    testWidgets('登録のボタンを押すと、登録済みの表示になる', (tester) async {
      final repository = _FakeAccountRepository();
      await pumpPage(tester, repository);

      await tester.tap(find.text('Googleで登録する'));
      await tester.pumpAndSettle();

      expect(repository.registered, [LoginMethod.google]);
      expect(find.text('アカウント登録済み'), findsOneWidget);
      expect(find.text('ログイン方法: Google'), findsOneWidget);
      expect(find.text('user@example.com'), findsOneWidget);
      expect(find.text('Googleで登録する'), findsNothing);
    });

    testWidgets('登録の処理中は、ボタンを押せず、進行中の表示を出す', (tester) async {
      final repository = _FakeAccountRepository()..registerGate = Completer();
      await pumpPage(tester, repository);

      await tester.tap(find.text('Googleで登録する'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );

      repository.registerGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('アカウント登録済み'), findsOneWidget);
    });

    testWidgets('登録に失敗したら、理由をダイアログで知らせ、ゲストのまま', (tester) async {
      final repository = _FakeAccountRepository()
        ..registerError = const AccountException('通信できませんでした。');
      await pumpPage(tester, repository);

      await tester.tap(find.text('Googleで登録する'));
      await tester.pumpAndSettle();

      expect(find.text('アカウントを登録できませんでした'), findsOneWidget);
      expect(find.text('通信できませんでした。'), findsOneWidget);

      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      expect(find.text('ゲスト利用中'), findsOneWidget);
      // もう一度、押せる。
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('利用者が取りやめたときは、エラーを出さない', (tester) async {
      final repository = _FakeAccountRepository()
        ..registerError = const AccountCancelledException();
      await pumpPage(tester, repository);

      await tester.tap(find.text('Googleで登録する'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('ゲスト利用中'), findsOneWidget);
    });

    testWidgets('想定外のエラーでも、内部の表記を出さず、決まった文言で知らせる', (tester) async {
      final repository = _FakeAccountRepository()
        ..registerError = StateError('boom');
      await pumpPage(tester, repository);

      await tester.tap(find.text('Googleで登録する'));
      await tester.pumpAndSettle();

      expect(find.text('時間をおいて、もう一度お試しください。'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
    });
  });

  group('ログイン(Issue #152)', () {
    Finder signInButton() => find.widgetWithText(OutlinedButton, 'Googleでログイン');

    testWidgets('ゲストのとき、「登録する」とは別のまとまり(見出しと「または」の線で分ける)に、「Googleでログイン」を出す', (
      tester,
    ) async {
      await pumpPage(tester, _FakeAccountRepository());

      expect(find.text('はじめての方'), findsOneWidget);
      expect(find.text('すでに登録済みの方'), findsOneWidget);
      expect(find.text('または'), findsOneWidget);
      expect(find.text('Googleで登録する'), findsOneWidget);
      expect(signInButton(), findsOneWidget);
      expect(find.textContaining('以前の履歴・お気に入り・購読が、戻ります'), findsOneWidget);

      // 登録のボタンと、ログインのボタンは、十分に、離れている(押し間違いを防ぐ)。
      final register = tester.getRect(
        find.widgetWithText(ElevatedButton, 'Googleで登録する'),
      );
      final signIn = tester.getRect(signInButton());
      expect(signIn.top - register.bottom, greaterThanOrEqualTo(80));
    });

    testWidgets('押すと、先に、確認を出す。やめるなら、ログインしない', (tester) async {
      final repository = _FakeAccountRepository();
      await pumpPage(tester, repository);

      await tester.tap(signInButton());
      await tester.pumpAndSettle();

      expect(find.text('ログインしますか?'), findsOneWidget);
      expect(find.textContaining('引き継がれず、使えなくなります'), findsOneWidget);
      expect(repository.signedIn, isEmpty, reason: '確認の前には、ログインしない');

      await tester.tap(find.text('やめる'));
      await tester.pumpAndSettle();

      expect(repository.signedIn, isEmpty);
      expect(find.text('ゲスト利用中'), findsOneWidget);
    });

    testWidgets('「ログインする」で、ログインし、登録済みの表示になる(登録は、呼ばない)', (tester) async {
      final repository = _FakeAccountRepository();
      await pumpPage(tester, repository);

      await tester.tap(signInButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('ログインする'));
      await tester.pumpAndSettle();

      expect(repository.signedIn, [LoginMethod.google]);
      expect(repository.registered, isEmpty);
      expect(find.text('アカウント登録済み'), findsOneWidget);
      expect(find.text('existing@example.com'), findsOneWidget);
    });

    testWidgets('Googleのアカウントの選択を取りやめたら、何も出さない', (tester) async {
      final repository = _FakeAccountRepository()
        ..signInError = const AccountCancelledException();
      await pumpPage(tester, repository);

      await tester.tap(signInButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('ログインする'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('ゲスト利用中'), findsOneWidget);
    });

    testWidgets('ログインに失敗したら、理由をダイアログで知らせ、ゲストのまま', (tester) async {
      final repository = _FakeAccountRepository()
        ..signInError = const AccountException('通信できませんでした。');
      await pumpPage(tester, repository);

      await tester.tap(signInButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('ログインする'));
      await tester.pumpAndSettle();

      expect(find.text('ログインできませんでした'), findsOneWidget);
      expect(find.text('通信できませんでした。'), findsOneWidget);
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      expect(find.text('ゲスト利用中'), findsOneWidget);
    });

    testWidgets('登録で、すでに登録済みのGoogleアカウントだったら、「ログイン」へ誘導する', (tester) async {
      final repository = _FakeAccountRepository()
        ..registerError = const AccountAlreadyRegisteredException();
      await pumpPage(tester, repository);

      await tester.tap(find.text('Googleで登録する'));
      await tester.pumpAndSettle();

      expect(find.text('アカウントを登録できませんでした'), findsOneWidget);
      expect(find.textContaining('「Googleでログイン」から、入ってください'), findsOneWidget);
    });

    testWidgets('登録済みのときは、ログインのボタンを出さない(ログアウトだけ)', (tester) async {
      await pumpPage(
        tester,
        _FakeAccountRepository(
          const AccountStatus.registered(method: LoginMethod.google),
        ),
      );

      expect(signInButton(), findsNothing);
      expect(find.text('ログアウト'), findsOneWidget);
    });
  });

  group('登録済み', () {
    final registered = _FakeAccountRepository(
      const AccountStatus.registered(
        method: LoginMethod.google,
        email: 'user@example.com',
      ),
    );

    testWidgets('登録済みの表示と、ログアウトのボタンを出す', (tester) async {
      await pumpPage(tester, registered);

      expect(find.text('アカウント登録済み'), findsOneWidget);
      expect(find.text('ログイン方法: Google'), findsOneWidget);
      expect(find.text('ログアウト'), findsOneWidget);
      expect(find.text('Googleで登録する'), findsNothing);
    });

    testWidgets('ログアウトは、確認のあとに行い、ゲストの表示に戻る', (tester) async {
      final repository = _FakeAccountRepository(
        const AccountStatus.registered(method: LoginMethod.google),
      );
      await pumpPage(tester, repository);

      await tester.tap(find.text('ログアウト'));
      await tester.pumpAndSettle();
      expect(find.text('ログアウトしますか?'), findsOneWidget);
      expect(repository.signOutCount, 0, reason: '確認の前には行わない');

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('ログアウト'),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.signOutCount, 1);
      expect(find.text('ゲスト利用中'), findsOneWidget);
    });

    testWidgets('確認で「やめる」を選ぶと、ログアウトしない', (tester) async {
      final repository = _FakeAccountRepository(
        const AccountStatus.registered(method: LoginMethod.google),
      );
      await pumpPage(tester, repository);

      await tester.tap(find.text('ログアウト'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('やめる'));
      await tester.pumpAndSettle();

      expect(repository.signOutCount, 0);
      expect(find.text('アカウント登録済み'), findsOneWidget);
    });

    testWidgets('「アカウントを削除」は、確認のあとに行い、ゲストの表示に戻る', (tester) async {
      final repository = _FakeAccountRepository(
        const AccountStatus.registered(method: LoginMethod.google),
      );
      await pumpPage(tester, repository);

      await tester.tap(find.text('アカウントを削除'));
      await tester.pumpAndSettle();
      expect(find.text('アカウントを削除しますか?'), findsOneWidget);
      // 元に戻せないこと・購読は自動では解約されないことを、先に知らせる。
      expect(find.textContaining('元に戻すことは、できません'), findsOneWidget);
      expect(find.textContaining('Google Playの「定期購入」'), findsOneWidget);
      expect(repository.deleteCount, 0, reason: '確認の前には削除しない');

      await tester.tap(find.text('削除する'));
      await tester.pumpAndSettle();

      expect(repository.deleteCount, 1);
      expect(find.text('ゲスト利用中'), findsOneWidget);
      expect(find.text('アカウントを削除しました'), findsOneWidget);
    });

    testWidgets('削除の確認で「やめる」を選ぶと、削除しない', (tester) async {
      final repository = _FakeAccountRepository(
        const AccountStatus.registered(method: LoginMethod.google),
      );
      await pumpPage(tester, repository);

      await tester.tap(find.text('アカウントを削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('やめる'));
      await tester.pumpAndSettle();

      expect(repository.deleteCount, 0);
      expect(find.text('アカウント登録済み'), findsOneWidget);
    });

    testWidgets('削除に失敗したら、ダイアログで知らせ、登録済みのまま', (tester) async {
      final repository = _FakeAccountRepository(
        const AccountStatus.registered(method: LoginMethod.google),
      )..deleteError = const AccountException('通信できませんでした。');
      await pumpPage(tester, repository);

      await tester.tap(find.text('アカウントを削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除する'));
      await tester.pumpAndSettle();

      expect(find.text('アカウントを削除できませんでした'), findsOneWidget);
      expect(find.text('通信できませんでした。'), findsOneWidget);
      expect(find.text('アカウント登録済み'), findsOneWidget);
    });

    testWidgets('ゲストには、「アカウントを削除」を出さない', (tester) async {
      await pumpPage(tester, _FakeAccountRepository());

      expect(find.text('アカウントを削除'), findsNothing);
    });

    testWidgets('ログアウトに失敗したら、ダイアログで知らせ、登録済みのまま', (tester) async {
      final repository = _FakeAccountRepository(
        const AccountStatus.registered(method: LoginMethod.google),
      )..signOutError = const AccountException('通信できませんでした。');
      await pumpPage(tester, repository);

      await tester.tap(find.text('ログアウト'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('ログアウト'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ログアウトできませんでした'), findsOneWidget);
      expect(find.text('通信できませんでした。'), findsOneWidget);
    });
  });

  testWidgets('状態を取得できなかったときは、案内と「もう一度読み込む」を出す', (tester) async {
    final repository = _FakeAccountRepository()
      ..loadError = StateError('load failed');
    await pumpPage(tester, repository);

    expect(find.text('アカウントの状態を取得できませんでした。'), findsOneWidget);

    repository.loadError = null;
    await tester.tap(find.text('もう一度読み込む'));
    await tester.pumpAndSettle();

    expect(find.text('ゲスト利用中'), findsOneWidget);
  });
}
