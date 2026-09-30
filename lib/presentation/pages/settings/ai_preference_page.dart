import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/entities/ai_preference.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/settings_save_error_dialog.dart';

/// AI提案の好み設定画面。
///
/// Figmaに参照なし。仕様書5.4「ユーザーごとの好み(雰囲気・予算・ジャンル)を
/// 将来的にプロンプトへ反映できる設計にしておく」に対応する。設定は端末に
/// 保存される(プロンプトへの反映は別Issue)。
class AiPreferencePage extends ConsumerWidget {
  const AiPreferencePage({super.key});

  static const _genreOptions = ['和食', '洋食', '中華', 'カフェ', 'スイーツ'];
  static const _budgetOptions = ['安め', '普通', '高め'];
  static const _moodOptions = ['静か', '賑やか', 'おしゃれ', 'レトロ'];

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    AiPreference next,
  ) async {
    try {
      await ref.read(aiPreferenceProvider.notifier).save(next);
    } catch (_) {
      if (context.mounted) await showSettingsSaveErrorDialog(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(aiPreferenceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('AI提案の好み設定')),
      body: SafeArea(
        child: preference.when(
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
              const _SectionLabel('好きなジャンル(複数選択可)'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _genreOptions
                    .map(
                      (genre) => FilterChip(
                        label: Text(genre),
                        selected: value.genres.contains(genre),
                        onSelected: (selected) => _save(
                          context,
                          ref,
                          value.copyWith(
                            genres: selected
                                ? {...value.genres, genre}
                                : ({...value.genres}..remove(genre)),
                          ),
                        ),
                        selectedColor: AppColors.primaryLight,
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: value.genres.contains(genre)
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontSize: AppFontSizes.bodyMedium,
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.x2l),
              const _SectionLabel('予算感'),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<String>(
                segments: _budgetOptions
                    .map((b) => ButtonSegment(value: b, label: Text(b)))
                    .toList(),
                selected: {value.budget},
                onSelectionChanged: (selection) => _save(
                  context,
                  ref,
                  value.copyWith(budget: selection.first),
                ),
              ),
              const SizedBox(height: AppSpacing.x2l),
              const _SectionLabel('雰囲気'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _moodOptions
                    .map(
                      (mood) => ChoiceChip(
                        label: Text(mood),
                        selected: value.mood == mood,
                        onSelected: (_) =>
                            _save(context, ref, value.copyWith(mood: mood)),
                        selectedColor: AppColors.primaryLight,
                        labelStyle: TextStyle(
                          color: value.mood == mood
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontSize: AppFontSizes.bodyMedium,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: AppFontSizes.labelSmall,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
