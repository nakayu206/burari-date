import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/entities/gacha_history_entry.dart';
import '../../../domain/entities/railway_line.dart';
import '../../providers/gacha_history_providers.dart';
import '../../widgets/app_bottom_nav.dart';

/// S-07 履歴画面。GachaHistory(仕様書 6.2)を新しい順に一覧表示する。
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(gachaHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('履歴')),
      body: SafeArea(
        child: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // 受動的なロード失敗は画面内表示でよい(docs/コード規約.md)。
          error: (_, _) => const _HistoryLoadError(),
          data: (entries) => entries.isEmpty
              ? const _EmptyHistory()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.lg),
                  itemBuilder: (context, index) =>
                      _HistoryRow(entry: entries[index]),
                ),
        ),
      ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: AppBottomNav(currentTab: AppTab.history),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final GachaHistoryEntry entry;

  String get _directionLabel => switch (entry.direction) {
    GachaDirection.up => 'up方面',
    GachaDirection.down => 'down方面',
    GachaDirection.random => 'おまかせ',
  };

  String get _formattedDate =>
      '${entry.executedAt.month}/${entry.executedAt.day}';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.circle, size: 10, color: AppColors.secondary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.arrivalStationName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppFontSizes.bodyMedium,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${entry.departureStationName}から${entry.stopsCount}駅隣($_directionLabel)',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFontSizes.caption,
                ),
              ),
            ],
          ),
        ),
        Text(
          _formattedDate,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppFontSizes.caption,
          ),
        ),
      ],
    );
  }
}

class _HistoryLoadError extends StatelessWidget {
  const _HistoryLoadError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.x2l),
        child: Text(
          '履歴を読み込めませんでした',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppFontSizes.bodyMedium,
          ),
        ),
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
