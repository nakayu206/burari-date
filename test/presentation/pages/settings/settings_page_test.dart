import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:burari_date/data/repositories/settings_repository_impl.dart';
import 'package:burari_date/domain/entities/ai_preference.dart';
import 'package:burari_date/domain/entities/sound_settings.dart';
import 'package:burari_date/presentation/pages/settings/ai_preference_page.dart';
import 'package:burari_date/domain/services/sound_player.dart';
import 'package:burari_date/presentation/pages/settings/contact_page.dart';
import 'package:burari_date/presentation/pages/settings/sound_settings_page.dart';
import 'package:burari_date/presentation/pages/settings/terms_page.dart';
import 'package:burari_date/presentation/providers/sound_providers.dart';
import 'package:burari_date/presentation/pages/settings/settings_page.dart';

/// 鳴らした音と音量を記録するだけの偽のプレイヤー。
class _RecordingSoundPlayer implements SoundPlayer {
  final played = <GachaSound>[];
  final volumes = <double>[];

  @override
  Future<void> play(GachaSound sound, {double volume = 1.0}) async {
    played.add(sound);
    volumes.add(volume);
  }

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> dispose() async {}
}

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

  group('SettingsPage の項目', () {
    testWidgets('「利用規約」と「お問い合わせ」は、別の項目として並ぶ', (tester) async {
      _useLargeScreen(tester);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SettingsPage())),
      );

      expect(find.text('効果音'), findsOneWidget);
      expect(find.text('好み設定'), findsOneWidget);
      expect(find.text('アカウント'), findsOneWidget);
      expect(find.text('利用規約'), findsOneWidget);
      expect(find.text('お問い合わせ'), findsOneWidget);
      // 以前の、1つにまとめた項目は、なくなった。
      expect(find.text('利用規約・お問い合わせ'), findsNothing);
    });

    testWidgets('「利用規約」は規約の画面、「お問い合わせ」はお問い合わせの画面に移る', (tester) async {
      _useLargeScreen(tester);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SettingsPage())),
      );

      await tester.tap(find.text('利用規約'));
      await tester.pumpAndSettle();
      expect(find.byType(TermsPage), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('お問い合わせ'));
      await tester.pumpAndSettle();
      expect(find.byType(ContactPage), findsOneWidget);
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

    testWidgets('音量のスライダーで、音量を変えて端末に保存し、試し聞きの音を鳴らす', (tester) async {
      _useLargeScreen(tester);
      final player = _RecordingSoundPlayer();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [soundPlayerProvider.overrideWithValue(player)],
          child: const MaterialApp(home: SoundSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('音量 100%'), findsOneWidget);

      // スライダーの左端(音量0)から右へ、半分のところまでドラッグする。
      final slider = find.byType(Slider);
      final rect = tester.getRect(slider);
      await tester.dragFrom(
        rect.centerRight - const Offset(24, 0),
        Offset(-(rect.width - 48) / 2, 0),
      );
      await tester.pumpAndSettle();

      final saved = (await SettingsRepositoryImpl().loadSoundSettings()).volume;
      expect(saved, closeTo(0.5, 0.11));
      expect(player.played, hasLength(1));
      expect(player.volumes.single, closeTo(saved, 0.001));
    });

    testWidgets('効果音がオフの間は、音量を変えられない', (tester) async {
      _useLargeScreen(tester);
      SharedPreferences.setMockInitialValues({'settings.sound.enabled': false});

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SoundSettingsPage())),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
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
