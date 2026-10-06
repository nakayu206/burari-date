import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/subscription.dart';
import 'package:burari_date/domain/repositories/candidate_repository.dart';
import 'package:burari_date/domain/repositories/purchase_repository.dart';
import 'package:burari_date/presentation/pages/gacha/limit_reached_view.dart';
import 'package:burari_date/presentation/pages/settings/purchase_page.dart';
import 'package:burari_date/presentation/providers/auth_providers.dart';
import 'package:burari_date/presentation/providers/purchase_providers.dart';

/// 購読の状態を持つだけの偽のリポジトリ。購入すると、購読中になる。
class _FakePurchaseRepository implements PurchaseRepository {
  _FakePurchaseRepository([this.status = const SubscriptionStatus.inactive()]);

  SubscriptionStatus status;

  @override
  Future<PurchaseOffer> loadOffer() async =>
      const PurchaseOffer(priceLabel: '月額300円');

  @override
  Future<SubscriptionStatus> loadStatus() async => status;

  @override
  Future<SubscriptionStatus> refreshStatus() async => status;

  @override
  Future<SubscriptionStatus> purchase() async =>
      status = const SubscriptionStatus.active();

  @override
  Future<SubscriptionStatus> restore() async => status;
}

void main() {
  const backendMessage = '無料利用の上限(10回)に達しました。継続利用にはアカウント登録と課金が必要です。';

  Future<void> pump(
    WidgetTester tester, {
    required LimitKind kind,
    required bool hasAccount,
    VoidCallback? onRetry,
    _FakePurchaseRepository? repository,
  }) async {
    // 前に開いた画面(プラン画面など)が、残らないよう、いったん、空にする。
    await tester.pumpWidget(const SizedBox());
    // 行き先のプラン画面が、Providerを使うため、ProviderScopeで包む。
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // プラン画面も、アカウント登録済みかを、同じ値で読む。
          hasAccountProvider.overrideWithValue(hasAccount),
          purchaseRepositoryProvider.overrideWithValue(
            repository ?? _FakePurchaseRepository(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: LimitReachedView(
              error: CandidateLimitException(backendMessage, kind: kind),
              hasAccount: hasAccount,
              onRetry: onRetry,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('無料枠を使い切った・アカウントなしは、登録と課金へ案内する', (tester) async {
    await pump(tester, kind: LimitKind.freeTier, hasAccount: false);

    // バックエンドの案内を、そのまま出す。
    expect(find.text(backendMessage), findsOneWidget);
    expect(find.text('アカウント登録と課金'), findsOneWidget);
  });

  testWidgets('無料枠を使い切った・アカウントありは、課金へ案内する(登録は求めない)', (tester) async {
    await pump(tester, kind: LimitKind.freeTier, hasAccount: true);

    expect(find.text('課金する'), findsOneWidget);
    expect(find.text('アカウント登録と課金'), findsNothing);
    // 登録済みの人に「アカウント登録が必要」と伝えない。
    expect(find.textContaining('アカウント登録'), findsNothing);
  });

  testWidgets('課金後の月の上限を超えたときは、追加課金へ案内する', (tester) async {
    await pump(tester, kind: LimitKind.monthly, hasAccount: true);

    expect(find.textContaining('今月の利用上限に達しました'), findsOneWidget);
    expect(find.text('追加課金'), findsOneWidget);
  });

  testWidgets('上限のときは「再読み込み」を出さない(押しても解消しないため)', (tester) async {
    for (final kind in LimitKind.values) {
      for (final hasAccount in [true, false]) {
        await pump(tester, kind: kind, hasAccount: hasAccount);
        expect(
          find.text('再読み込み'),
          findsNothing,
          reason: '$kind / hasAccount=$hasAccount',
        );
        expect(find.text('もう一度読み込む'), findsNothing);
      }
    }
  });

  group('プラン画面への導線', () {
    testWidgets('どの状況のボタンも、プラン画面へ移る', (tester) async {
      const cases = [
        (LimitKind.freeTier, false, 'アカウント登録と課金'),
        (LimitKind.freeTier, true, '課金する'),
        (LimitKind.monthly, true, '追加課金'),
      ];
      for (final (kind, hasAccount, label) in cases) {
        await pump(tester, kind: kind, hasAccount: hasAccount);

        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        expect(
          find.byType(PurchasePage),
          findsOneWidget,
          reason: '$kind / hasAccount=$hasAccount',
        );
      }
    });

    testWidgets('購入しないで戻ったときは、取り直さない(上限のまま)', (tester) async {
      var retryCount = 0;
      await pump(
        tester,
        kind: LimitKind.freeTier,
        hasAccount: true,
        onRetry: () => retryCount++,
      );

      await tester.tap(find.text('課金する'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(retryCount, 0);
    });

    testWidgets('購入して戻ったときは、候補を取り直す', (tester) async {
      var retryCount = 0;
      await pump(
        tester,
        kind: LimitKind.freeTier,
        hasAccount: true,
        onRetry: () => retryCount++,
      );

      await tester.tap(find.text('課金する'));
      await tester.pumpAndSettle();
      // プラン画面で、購入する。
      await tester.tap(find.textContaining('で購入する'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(retryCount, 1);
    });
  });

  group('購入の直後(サーバーへの反映待ち)', () {
    testWidgets('購読中なのに、無料枠の上限と答えられたときは、反映を待つ案内と、読み込み直しを出す', (tester) async {
      var retryCount = 0;
      await pump(
        tester,
        kind: LimitKind.freeTier,
        hasAccount: true,
        onRetry: () => retryCount++,
        repository: _FakePurchaseRepository(const SubscriptionStatus.active()),
      );

      expect(find.textContaining('購入ありがとうございます'), findsOneWidget);
      expect(find.text('課金する'), findsNothing);
      expect(find.text(backendMessage), findsNothing);

      await tester.tap(find.text('もう一度読み込む'));
      expect(retryCount, 1);
    });

    testWidgets('購読中で、月の上限のときは、反映待ちにしない(追加課金を案内する)', (tester) async {
      await pump(
        tester,
        kind: LimitKind.monthly,
        hasAccount: true,
        repository: _FakePurchaseRepository(const SubscriptionStatus.active()),
      );

      expect(find.textContaining('今月の利用上限に達しました'), findsOneWidget);
      expect(find.text('追加課金'), findsOneWidget);
      expect(find.text('もう一度読み込む'), findsNothing);
    });
  });
}
