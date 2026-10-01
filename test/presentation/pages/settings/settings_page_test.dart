import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:burari_date/data/repositories/settings_repository_impl.dart';
import 'package:burari_date/domain/entities/ai_preference.dart';
import 'package:burari_date/domain/entities/sound_settings.dart';
import 'package:burari_date/presentation/pages/settings/ai_preference_page.dart';
import 'package:burari_date/presentation/pages/settings/sound_settings_page.dart';
import 'package:burari_date/presentation/pages/settings/settings_page.dart';

void _useLargeScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SettingsPage', () {
    testWidgets('項目をタップするとサブ画面に遷移する', (tester) async {
      _useLargeScreen(tester);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SettingsPage())),
      );

      await tester.tap(find.text('効果音'));
      await tester.pumpAndSettle();

      expect(find.byType(SoundSettingsPage), findsOneWidget);
    });
  });

  group('SoundSettingsPage', () {
    testWidgets('保存済みの設定が画面に反映される', (tester) async {
      _useLargeScreen(tester);
      SharedPreferences.setMockInitialValues({
        'settings.notification.sound': false,
      });

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SoundSettingsPage())),
      );
      await tester.pumpAndSettle();

      final soundSwitch = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'ガチャ演出の効果音'),
      );
      expect(soundSwitch.value, isFalse);
    });

    testWidgets('スイッチを切り替えると端末に保存される', (tester) async {
      _useLargeScreen(tester);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SoundSettingsPage())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SwitchListTile, 'ガチャ演出の効果音'));
      await tester.pumpAndSettle();

      expect(
        await SettingsRepositoryImpl().loadSoundSettings(),
        const SoundSettings(isSoundEnabled: false),
      );
    });

    testWidgets('以前の「通知設定」で保存した値も、引き継いで表示する', (tester) async {
      _useLargeScreen(tester);
      SharedPreferences.setMockInitialValues({
        'settings.notification.sound': false,
      });

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SoundSettingsPage())),
      );
      await tester.pumpAndSettle();

      final soundSwitch = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'ガチャ演出の効果音'),
      );
      expect(soundSwitch.value, isFalse);
    });

    testWidgets('通知のスイッチは出さない(送る通知がないため)', (tester) async {
      _useLargeScreen(tester);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SoundSettingsPage())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.text('通知を受け取る'), findsNothing);
      expect(find.text('履歴の更新通知'), findsNothing);
    });
  });

  group('AiPreferencePage', () {
    testWidgets('保存済みの好み設定が画面に反映される', (tester) async {
      _useLargeScreen(tester);
      SharedPreferences.setMockInitialValues({
        'settings.ai.mood': 'レトロ',
        'settings.ai.genres': ['中華'],
      });

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AiPreferencePage())),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'レトロ'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, '中華'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, '和食'))
            .selected,
        isFalse,
      );
    });

    testWidgets('ジャンル・雰囲気を変更すると端末に保存される', (tester) async {
      _useLargeScreen(tester);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AiPreferencePage())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, '中華'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'レトロ'));
      await tester.pumpAndSettle();

      expect(
        await SettingsRepositoryImpl().loadAiPreference(),
        const AiPreference(genres: {'和食', '洋食', 'カフェ', '中華'}, mood: 'レトロ'),
      );
    });
  });
}
