import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/entities/notification_settings.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/settings_save_error_dialog.dart';

/// 通知設定画面。
///
/// Figmaに参照なし(S-08はリスト画面のみ)。仕様書4.2 S-03「ミュート設定
/// (S-08設定画面)も必要」に対応する。設定は端末に保存され、次回起動時も
/// 保持される。
class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    NotificationSettings next,
  ) async {
    try {
      await ref.read(notificationSettingsProvider.notifier).save(next);
    } catch (_) {
      if (context.mounted) await showSettingsSaveErrorDialog(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('通知設定')),
      body: SafeArea(
        child: settings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Text(
              '設定を読み込めませんでした',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          data: (value) => ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            children: [
              _SettingsSwitchTile(
                title: '通知を受け取る',
                subtitle: 'アプリからのお知らせ全般のオン/オフ',
                value: value.isNotificationEnabled,
                onChanged: (v) => _save(
                  context,
                  ref,
                  value.copyWith(isNotificationEnabled: v),
                ),
              ),
              const Divider(height: AppSpacing.x2l),
              _SettingsSwitchTile(
                title: 'ガチャ演出の効果音',
                subtitle: 'フリップ音・確定音を再生する(仕様書4.2 S-03)',
                value: value.isSoundEnabled,
                onChanged: value.isNotificationEnabled
                    ? (v) =>
                          _save(context, ref, value.copyWith(isSoundEnabled: v))
                    : null,
              ),
              const Divider(height: AppSpacing.x2l),
              _SettingsSwitchTile(
                title: '履歴の更新通知',
                subtitle: '新しい候補が追加された時に通知する',
                value: value.isHistoryUpdateNotificationEnabled,
                onChanged: value.isNotificationEnabled
                    ? (v) => _save(
                        context,
                        ref,
                        value.copyWith(isHistoryUpdateNotificationEnabled: v),
                      )
                    : null,
              ),
            ],
          ),
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
