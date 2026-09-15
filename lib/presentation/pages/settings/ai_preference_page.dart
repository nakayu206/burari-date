import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';

/// AI提案の好み設定画面。
///
/// Figmaに参照なし。仕様書5.4「ユーザーごとの好み(雰囲気・予算・ジャンル)を
/// 将来的にプロンプトへ反映できる設計にしておく」に対応する、UIのみの
/// 初期実装(状態は非永続。#4のAI連携実装時にプロンプトへ反映する想定)。
class AiPreferencePage extends StatefulWidget {
  const AiPreferencePage({super.key});

  @override
  State<AiPreferencePage> createState() => _AiPreferencePageState();
}

class _AiPreferencePageState extends State<AiPreferencePage> {
  final _genres = <String>{'和食', '洋食', 'カフェ'};
  String _budget = '普通';
  String _mood = 'おしゃれ';

  static const _genreOptions = ['和食', '洋食', '中華', 'カフェ', 'スイーツ'];
  static const _budgetOptions = ['安め', '普通', '高め'];
  static const _moodOptions = ['静か', '賑やか', 'おしゃれ', 'レトロ'];

  void _toggleGenre(String genre, bool selected) {
    setState(() {
      if (selected) {
        _genres.add(genre);
      } else {
        _genres.remove(genre);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI提案の好み設定')),
      body: SafeArea(
        child: ListView(
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
                      selected: _genres.contains(genre),
                      onSelected: (selected) => _toggleGenre(genre, selected),
                      selectedColor: AppColors.primaryLight,
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: _genres.contains(genre)
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
              selected: {_budget},
              onSelectionChanged: (selection) =>
                  setState(() => _budget = selection.first),
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
                      selected: _mood == mood,
                      onSelected: (_) => setState(() => _mood = mood),
                      selectedColor: AppColors.primaryLight,
                      labelStyle: TextStyle(
                        color: _mood == mood
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
