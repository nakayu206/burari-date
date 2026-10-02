import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/ai_preference.dart';
import '../../domain/entities/sound_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// 端末ローカル(SharedPreferences)に設定を保存する。初回リリースは
/// アカウント登録なしのため、クラウド同期は行わない。
class SettingsRepositoryImpl implements SettingsRepository {
  /// テストで保存の失敗を再現するための注入ポイント。
  SettingsRepositoryImpl({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;

  static const _kSoundEnabled = 'settings.sound.enabled';
  // 以前の「通知設定」画面で保存していたキー。移行のため、新しいキーがなければ読む。
  static const _kLegacySoundEnabled = 'settings.notification.sound';
  static const _kSoundVolume = 'settings.sound.volume';
  static const _kAiGenres = 'settings.ai.genres';
  static const _kAiBudget = 'settings.ai.budget';
  static const _kAiMood = 'settings.ai.mood';

  @override
  Future<SoundSettings> loadSoundSettings() async {
    final prefs = await _preferences();
    const defaults = SoundSettings();
    return SoundSettings(
      isSoundEnabled:
          prefs.getBool(_kSoundEnabled) ??
          prefs.getBool(_kLegacySoundEnabled) ??
          defaults.isSoundEnabled,
      // 範囲外の値が保存されていても、0〜1に収める。
      volume: (prefs.getDouble(_kSoundVolume) ?? defaults.volume).clamp(
        0.0,
        1.0,
      ),
    );
  }

  @override
  Future<void> saveSoundSettings(SoundSettings settings) async {
    final prefs = await _preferences();
    _ensureSaved([
      await prefs.setBool(_kSoundEnabled, settings.isSoundEnabled),
      await prefs.setDouble(_kSoundVolume, settings.volume.clamp(0.0, 1.0)),
    ]);
  }

  /// 保存APIは、失敗してもfalseを返すだけで例外を投げない。見落とすと、画面では
  /// 変更済みなのに再起動すると元に戻る。失敗は、呼び出し元(画面)に伝える。
  void _ensureSaved(List<bool> results) {
    if (results.contains(false)) throw StateError('設定を保存できませんでした');
  }

  @override
  Future<AiPreference> loadAiPreference() async {
    final prefs = await _preferences();
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
    final prefs = await _preferences();
    // 保存時は3つのキーを必ずまとめて書くため、ジャンルのキーの有無で判定する。
    if (!prefs.containsKey(_kAiGenres)) return null;
    return loadAiPreference();
  }

  @override
  Future<void> saveAiPreference(AiPreference preference) async {
    final prefs = await _preferences();
    // 並びを固定して、同じ内容なら同じ値が保存されるようにする。
    _ensureSaved([
      await prefs.setStringList(_kAiGenres, preference.genres.toList()..sort()),
      await prefs.setString(_kAiBudget, preference.budget),
      await prefs.setString(_kAiMood, preference.mood),
    ]);
  }
}
