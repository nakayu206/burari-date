import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/ai_preference.dart';
import '../../domain/entities/notification_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// 端末ローカル(SharedPreferences)に設定を保存する。初回リリースは
/// アカウント登録なしのため、クラウド同期は行わない。
class SettingsRepositoryImpl implements SettingsRepository {
  static const _kNotificationEnabled = 'settings.notification.enabled';
  static const _kSoundEnabled = 'settings.notification.sound';
  static const _kHistoryUpdate = 'settings.notification.historyUpdate';
  static const _kAiGenres = 'settings.ai.genres';
  static const _kAiBudget = 'settings.ai.budget';
  static const _kAiMood = 'settings.ai.mood';

  @override
  Future<NotificationSettings> loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    const defaults = NotificationSettings();
    return NotificationSettings(
      isNotificationEnabled:
          prefs.getBool(_kNotificationEnabled) ??
          defaults.isNotificationEnabled,
      isSoundEnabled: prefs.getBool(_kSoundEnabled) ?? defaults.isSoundEnabled,
      isHistoryUpdateNotificationEnabled:
          prefs.getBool(_kHistoryUpdate) ??
          defaults.isHistoryUpdateNotificationEnabled,
    );
  }

  @override
  Future<void> saveNotificationSettings(NotificationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificationEnabled, settings.isNotificationEnabled);
    await prefs.setBool(_kSoundEnabled, settings.isSoundEnabled);
    await prefs.setBool(
      _kHistoryUpdate,
      settings.isHistoryUpdateNotificationEnabled,
    );
  }

  @override
  Future<AiPreference> loadAiPreference() async {
    final prefs = await SharedPreferences.getInstance();
    const defaults = AiPreference();
    // ジャンルは全解除(空)も有効な保存値なので、キーの有無で初期値と区別する。
    final genres = prefs.getStringList(_kAiGenres);
    return AiPreference(
      genres: genres == null ? defaults.genres : genres.toSet(),
      budget: prefs.getString(_kAiBudget) ?? defaults.budget,
      mood: prefs.getString(_kAiMood) ?? defaults.mood,
    );
  }

  @override
  Future<AiPreference?> loadSavedAiPreference() async {
    final prefs = await SharedPreferences.getInstance();
    // 保存時は3つのキーを必ずまとめて書くため、ジャンルのキーの有無で判定する。
    if (!prefs.containsKey(_kAiGenres)) return null;
    return loadAiPreference();
  }

  @override
  Future<void> saveAiPreference(AiPreference preference) async {
    final prefs = await SharedPreferences.getInstance();
    // 並びを固定して、同じ内容なら同じ値が保存されるようにする。
    await prefs.setStringList(_kAiGenres, preference.genres.toList()..sort());
    await prefs.setString(_kAiBudget, preference.budget);
    await prefs.setString(_kAiMood, preference.mood);
  }
}
