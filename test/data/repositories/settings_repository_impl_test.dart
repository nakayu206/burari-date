import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:burari_date/data/repositories/settings_repository_impl.dart';
import 'package:burari_date/domain/entities/ai_preference.dart';
import 'package:burari_date/domain/entities/notification_settings.dart';

void main() {
  late SettingsRepositoryImpl repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = SettingsRepositoryImpl();
  });

  group('通知設定', () {
    test('保存済みの値がなければ初期値を返す', () async {
      expect(
        await repository.loadNotificationSettings(),
        const NotificationSettings(),
      );
    });

    test('保存した値を読み込める', () async {
      const settings = NotificationSettings(
        isNotificationEnabled: false,
        isSoundEnabled: false,
        isHistoryUpdateNotificationEnabled: true,
      );

      await repository.saveNotificationSettings(settings);

      expect(await repository.loadNotificationSettings(), settings);
    });

    test('新しいインスタンスからも保存済みの値を読み込める(永続化)', () async {
      const settings = NotificationSettings(isSoundEnabled: false);
      await repository.saveNotificationSettings(settings);

      expect(
        await SettingsRepositoryImpl().loadNotificationSettings(),
        settings,
      );
    });
  });

  group('AI提案の好み設定', () {
    test('保存済みの値がなければ初期値を返す', () async {
      expect(await repository.loadAiPreference(), const AiPreference());
    });

    test('保存した値を読み込める', () async {
      const preference = AiPreference(
        genres: {'中華', 'スイーツ'},
        budget: '高め',
        mood: 'レトロ',
      );

      await repository.saveAiPreference(preference);

      expect(await repository.loadAiPreference(), preference);
    });

    test('ジャンルを全て解除した状態も保存でき、初期値に戻らない', () async {
      await repository.saveAiPreference(const AiPreference(genres: {}));

      expect((await repository.loadAiPreference()).genres, isEmpty);
    });
  });
}
