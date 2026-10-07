import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:burari_date/domain/entities/account_status.dart';
import 'package:burari_date/domain/entities/subscription.dart';
import 'package:burari_date/domain/repositories/account_repository.dart';
import 'package:burari_date/domain/repositories/purchase_repository.dart';
import 'package:burari_date/presentation/pages/settings/purchase_page.dart';
import 'package:burari_date/presentation/providers/account_providers.dart';
import 'package:burari_date/presentation/providers/auth_providers.dart';
import 'package:burari_date/presentation/providers/purchase_providers.dart';

/// 登録の呼び出しを、記録するだけの偽のアカウントのリポジトリ。
class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository(this.log);

  final List<String> log;
  AccountStatus status = const AccountStatus.guest();
  Object? registerError;
  Completer<void>? registerGate;
  Object? signInError;

  /// ログインしたときに、呼ぶ(ログインした先のアカウントの、購読の状態を、設定するため)。
  void Function()? onSignIn;

  @override
  Future<AccountStatus> loadStatus() async => status;

  @override
  Future<AccountStatus> signIn(LoginMethod method) async {
    log.add('signIn');
    if (signInError != null) throw signInError!;
    onSignIn?.call();
    return status = AccountStatus.registered(
      method: method,
      email: 'existing@example.com',
    );
  }

  @override
  Future<AccountStatus> register(LoginMethod method) async {
    log.add('register');
    await registerGate?.future;
    if (registerError != null) throw registerError!;
    return status = AccountStatus.registered(method: method);
  }

  @override
  Future<AccountStatus> signOut() async => status = const AccountStatus.guest();
}

/// 状態を持つだけの偽のリポジトリ。[purchaseError]・[restoreResult]などで、結果を変える。
class _FakePurchaseRepository implements PurchaseRepository {
  _FakePurchaseRepository([this.status = const SubscriptionStatus.inactive()]);

  SubscriptionStatus status;
  Object? loadError;
  Object? purchaseError;
  SubscriptionStatus restoreResult = const SubscriptionStatus.inactive();

  /// 取り直し(refreshStatus)で、返す状態。nullなら、いまの状態のまま。
  SubscriptionStatus? refreshResult;
  Object? refreshError;
  int refreshCount = 0;
  Completer<void>? purchaseGate;
  int purchaseCount = 0;
  int restoreCount = 0;

  @override
  Future<PurchaseOffer> loadOffer() async {
    if (loadError != null) throw loadError!;
    return const PurchaseOffer(priceLabel: '月額300円');
  }

  @override
  Future<SubscriptionStatus> loadStatus() async => status;

  @override
  Future<SubscriptionStatus> refreshStatus() async {
    refreshCount++;
    if (refreshError != null) throw refreshError!;
    return status = refreshResult ?? status;
  }

  /// 呼び出しの順番の記録(登録 → 購入の順を、確かめるため。nullなら記録しない)。
  List<String>? log;

  @override
  Future<SubscriptionStatus> purchase() async {
    log?.add('purchase');
    purchaseCount++;
    await purchaseGate?.future;
    if (purchaseError != null) throw purchaseError!;
    return status = SubscriptionStatus.active(renewsOn: DateTime(2026, 11, 5));
  }

