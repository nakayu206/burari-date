import '../entities/ai_preference.dart';
import '../entities/notification_settings.dart';

/// 設定画面の各設定(通知・AI提案の好み)の永続化を抽象化する。
///
/// 保存済みの値がない項目は、各エンティティの初期値を返す。
abstract interface class SettingsRepository {
  Future<NotificationSettings> loadNotificationSettings();

  Future<void> saveNotificationSettings(NotificationSettings settings);

  Future<AiPreference> loadAiPreference();

  Future<void> saveAiPreference(AiPreference preference);
}
