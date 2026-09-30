import '../entities/ai_preference.dart';
import '../entities/notification_settings.dart';

/// 設定画面の各設定(通知・AI提案の好み)の永続化を抽象化する。
///
/// 保存済みの値がない項目は、各エンティティの初期値を返す。
abstract interface class SettingsRepository {
  Future<NotificationSettings> loadNotificationSettings();

  Future<void> saveNotificationSettings(NotificationSettings settings);

  Future<AiPreference> loadAiPreference();

  /// ユーザーが一度でも保存した好み設定を返す。未保存ならnull。
  ///
  /// [loadAiPreference]は未保存でも初期値を返し画面表示に使うが、AI提案への
  /// 反映には「ユーザーが選んだ値」だけを使うため、未保存かどうかを区別する。
  Future<AiPreference?> loadSavedAiPreference();

  Future<void> saveAiPreference(AiPreference preference);
}
