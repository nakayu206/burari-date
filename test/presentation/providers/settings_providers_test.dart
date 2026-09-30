import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:burari_date/domain/entities/ai_preference.dart';
import 'package:burari_date/domain/entities/notification_settings.dart';
import 'package:burari_date/domain/repositories/settings_repository.dart';
import 'package:burari_date/presentation/providers/settings_providers.dart';

/// 保存だけ常に失敗させるリポジトリ。
class _FailingSaveRepository implements SettingsRepository {
  @override
  Future<NotificationSettings> loadNotificationSettings() async =>
      const NotificationSettings();

  @override
  Future<void> saveNotificationSettings(NotificationSettings settings) =>
      Future.error(Exception('save failed'));

  @override
  Future<AiPreference> loadAiPreference() async => const AiPreference();

  @override
  Future<void> saveAiPreference(AiPreference preference) =>
      Future.error(Exception('save failed'));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('notificationSettingsProvider', () {
    test('変更すると状態に反映され、作り直したContainerでも保持される', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(notificationSettingsProvider.future);

      await container
          .read(notificationSettingsProvider.notifier)
          .save(const NotificationSettings(isSoundEnabled: false));

      expect(
        container.read(notificationSettingsProvider).value,
        const NotificationSettings(isSoundEnabled: false),
      );

      final reopened = ProviderContainer();
      addTearDown(reopened.dispose);
      expect(
        await reopened.read(notificationSettingsProvider.future),
        const NotificationSettings(isSoundEnabled: false),
      );
    });

    test('保存に失敗したら元の値に戻し、例外を伝える', () async {
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _FailingSaveRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(notificationSettingsProvider.future);

      await expectLater(
        container
            .read(notificationSettingsProvider.notifier)
            .save(const NotificationSettings(isSoundEnabled: false)),
        throwsException,
      );

      expect(
        container.read(notificationSettingsProvider).value,
        const NotificationSettings(),
      );
    });
  });

  group('aiPreferenceProvider', () {
    test('変更すると状態に反映され、作り直したContainerでも保持される', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(aiPreferenceProvider.future);

      await container
          .read(aiPreferenceProvider.notifier)
          .save(const AiPreference(genres: {'中華'}, budget: '高め'));

      final reopened = ProviderContainer();
      addTearDown(reopened.dispose);
      expect(
        await reopened.read(aiPreferenceProvider.future),
        const AiPreference(genres: {'中華'}, budget: '高め'),
      );
    });

    test('保存に失敗したら元の値に戻し、例外を伝える', () async {
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _FailingSaveRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(aiPreferenceProvider.future);

      await expectLater(
        container
            .read(aiPreferenceProvider.notifier)
            .save(const AiPreference(mood: 'レトロ')),
        throwsException,
      );

      expect(container.read(aiPreferenceProvider).value, const AiPreference());
    });
  });
}
