import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/presentation/pages/gacha/station_select_page.dart';
import 'package:burari_date/presentation/pages/home/home_page.dart';

void main() {
  group('HomePage', () {
    testWidgets('タイトルとガチャ開始ボタンを表示する', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomePage())),
      );

      expect(find.text('デートガチャ'), findsOneWidget);
      expect(find.text('ガチャを始める'), findsOneWidget);
    });

    testWidgets('ガチャを始めるボタンをタップすると駅選択画面に遷移する', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomePage())),
      );

      await tester.tap(find.text('ガチャを始める'));
      await tester.pumpAndSettle();

      expect(find.byType(StationSelectPage), findsOneWidget);
    });
  });
}
