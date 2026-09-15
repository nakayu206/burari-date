import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/presentation/pages/settings/notification_settings_page.dart';
import 'package:burari_date/presentation/pages/settings/settings_page.dart';

void main() {
  group('SettingsPage', () {
    testWidgets('項目をタップするとサブ画面に遷移する', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

      await tester.tap(find.text('通知設定'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationSettingsPage), findsOneWidget);
    });
  });
}
