import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';

/// 通知設定画面。
///
/// Figmaに参照なし(S-08はリスト画面のみ)。仕様書4.2 S-03「ミュート設定
/// (S-08設定画面)も必要」に対応する、UIのみの初期実装(状態は非永続)。
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _historyUpdateNotification = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知設定')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          children: [
            _SettingsSwitchTile(
              title: '通知を受け取る',
              subtitle: 'アプリからのお知らせ全般のオン/オフ',
              value: _notificationsEnabled,
              onChanged: (value) =>
                  setState(() => _notificationsEnabled = value),
            ),
            const Divider(height: AppSpacing.x2l),
            _SettingsSwitchTile(
              title: 'ガチャ演出の効果音',
              subtitle: 'フリップ音・確定音を再生する(仕様書4.2 S-03)',
              value: _soundEnabled,
              onChanged: _notificationsEnabled
                  ? (value) => setState(() => _soundEnabled = value)
                  : null,
            ),
            const Divider(height: AppSpacing.x2l),
            _SettingsSwitchTile(
              title: '履歴の更新通知',
              subtitle: '新しい候補が追加された時に通知する',
              value: _historyUpdateNotification,
              onChanged: _notificationsEnabled
                  ? (value) =>
                        setState(() => _historyUpdateNotification = value)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeThumbColor: AppColors.primary,
      value: value,
      onChanged: onChanged,
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppFontSizes.bodyLarge,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppFontSizes.labelSmall,
        ),
      ),
    );
  }
}
