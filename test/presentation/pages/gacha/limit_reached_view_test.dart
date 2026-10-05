import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/repositories/candidate_repository.dart';
import 'package:burari_date/presentation/pages/gacha/limit_reached_view.dart';
import 'package:burari_date/presentation/pages/settings/account_page.dart';

void main() {
  const backendMessage = '無料利用の上限(10回)に達しました。継続利用にはアカウント登録と課金が必要です。';

  Future<void> pump(
    WidgetTester tester, {
    required LimitKind kind,
    required bool hasAccount,
  }) async {
    // 行き先のアカウント画面が、Providerを使うため、ProviderScopeで包む。
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: LimitReachedView(
              error: CandidateLimitException(backendMessage, kind: kind),
              hasAccount: hasAccount,
            ),
          ),
        ),
      ),
    );
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
      }
    }
  });

  testWidgets('ボタンを押すと、アカウント画面へ移る(登録・課金の画面ができるまでの行き先)', (tester) async {
    await pump(tester, kind: LimitKind.freeTier, hasAccount: false);

    await tester.tap(find.text('アカウント登録と課金'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountPage), findsOneWidget);
  });
}
