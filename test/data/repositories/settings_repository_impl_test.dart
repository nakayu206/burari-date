import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:burari_date/data/repositories/settings_repository_impl.dart';
import 'package:burari_date/domain/entities/ai_preference.dart';
import 'package:burari_date/domain/entities/sound_settings.dart';

void main() {
  late SettingsRepositoryImpl repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = SettingsRepositoryImpl();
  });

  group('効果音の設定', () {
    test('保存済みの値がなければ初期値を返す', () async {
      expect(await repository.loadSoundSettings(), const SoundSettings());
    });

    test('保存した値を読み込める', () async {
      const settings = SoundSettings(isSoundEnabled: false);

      await repository.saveSoundSettings(settings);

      expect(await repository.loadSoundSettings(), settings);
    });

    test('以前の「通知設定」で保存した効果音の値を、引き継いで読み込む', () async {
      SharedPreferences.setMockInitialValues({
        'settings.notification.sound': false,
      });

      expect(
        await SettingsRepositoryImpl().loadSoundSettings(),
        const SoundSettings(isSoundEnabled: false),
      );
    });

    test('音量は初期値が最大で、保存した値を読み込める', () async {
      expect((await repository.loadSoundSettings()).volume, 1.0);

      await repository.saveSoundSettings(const SoundSettings(volume: 0.3));

      expect((await repository.loadSoundSettings()).volume, 0.3);
    });

    test('範囲外の音量が保存されていても、0〜1に収める', () async {
      SharedPreferences.setMockInitialValues({'settings.sound.volume': 5.0});
      expect((await SettingsRepositoryImpl().loadSoundSettings()).volume, 1.0);

      SharedPreferences.setMockInitialValues({'settings.sound.volume': -2.0});
      expect((await SettingsRepositoryImpl().loadSoundSettings()).volume, 0.0);
    });

    test('新しいキーの値が、以前のキーより優先される', () async {
      SharedPreferences.setMockInitialValues({
        'settings.notification.sound': false,
        'settings.sound.enabled': true,
      });

      expect(
        await SettingsRepositoryImpl().loadSoundSettings(),
        const SoundSettings(isSoundEnabled: true),
      );
    });

    test('新しいインスタンスからも保存済みの値を読み込める(永続化)', () async {
      const settings = SoundSettings(isSoundEnabled: false);
      await repository.saveSoundSettings(settings);

      expect(await SettingsRepositoryImpl().loadSoundSettings(), settings);
    });
  });

  group('好み設定', () {
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

    test('未保存のときloadSavedAiPreferenceはnullを返す(初期値と区別する)', () async {
      expect(await repository.loadSavedAiPreference(), isNull);
    });

    test('保存後はloadSavedAiPreferenceが保存した値を返す', () async {
      const preference = AiPreference(genres: {'中華'}, budget: '高め');
      await repository.saveAiPreference(preference);

      expect(await repository.loadSavedAiPreference(), preference);
    });

    test('ユーザーが初期値と同じ内容を保存した場合も「保存済み」として扱う', () async {
      await repository.saveAiPreference(const AiPreference());

      expect(await repository.loadSavedAiPreference(), const AiPreference());
    });

    test('ジャンルを全て解除した状態も保存でき、初期値に戻らない', () async {
      await repository.saveAiPreference(const AiPreference(genres: {}));

      expect((await repository.loadAiPreference()).genres, isEmpty);
    });
  });
}
