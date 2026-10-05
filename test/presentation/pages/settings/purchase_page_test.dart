import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/subscription.dart';
import 'package:burari_date/domain/repositories/purchase_repository.dart';
import 'package:burari_date/presentation/pages/settings/account_page.dart';
import 'package:burari_date/presentation/pages/settings/purchase_page.dart';
import 'package:burari_date/presentation/providers/auth_providers.dart';
import 'package:burari_date/presentation/providers/purchase_providers.dart';

/// 状態を持つだけの偽のリポジトリ。[purchaseError]・[restoreResult]などで、結果を変える。
class _FakePurchaseRepository implements PurchaseRepository {
  _FakePurchaseRepository([this.status = const SubscriptionStatus.inactive()]);

  SubscriptionStatus status;
  Object? loadError;
  Object? purchaseError;
  SubscriptionStatus restoreResult = const SubscriptionStatus.inactive();
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
  Future<SubscriptionStatus> purchase() async {
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
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchaseRepositoryProvider.overrideWithValue(repository),
          hasAccountProvider.overrideWithValue(hasAccount),
        ],
        child: const MaterialApp(home: PurchasePage()),
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
      expect(find.text('次回の更新日: 2026年11月5日'), findsOneWidget);
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

  group('購読中', () {
    testWidgets('購入のボタンは出さず、状態を表示する', (tester) async {
      await pumpPage(
        tester,
        _FakePurchaseRepository(const SubscriptionStatus.active()),
      );

      expect(find.text('ご利用中のプランです'), findsOneWidget);
      expect(purchaseButton(), findsNothing);
      expect(find.text('購入を復元する'), findsNothing);
      // 更新日が分からないときは、出さない。
      expect(find.textContaining('次回の更新日'), findsNothing);
    });
  });

  group('アカウント未登録', () {
    testWidgets('購入の前に、アカウントの登録が必要なことを案内する', (tester) async {
      await pumpPage(tester, _FakePurchaseRepository(), hasAccount: false);

      expect(find.text('ご購入には、アカウントの登録が必要です。'), findsOneWidget);
      expect(purchaseButton(), findsNothing);
    });

    testWidgets('「アカウントを登録する」で、アカウント画面へ移る', (tester) async {
      await pumpPage(tester, _FakePurchaseRepository(), hasAccount: false);

      await tester.tap(find.text('アカウントを登録する'));
      await tester.pumpAndSettle();

      expect(find.byType(AccountPage), findsOneWidget);
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
