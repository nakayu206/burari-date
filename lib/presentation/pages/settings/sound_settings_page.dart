import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/entities/sound_settings.dart';
import '../../../domain/services/sound_player.dart';
import '../../providers/settings_providers.dart';
import '../../providers/sound_providers.dart';
import '../../widgets/settings_save_error_dialog.dart';

/// 効果音の設定画面。
///
/// Figmaに参照なし(S-08はリスト画面のみ)。仕様書4.2 S-03「ミュート設定
/// (S-08設定画面)も必要」に対応する。設定は端末に保存され、次回起動時も
/// 保持される。以前は「通知設定」だったが、送るべき通知の場面がないため、通知の
/// 項目は外した(Issue #64)。
class SoundSettingsPage extends ConsumerWidget {
  const SoundSettingsPage({super.key});

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    SoundSettings next,
  ) async {
    try {
      await ref.read(soundSettingsProvider.notifier).save(next);
    } catch (_) {
      if (context.mounted) await showSettingsSaveErrorDialog(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(soundSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('効果音')),
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.primary,
                value: value.isSoundEnabled,
                onChanged: (v) =>
                    _save(context, ref, value.copyWith(isSoundEnabled: v)),
                title: const Text(
                  'ガチャ演出の効果音',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppFontSizes.bodyLarge,
                  ),
                ),
                subtitle: const Text(
                  'フリップ音・確定音を鳴らす',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFontSizes.labelSmall,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '音量 ${(value.volume * 100).round()}%',
                style: TextStyle(
                  color: value.isSoundEnabled
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: AppFontSizes.bodyMedium,
                ),
              ),
              Slider(
                value: value.volume,
                divisions: 10,
                activeColor: AppColors.primary,
                label: '${(value.volume * 100).round()}%',
                // 効果音をオフにしている間は、音量を変えても意味がない。
                onChanged: value.isSoundEnabled
                    ? (v) => _save(context, ref, value.copyWith(volume: v))
                    : null,
                // 離したときに、その音量で試し聞きの音を鳴らす。
                onChangeEnd: value.isSoundEnabled
                    ? (v) => ref
                          .read(soundPlayerProvider)
                          .play(GachaSound.confirm, volume: v)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
