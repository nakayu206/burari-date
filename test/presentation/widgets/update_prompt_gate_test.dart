import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/app_update.dart';
import 'package:burari_date/presentation/providers/app_update_providers.dart';
import 'package:burari_date/presentation/widgets/update_prompt_gate.dart';

import '../providers/app_update_providers_test.dart';

void main() {
  const update = AppUpdate(versionCode: 5, packageName: 'com.example');

  Future<void> pump(WidgetTester tester, FakeAppUpdateRepository repository) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [appUpdateRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: UpdatePromptGate(child: Scaffold(body: Text('ホーム'))),
        ),
      ),
    );
  }

  group('UpdatePromptGate', () {
    testWidgets('更新があれば、ホームを出したまま、案内を出し、案内済みを保存する', (tester) async {
      final repository = FakeAppUpdateRepository(update: update);

      await pump(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text('ホーム'), findsOneWidget);
      expect(find.text('新しいバージョンがあります'), findsOneWidget);
      expect(repository.notified, 5);
    });

    testWidgets('「更新する」で、Playの商品ページを開く', (tester) async {
      final repository = FakeAppUpdateRepository(update: update);
      await pump(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.text('更新する'));
      await tester.pumpAndSettle();

      expect(repository.opened, [update]);
      expect(find.text('新しいバージョンがあります'), findsNothing);
    });

    testWidgets('「あとで」では、商品ページを開かず、利用を続けられる', (tester) async {
      final repository = FakeAppUpdateRepository(update: update);
      await pump(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.text('あとで'));
      await tester.pumpAndSettle();

      expect(repository.opened, isEmpty);
      expect(find.text('ホーム'), findsOneWidget);
      // 案内済みは保存されたまま(同じ更新を、次の起動で繰り返さない)。
      expect(repository.notified, 5);
    });

    testWidgets('更新がなければ、案内を出さない', (tester) async {
      final repository = FakeAppUpdateRepository();

      await pump(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text('ホーム'), findsOneWidget);
      expect(find.text('新しいバージョンがあります'), findsNothing);
    });

    testWidgets('案内済みの更新は、また出さない', (tester) async {
      final repository = FakeAppUpdateRepository(update: update, notified: 5);

      await pump(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text('新しいバージョンがあります'), findsNothing);
    });
  });
}