  @override
  Future<SubscriptionStatus> restore() async {
    restoreCount++;
    return status = restoreResult;
  }
}

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    _FakePurchaseRepository repository, {
    bool hasAccount = true,
    SubscriptionUrlLauncher? launcher,
    _FakeAccountRepository? accountRepository,
    Size size = const Size(1170, 2532),
    double pixelRatio = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchaseRepositoryProvider.overrideWithValue(repository),
          // 登録の流れを試すときは、実際の登録の状態から、アカウントの有無を、導く。
          if (accountRepository != null)
            accountRepositoryProvider.overrideWithValue(accountRepository)
          else
            hasAccountProvider.overrideWithValue(hasAccount),
        ],
        child: MaterialApp(
          home: launcher == null
              ? const PurchasePage()
              : PurchasePage(launchUrlOverride: launcher),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder purchaseButton() => find.widgetWithText(ElevatedButton, '月額300円で購入する');

  testWidgets('プランの案内(価格・使い放題・制限の可能性)を表示する', (tester) async {
    await pumpPage(tester, _FakePurchaseRepository());

    expect(find.text('月額300円'), findsOneWidget);
    expect(find.text('ガチャを、使い放題でお楽しみいただけます。'), findsOneWidget);
    expect(find.textContaining('機能を制限することがあります'), findsOneWidget);
  });

  group('アカウント登録済み・未購読', () {
    testWidgets('購入と復元のボタンを出す', (tester) async {
      await pumpPage(tester, _FakePurchaseRepository());

      expect(purchaseButton(), findsOneWidget);
      expect(find.text('購入を復元する'), findsOneWidget);
      expect(find.text('ご利用中のプランです'), findsNothing);
    });

    testWidgets('購入すると、完了を知らせ、購読中の表示になる', (tester) async {
      final repository = _FakePurchaseRepository();
      await pumpPage(tester, repository);

      await tester.tap(purchaseButton());
      await tester.pumpAndSettle();

      expect(repository.purchaseCount, 1);
      expect(find.text('ご購入ありがとうございます'), findsOneWidget);

      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      expect(find.text('ご利用中のプランです'), findsOneWidget);
      expect(find.text('次回の更新日: 2026年11月5日(自動で更新されます)'), findsOneWidget);
      expect(purchaseButton(), findsNothing);
    });

    testWidgets('購入の処理中は、ボタンを押せず、進行中の表示を出す', (tester) async {
      final repository = _FakePurchaseRepository()..purchaseGate = Completer();
      await pumpPage(tester, repository);

      await tester.tap(purchaseButton());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '購入を復元する'))
            .onPressed,
        isNull,
      );

      repository.purchaseGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('ご購入ありがとうございます'), findsOneWidget);
    });

    testWidgets('購入に失敗したら、理由をダイアログで知らせ、もう一度押せる', (tester) async {
      final repository = _FakePurchaseRepository()
        ..purchaseError = const PurchaseException('ストアに接続できませんでした。');
      await pumpPage(tester, repository);

      await tester.tap(purchaseButton());
      await tester.pumpAndSettle();

      expect(find.text('ご購入を完了できませんでした'), findsOneWidget);
      expect(find.text('ストアに接続できませんでした。'), findsOneWidget);

      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ElevatedButton>(purchaseButton()).onPressed,
        isNotNull,
      );
    });

    testWidgets('利用者が取りやめたときは、エラーを出さない', (tester) async {
      final repository = _FakePurchaseRepository()
        ..purchaseError = const PurchaseCancelledException();
      await pumpPage(tester, repository);

      await tester.tap(purchaseButton());
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(purchaseButton(), findsOneWidget);
    });

    testWidgets('想定外のエラーでも、内部の表記を出さず、決まった文言で知らせる', (tester) async {
      final repository = _FakePurchaseRepository()
        ..purchaseError = StateError('boom');
      await pumpPage(tester, repository);

      await tester.tap(purchaseButton());
      await tester.pumpAndSettle();

      expect(find.text('時間をおいて、もう一度お試しください。'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
    });

    testWidgets('復元できたら、知らせて、購読中の表示にする', (tester) async {
      final repository = _FakePurchaseRepository()
        ..restoreResult = const SubscriptionStatus.active();
      await pumpPage(tester, repository);

      await tester.tap(find.text('購入を復元する'));
      await tester.pumpAndSettle();

      expect(repository.restoreCount, 1);
      expect(find.text('購入を復元しました'), findsOneWidget);
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      expect(find.text('ご利用中のプランです'), findsOneWidget);
    });

    testWidgets('復元できる購入がなければ、その旨を知らせる', (tester) async {
      await pumpPage(tester, _FakePurchaseRepository());

      await tester.tap(find.text('購入を復元する'));
      await tester.pumpAndSettle();

      expect(find.text('復元できる購入がありません'), findsOneWidget);
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      expect(purchaseButton(), findsOneWidget);
    });
  });

  group('自動更新と解約の案内', () {
    testWidgets('購入の前に、自動で更新されることと、解約のしかたを、伝える', (tester) async {
      await pumpPage(tester, _FakePurchaseRepository());

      expect(find.textContaining('毎月、自動で更新されます'), findsOneWidget);
      expect(find.textContaining('次回の更新日の前までに解約しないと'), findsOneWidget);
      expect(find.textContaining('Google Playの「定期購入」から'), findsOneWidget);
      expect(find.textContaining('アプリの中からは、解約できません'), findsOneWidget);
    });

    testWidgets('アカウント未登録でも、同じ案内を出す(購入の前に、読めるように)', (tester) async {
      await pumpPage(tester, _FakePurchaseRepository(), hasAccount: false);

      expect(find.textContaining('毎月、自動で更新されます'), findsOneWidget);
    });
  });

  group('購読中は、購入前の案内を出さない(状態の表示と矛盾させない)', () {
    testWidgets('自動で更新される購読では、購入前の「毎月、自動で更新されます」の案内は出さず、更新日を出す', (
      tester,
    ) async {
      await pumpPage(
        tester,
        _FakePurchaseRepository(
          SubscriptionStatus.active(renewsOn: DateTime(2026, 11, 5)),
        ),
      );

      expect(find.textContaining('毎月、自動で更新されます'), findsNothing);
      expect(find.textContaining('アプリの中からは、解約できません'), findsNothing);
      expect(find.text('次回の更新日: 2026年11月5日(自動で更新されます)'), findsOneWidget);
      // 解約などは、管理のボタンから。
      expect(find.text('定期購入を管理する(解約など)'), findsOneWidget);
    });

    testWidgets('解約済みの購読では、「自動で更新されます」と「自動では更新されません」を、同時に出さない', (tester) async {
      await pumpPage(
        tester,
        _FakePurchaseRepository(
          SubscriptionStatus.active(endsOn: DateTime(2026, 11, 5)),
        ),
      );

      expect(find.textContaining('自動で更新されます'), findsNothing);
      expect(find.textContaining('自動では更新されません'), findsOneWidget);
    });

    testWidgets('購入して購読中になったら、購入前の案内は消える', (tester) async {
      await pumpPage(tester, _FakePurchaseRepository());
      expect(find.textContaining('毎月、自動で更新されます'), findsOneWidget);

      await tester.tap(purchaseButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();

      expect(find.text('ご利用中のプランです'), findsOneWidget);
      expect(find.textContaining('毎月、自動で更新されます'), findsNothing);
    });

    testWidgets('アプリに戻って、解約後の状態に更新されたら、「自動で更新されます」の表示も、なくなる', (tester) async {
      final repository =
          _FakePurchaseRepository(
              SubscriptionStatus.active(renewsOn: DateTime(2026, 11, 5)),
            )
            ..refreshResult = SubscriptionStatus.active(
              endsOn: DateTime(2026, 11, 5),
            );
      await pumpPage(tester, repository);
      expect(find.textContaining('自動で更新されます'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.textContaining('自動で更新されます'), findsNothing);
      expect(find.textContaining('自動では更新されません'), findsOneWidget);
    });
  });

  group('Google Playでの解約・更新の反映', () {
    final renewing = SubscriptionStatus.active(renewsOn: DateTime(2026, 11, 5));
    final cancelled = SubscriptionStatus.active(endsOn: DateTime(2026, 11, 5));

    testWidgets('アプリに戻ったとき、購読の状態を取り直し、解約後の表示に更新する', (tester) async {
      final repository = _FakePurchaseRepository(renewing)
        ..refreshResult = cancelled;
      await pumpPage(tester, repository);
      expect(find.textContaining('次回の更新日: 2026年11月5日'), findsOneWidget);

      // Google Playの「定期購入」の画面で、解約して、アプリに戻る。
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(repository.refreshCount, 1);
      expect(find.textContaining('次回の更新日: '), findsNothing);
      expect(find.text('有効期限: 2026年11月5日(自動では更新されません)'), findsOneWidget);
    });

    testWidgets('取り直している間も、読み込み中の表示には戻さない', (tester) async {
      final repository = _FakePurchaseRepository(renewing)
        ..refreshResult = cancelled;
      await pumpPage(tester, repository);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('ご利用中のプランです'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('取り直しに失敗したときは、いまの表示を残し、エラーにしない', (tester) async {
      final repository = _FakePurchaseRepository(renewing)
        ..refreshError = const PurchaseException('通信できませんでした。');
      await pumpPage(tester, repository);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(repository.refreshCount, 1);
      expect(find.textContaining('次回の更新日: 2026年11月5日'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('画面を、初めて開くときは、読み込みと別の取り直しをしない', (tester) async {
      final repository = _FakePurchaseRepository(renewing);
      await pumpPage(tester, repository);

      expect(repository.refreshCount, 0);
    });

    testWidgets('すでに取得済みの状態があるときに、開き直したら、最新に取り直す', (tester) async {
      final repository = _FakePurchaseRepository(renewing)
        ..refreshResult = cancelled;
      final container = ProviderContainer(
        overrides: [
          purchaseRepositoryProvider.overrideWithValue(repository),
          hasAccountProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);
      // 前に開いたときに、取得して、保持している状態(解約の前のもの)。
      await container.read(subscriptionStatusProvider.future);
      expect(repository.refreshCount, 0);

      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PurchasePage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.refreshCount, 1);
      expect(find.text('有効期限: 2026年11月5日(自動では更新されません)'), findsOneWidget);
    });
  });

  group('購読中', () {
    testWidgets('解約済みで、期限で終わるときは、有効期限を出し、更新とは、書かない', (tester) async {
      await pumpPage(
        tester,
        _FakePurchaseRepository(
          SubscriptionStatus.active(endsOn: DateTime(2026, 11, 5)),
        ),
      );

      expect(find.text('有効期限: 2026年11月5日(自動では更新されません)'), findsOneWidget);
      expect(find.textContaining('次回の更新日:'), findsNothing);
    });

    testWidgets('「定期購入を管理する」で、Google Playの定期購入の画面を、外部のアプリで開く', (tester) async {
      Uri? opened;
      LaunchMode? openedMode;
      await pumpPage(
        tester,
        _FakePurchaseRepository(const SubscriptionStatus.active()),
        launcher: (uri, {mode = LaunchMode.platformDefault}) async {
          opened = uri;
          openedMode = mode;
          return true;
        },
      );

      await tester.tap(find.text('定期購入を管理する(解約など)'));
      await tester.pumpAndSettle();

      expect(
        opened,
        Uri.parse('https://play.google.com/store/account/subscriptions'),
      );
      expect(openedMode, LaunchMode.externalApplication);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('開けなかったときは、ダイアログで知らせる', (tester) async {
      await pumpPage(
        tester,
        _FakePurchaseRepository(const SubscriptionStatus.active()),
        launcher: (uri, {mode = LaunchMode.platformDefault}) async => false,
      );

      await tester.tap(find.text('定期購入を管理する(解約など)'));
      await tester.pumpAndSettle();

      expect(find.text('Google Playを開けませんでした'), findsOneWidget);
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('起動で例外が出ても、ダイアログで知らせる', (tester) async {
      await pumpPage(
        tester,
        _FakePurchaseRepository(const SubscriptionStatus.active()),
        launcher: (uri, {mode = LaunchMode.platformDefault}) async =>
            throw Exception('no activity'),
      );

      await tester.tap(find.text('定期購入を管理する(解約など)'));
      await tester.pumpAndSettle();

      expect(find.text('Google Playを開けませんでした'), findsOneWidget);
    });

    testWidgets('購読していないときは、管理のボタンを出さない', (tester) async {
      await pumpPage(tester, _FakePurchaseRepository());

      expect(find.text('定期購入を管理する(解約など)'), findsNothing);
    });

    testWidgets('購入のボタンは出さず、状態を表示する', (tester) async {
      await pumpPage(
        tester,
        _FakePurchaseRepository(const SubscriptionStatus.active()),
      );

      expect(find.text('ご利用中のプランです'), findsOneWidget);
      expect(purchaseButton(), findsNothing);
      expect(find.text('購入を復元する'), findsNothing);
      // 更新日・有効期限が分からないときは、状態の表示を出さない(案内の文章には、
      // 「次回の更新日」という言葉が入るため、「次回の更新日:」の形で探す)。
      expect(find.textContaining('次回の更新日:'), findsNothing);
      expect(find.textContaining('有効期限:'), findsNothing);
      // 解約などのための、管理のボタンは、出す。
      expect(find.text('定期購入を管理する(解約など)'), findsOneWidget);
    });
  });

  group('アカウント未登録: Googleで登録して購入する(Issue #151)', () {
    Finder registerAndPurchaseButton() =>
        find.widgetWithText(ElevatedButton, 'Googleで登録して購入する');

    testWidgets('登録が必要なことと、登録して購入するボタンを出す(アカウント画面へは、飛ばない)', (tester) async {
      await pumpPage(tester, _FakePurchaseRepository(), hasAccount: false);

      expect(find.textContaining('ご購入には、アカウントの登録が必要です'), findsOneWidget);
      expect(find.textContaining('履歴とお気に入りを、そのまま引き継げます'), findsOneWidget);
      expect(registerAndPurchaseButton(), findsOneWidget);
      expect(purchaseButton(), findsNothing);
      // 別の画面に移る、これまでのボタンは、出さない。
      expect(find.text('アカウントを登録する'), findsNothing);
    });

    testWidgets('押すと、登録してから、続けて、購入し、購読中の表示になる', (tester) async {
      final log = <String>[];
      final purchases = _FakePurchaseRepository()..log = log;
      await pumpPage(
        tester,
        purchases,
        accountRepository: _FakeAccountRepository(log),
      );
      expect(registerAndPurchaseButton(), findsOneWidget);

      await tester.tap(registerAndPurchaseButton());
      await tester.pumpAndSettle();

      expect(log, ['register', 'purchase'], reason: '登録のあとに、購入');
      expect(find.text('ご購入ありがとうございます'), findsOneWidget);
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      expect(find.text('ご利用中のプランです'), findsOneWidget);
    });

    testWidgets('登録から購入まで、処理中のままで、ボタンを押せない', (tester) async {
      final log = <String>[];
      final account = _FakeAccountRepository(log)..registerGate = Completer();
      await pumpPage(
        tester,
        _FakePurchaseRepository()..log = log,
        accountRepository: account,
      );

      await tester.tap(registerAndPurchaseButton());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );

      account.registerGate!.complete();
      await tester.pumpAndSettle();
      expect(log, ['register', 'purchase']);
    });

    testWidgets('Googleのアカウントの選択を取りやめたら、何も出さず、購入に進まない', (tester) async {
      final log = <String>[];
      final account = _FakeAccountRepository(log)
        ..registerError = const AccountCancelledException();
      await pumpPage(
        tester,
        _FakePurchaseRepository()..log = log,
        accountRepository: account,
      );

      await tester.tap(registerAndPurchaseButton());
      await tester.pumpAndSettle();

      expect(log, ['register']);
      expect(find.byType(AlertDialog), findsNothing);
      // もう一度、押せる。
      expect(
        tester.widget<ElevatedButton>(registerAndPurchaseButton()).onPressed,
        isNotNull,
      );
    });

    testWidgets('登録に失敗したら、その旨を知らせ、購入には進まない', (tester) async {
      final log = <String>[];
      final account = _FakeAccountRepository(log)
        ..registerError = const AccountException('通信できませんでした。');
      await pumpPage(
        tester,
        _FakePurchaseRepository()..log = log,
        accountRepository: account,
      );

      await tester.tap(registerAndPurchaseButton());
      await tester.pumpAndSettle();

      expect(find.text('アカウントを登録できませんでした'), findsOneWidget);
      expect(find.text('通信できませんでした。'), findsOneWidget);
      expect(log, ['register'], reason: '購入には進まない');
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      expect(registerAndPurchaseButton(), findsOneWidget);
    });

    testWidgets('登録できて、購入を取りやめたら、登録済みのまま、購入のボタンが出る', (tester) async {
      final log = <String>[];
      final purchases = _FakePurchaseRepository()
        ..log = log
        ..purchaseError = const PurchaseCancelledException();
      await pumpPage(
        tester,
        purchases,
        accountRepository: _FakeAccountRepository(log),
      );

      await tester.tap(registerAndPurchaseButton());
      await tester.pumpAndSettle();

      expect(log, ['register', 'purchase']);
      expect(find.byType(AlertDialog), findsNothing);
      // 登録は済んでいるので、「登録して」ではなく、「購入する」が出る。
      expect(registerAndPurchaseButton(), findsNothing);
      expect(purchaseButton(), findsOneWidget);
    });

    testWidgets('登録できて、購入に失敗したら、その旨を知らせ、購入のボタンが出る', (tester) async {
      final log = <String>[];
      final purchases = _FakePurchaseRepository()
        ..log = log
        ..purchaseError = const PurchaseException('ストアに接続できませんでした。');
      await pumpPage(
        tester,
        purchases,
        accountRepository: _FakeAccountRepository(log),
      );

      await tester.tap(registerAndPurchaseButton());
      await tester.pumpAndSettle();

      expect(find.text('ご購入を完了できませんでした'), findsOneWidget);
      expect(find.text('ストアに接続できませんでした。'), findsOneWidget);
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      expect(purchaseButton(), findsOneWidget);
    });
  });

  group('アカウント未登録: 登録済みの方の、ログイン(Issue #153)', () {
    Finder signInLink() => find.text('登録済みの方は、Googleでログイン');

    testWidgets('「登録して購入する」の下に、小さく、登録済みの方の、ログインの入口を出す', (tester) async {
      await pumpPage(tester, _FakePurchaseRepository(), hasAccount: false);

      expect(find.text('Googleで登録して購入する'), findsOneWidget);
      expect(signInLink(), findsOneWidget);
      // プラン画面は、コンパクトに(見出し・「または」の線は、アカウント画面だけ)。
      expect(find.text('または'), findsNothing);
      // 登録して購入するボタンの下に、ログインの入口がある。
      final register = tester.getRect(
        find.widgetWithText(ElevatedButton, 'Googleで登録して購入する'),
      );
      expect(tester.getRect(signInLink()).top, greaterThan(register.bottom));
    });

    testWidgets('未登録のときも、スクロールなしの、1画面に収まる(Pixel 8a)', (tester) async {
      await pumpPage(
        tester,
        _FakePurchaseRepository(),
        hasAccount: false,
        size: const Size(1080, 2400),
        pixelRatio: 2.625,
      );

      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.maxScrollExtent, 0);
    });

    testWidgets('押すと、先に、確認を出す(ゲストの履歴が使えなくなる旨)。やめるなら、ログインしない', (tester) async {
      final log = <String>[];
      await pumpPage(
        tester,
        _FakePurchaseRepository()..log = log,
        accountRepository: _FakeAccountRepository(log),
      );

      await tester.tap(signInLink());
      await tester.pumpAndSettle();

      expect(find.text('ログインしますか?'), findsOneWidget);
      expect(find.textContaining('引き継がれず、使えなくなります'), findsOneWidget);
      expect(log, isEmpty, reason: '確認の前には、ログインしない');

      await tester.tap(find.text('やめる'));
      await tester.pumpAndSettle();

      expect(log, isEmpty);
      expect(signInLink(), findsOneWidget);
    });

    testWidgets('ログインできて、購読していなければ、購入には進まず、「…で購入する」が出る', (tester) async {
      final log = <String>[];
      await pumpPage(
        tester,
        _FakePurchaseRepository()..log = log,
        accountRepository: _FakeAccountRepository(log),
      );

      await tester.tap(signInLink());
      await tester.pumpAndSettle();
      await tester.tap(find.text('ログインする'));
      await tester.pumpAndSettle();

      expect(log, ['signIn'], reason: '登録でも、購入でもない');
      expect(find.text('Googleで登録して購入する'), findsNothing);
      expect(purchaseButton(), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('ログインした先で、すでに購読中なら、購入には進まず、引き継がれた旨を知らせる', (tester) async {
      final log = <String>[];
      final purchases = _FakePurchaseRepository()..log = log;
      final account = _FakeAccountRepository(log)
        // ログインした先のアカウントは、購読中。
        ..onSignIn = () => purchases.status = SubscriptionStatus.active(
          renewsOn: DateTime(2026, 11, 5),
        );
      await pumpPage(tester, purchases, accountRepository: account);

      await tester.tap(signInLink());
      await tester.pumpAndSettle();
      await tester.tap(find.text('ログインする'));
      await tester.pumpAndSettle();

      expect(find.text('ログインしました'), findsOneWidget);
      expect(find.text('ご利用中のプランが、引き継がれました。'), findsOneWidget);
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      expect(find.text('ご利用中のプランです'), findsOneWidget);
      expect(log, ['signIn'], reason: 'すでに購読中なので、購入には進まない');
    });

    testWidgets('Googleのアカウントの選択を取りやめたら、何も出さない', (tester) async {
      final log = <String>[];
      final account = _FakeAccountRepository(log)
        ..signInError = const AccountCancelledException();
      await pumpPage(
        tester,
        _FakePurchaseRepository()..log = log,
        accountRepository: account,
      );

      await tester.tap(signInLink());
      await tester.pumpAndSettle();
      await tester.tap(find.text('ログインする'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(signInLink(), findsOneWidget);
    });

    testWidgets('ログインに失敗したら、その旨を知らせる', (tester) async {
      final log = <String>[];
      final account = _FakeAccountRepository(log)
        ..signInError = const AccountException('通信できませんでした。');
      await pumpPage(
        tester,
        _FakePurchaseRepository()..log = log,
        accountRepository: account,
      );

      await tester.tap(signInLink());
      await tester.pumpAndSettle();
      await tester.tap(find.text('ログインする'));
      await tester.pumpAndSettle();

      expect(find.text('ログインできませんでした'), findsOneWidget);
      expect(find.text('通信できませんでした。'), findsOneWidget);
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      expect(signInLink(), findsOneWidget);
    });

    testWidgets('登録で、すでに登録済みのGoogleアカウントだったら、「ログイン」へ誘導する', (tester) async {
      final log = <String>[];
      final account = _FakeAccountRepository(log)
        ..registerError = const AccountAlreadyRegisteredException();
      await pumpPage(
        tester,
        _FakePurchaseRepository()..log = log,
        accountRepository: account,
      );

      await tester.tap(find.text('Googleで登録して購入する'));
      await tester.pumpAndSettle();

      expect(find.text('アカウントを登録できませんでした'), findsOneWidget);
      expect(find.textContaining('「Googleでログイン」から、入ってください'), findsOneWidget);
      expect(log, ['register'], reason: '購入には進まない');
    });
  });

  testWidgets('プランの情報を取得できなかったときは、案内と「もう一度読み込む」を出す', (tester) async {
    final repository = _FakePurchaseRepository()
      ..loadError = StateError('load failed');
    await pumpPage(tester, repository);

    expect(find.text('プランの情報を取得できませんでした。'), findsOneWidget);

    repository.loadError = null;
    await tester.tap(find.text('もう一度読み込む'));
    await tester.pumpAndSettle();

    expect(find.text('月額300円'), findsOneWidget);
  });
}
