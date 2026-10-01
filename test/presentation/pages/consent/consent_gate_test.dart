import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:burari_date/core/config/terms_version.dart';
import 'package:burari_date/domain/repositories/consent_repository.dart';
import 'package:burari_date/presentation/pages/consent/consent_gate.dart';
import 'package:burari_date/presentation/pages/consent/consent_page.dart';
import 'package:burari_date/presentation/providers/consent_providers.dart';

/// 保存だけ失敗するリポジトリ。
class _FailingSaveRepository implements ConsentRepository {
  @override
  Future<int?> loadAcceptedVersion() async => null;

  @override
  Future<void> saveAcceptedVersion(int version) =>
      Future.error(StateError('save failed'));
}

/// 読み込みが終わらないリポジトリ(判定を待つ間の表示を確かめる)。
class _NeverLoadsRepository implements ConsentRepository {
  @override
  Future<int?> loadAcceptedVersion() => Completer<int?>().future;

  @override
  Future<void> saveAcceptedVersion(int version) async {}
}

/// 読み込みに失敗するリポジトリ。
class _FailingLoadRepository implements ConsentRepository {
  @override
  Future<int?> loadAcceptedVersion() => Future.error(StateError('load failed'));

  @override
  Future<void> saveAcceptedVersion(int version) async {}
}

void main() {
  const homeKey = Key('home');

  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpGate(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          home: ConsentGate(
            child: Scaffold(key: homeKey, body: Text('ホーム')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('初めて起動したときは、同意画面を出し、ホームは出さない', (tester) async {
    useTallScreen(tester);
    await pumpGate(tester);

    expect(find.byType(ConsentPage), findsOneWidget);
    expect(find.byKey(homeKey), findsNothing);
    expect(find.text('同意して始める'), findsOneWidget);
    // 同意しないと先に進めないため、「同意しない」ボタンは置かない。
    expect(find.textContaining('同意しない'), findsNothing);
  });

  testWidgets('同意画面に、利用規約とプライバシーポリシーの本文を表示する', (tester) async {
    useTallScreen(tester);
    await pumpGate(tester);

    expect(find.text('第4条(利用回数の制限と有料の機能)'), findsOneWidget);
    expect(find.text('プライバシーポリシー'), findsOneWidget);
  });

  testWidgets('「同意して始める」を押すと、同意を保存して、ホームに進む', (tester) async {
    useTallScreen(tester);
    await pumpGate(tester);

    await tester.tap(find.text('同意して始める'));
    await tester.pumpAndSettle();

    expect(find.byKey(homeKey), findsOneWidget);
    expect(find.byType(ConsentPage), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('consent.terms.version'), kTermsVersion);
  });

  group('最後までスクロールするまで、同意ボタンを押せない', () {
    ElevatedButton button(WidgetTester tester) => tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '同意して始める'),
    );

    testWidgets('本文が画面に収まらない小さな画面では、最初は押せず、案内を出す', (tester) async {
      // 既定のテスト画面(800×600)では、本文が収まらない。
      await pumpGate(tester);

      expect(button(tester).onPressed, isNull);
      expect(find.text('最後までスクロールすると、同意できます'), findsOneWidget);
    });

    testWidgets('押せない間にタップしても、同意は保存されず、ホームにも進まない', (tester) async {
      await pumpGate(tester);

      await tester.tap(find.text('同意して始める'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byKey(homeKey), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('consent.terms.version'), isNull);
    });

    testWidgets('途中までスクロールしただけでは、まだ押せない', (tester) async {
      await pumpGate(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(button(tester).onPressed, isNull);
    });

    testWidgets('最後までスクロールすると、押せるようになり、案内は消え、同意してホームに進める', (tester) async {
      await pumpGate(tester);

      // 十分に大きく、何度かスクロールして、末尾まで進める。
      for (var i = 0; i < 20; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pumpAndSettle();
      }

      expect(button(tester).onPressed, isNotNull);
      expect(find.text('最後までスクロールすると、同意できます'), findsNothing);

      await tester.tap(find.text('同意して始める'));
      await tester.pumpAndSettle();

      expect(find.byKey(homeKey), findsOneWidget);
    });

    testWidgets('一度押せるようになったら、上に戻っても押せるまま', (tester) async {
      await pumpGate(tester);
      for (var i = 0; i < 20; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pumpAndSettle();
      }

      for (var i = 0; i < 20; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, 2000));
        await tester.pumpAndSettle();
      }

      expect(button(tester).onPressed, isNotNull);
    });

    testWidgets('本文が画面に収まる(スクロールが要らない)ときは、最初から押せる', (tester) async {
      useTallScreen(tester);
      await pumpGate(tester);

      expect(button(tester).onPressed, isNotNull);
      expect(find.text('最後までスクロールすると、同意できます'), findsNothing);
    });
  });

  testWidgets('現在の版に同意済みなら、同意画面を出さず、すぐホームを出す', (tester) async {
    useTallScreen(tester);
    SharedPreferences.setMockInitialValues({
      'consent.terms.version': kTermsVersion,
    });
    await pumpGate(tester);

    expect(find.byKey(homeKey), findsOneWidget);
    expect(find.byType(ConsentPage), findsNothing);
  });

  testWidgets('規約の版が上がったら(古い版にしか同意していなければ)、もう一度同意を求める', (tester) async {
    useTallScreen(tester);
    SharedPreferences.setMockInitialValues({
      'consent.terms.version': kTermsVersion - 1,
    });
    await pumpGate(tester);

    expect(find.byType(ConsentPage), findsOneWidget);
    expect(find.byKey(homeKey), findsNothing);
  });

  testWidgets('判定を待つ間は、ホームも同意画面も出さない(一瞬ホームが見えるのを防ぐ)', (tester) async {
    await pumpGate(
      tester,
      overrides: [
        consentRepositoryProvider.overrideWithValue(_NeverLoadsRepository()),
      ],
    );

    expect(find.byKey(homeKey), findsNothing);
    expect(find.byType(ConsentPage), findsNothing);
  });

  testWidgets('判定を読み込めなかったときは、未同意として同意画面を出す', (tester) async {
    useTallScreen(tester);
    await pumpGate(
      tester,
      overrides: [
        consentRepositoryProvider.overrideWithValue(_FailingLoadRepository()),
      ],
    );

    expect(find.byType(ConsentPage), findsOneWidget);
    expect(find.byKey(homeKey), findsNothing);
  });

  testWidgets('同意の保存に失敗したら、ダイアログで知らせ、ホームには進まない', (tester) async {
    useTallScreen(tester);
    await pumpGate(
      tester,
      overrides: [
        consentRepositoryProvider.overrideWithValue(_FailingSaveRepository()),
      ],
    );

    await tester.tap(find.text('同意して始める'));
    await tester.pumpAndSettle();

    expect(find.text('同意を保存できませんでした'), findsOneWidget);
    expect(find.byKey(homeKey), findsNothing);

    // 閉じたあと、もう一度押せる。
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, '同意して始める'),
          )
          .onPressed,
      isNotNull,
    );
  });
}
