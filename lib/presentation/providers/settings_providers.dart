import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/entities/ai_preference.dart';
import '../../domain/entities/notification_settings.dart';
import '../../domain/repositories/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl();
});

/// 通知設定。変更は即座に画面へ反映し、保存に失敗した場合は元の値に戻して
/// 例外を呼び出し元へ伝える(画面側でダイアログを出す)。
class NotificationSettingsNotifier extends AsyncNotifier<NotificationSettings> {
  @override
  Future<NotificationSettings> build() {
    return ref.read(settingsRepositoryProvider).loadNotificationSettings();
  }

  Future<void> save(NotificationSettings next) async {
    final previous = state;
    state = AsyncData(next);
    try {
      await ref.read(settingsRepositoryProvider).saveNotificationSettings(next);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final notificationSettingsProvider =
    AsyncNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
      NotificationSettingsNotifier.new,
    );

/// AI提案の好み設定。保存失敗時の扱いは[NotificationSettingsNotifier]と同じ。
class AiPreferenceNotifier extends AsyncNotifier<AiPreference> {
  @override
  Future<AiPreference> build() {
    return ref.read(settingsRepositoryProvider).loadAiPreference();
  }

  Future<void> save(AiPreference next) async {
    final previous = state;
    state = AsyncData(next);
    try {
      await ref.read(settingsRepositoryProvider).saveAiPreference(next);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final aiPreferenceProvider =
    AsyncNotifierProvider<AiPreferenceNotifier, AiPreference>(
      AiPreferenceNotifier.new,
    );
