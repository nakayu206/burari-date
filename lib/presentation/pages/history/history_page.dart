import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../widgets/app_bottom_nav.dart';

/// S-07 履歴画面
///
/// 仕様書 4.2 に記載の通り詳細は今後の拡張フェーズで検討中のプレースホルダー。
/// 実装時は GachaHistory テーブル(仕様書 6.2)からの取得に置き換える。
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  static const _placeholderEntries = [
    (station: '△△駅', summary: 'グルメ2件保存', date: '9/1'),
    (station: '□□駅', summary: '観光1件保存', date: '8/24'),
    (station: '◇◇駅', summary: '', date: '8/10'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('履歴')),
      body: SafeArea(
        child: _placeholderEntries.isEmpty
            ? const _EmptyHistory()
            : ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                itemCount: _placeholderEntries.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.lg),
                itemBuilder: (context, index) {
                  final entry = _placeholderEntries[index];
                  return Row(
                    children: [
                      const Icon(
                        Icons.circle,
                        size: 10,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.station,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: AppFontSizes.bodyMedium,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (entry.summary.isNotEmpty)
                              Text(
                                entry.summary,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: AppFontSizes.caption,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        entry.date,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppFontSizes.caption,
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: AppBottomNav(currentTab: AppTab.history),
      ),
    );
  }
}

/// 履歴が1件もない場合の空状態(Figmaに参照なし、仕様書4.2「詳細は今後の
/// 拡張フェーズで検討」に対するたたき台)。
class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x2l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.train_rounded,
              size: AppSizes.iconLg,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'まだガチャの履歴がありません',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
