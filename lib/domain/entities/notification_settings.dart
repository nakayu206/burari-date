/// 通知設定(S-08 設定画面 > 通知設定)。端末ローカルに保存する。
class NotificationSettings {
  const NotificationSettings({
    this.isNotificationEnabled = true,
    this.isSoundEnabled = true,
    this.isHistoryUpdateNotificationEnabled = false,
  });

  /// アプリからのお知らせ全般。falseの間は他の項目も無効として扱う。
  final bool isNotificationEnabled;

  /// ガチャ演出の効果音(仕様書4.2 S-03のミュート設定)。
  final bool isSoundEnabled;

  /// 新しい候補が追加された時の通知。
  final bool isHistoryUpdateNotificationEnabled;

  NotificationSettings copyWith({
    bool? isNotificationEnabled,
    bool? isSoundEnabled,
    bool? isHistoryUpdateNotificationEnabled,
  }) {
    return NotificationSettings(
      isNotificationEnabled:
          isNotificationEnabled ?? this.isNotificationEnabled,
      isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled,
      isHistoryUpdateNotificationEnabled:
          isHistoryUpdateNotificationEnabled ??
          this.isHistoryUpdateNotificationEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      other.isNotificationEnabled == isNotificationEnabled &&
      other.isSoundEnabled == isSoundEnabled &&
      other.isHistoryUpdateNotificationEnabled ==
          isHistoryUpdateNotificationEnabled;

  @override
  int get hashCode => Object.hash(
    isNotificationEnabled,
    isSoundEnabled,
    isHistoryUpdateNotificationEnabled,
  );
}
