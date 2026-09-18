import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/entities/candidate.dart';
import '../../../domain/entities/favorite.dart';
import '../../providers/favorite_providers.dart';

/// お気に入り一覧画面。S-06で保存した候補を新しい順に表示する(仕様書 6.1 Favorite)。
class FavoriteListPage extends ConsumerWidget {
  const FavoriteListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('お気に入り')),
      body: SafeArea(
        child: favorites.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // 受動的なロード失敗は画面内表示でよい(docs/コード規約.md)。
          error: (_, _) => _FavoriteLoadError(
            onRetry: () => ref.invalidate(favoritesProvider),
          ),
          data: (entries) => entries.isEmpty
              ? const _EmptyFavorites()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.lg),
                  itemBuilder: (context, index) =>
                      _FavoriteRow(favorite: entries[index]),
                ),
        ),
      ),
    );
  }
}

class _FavoriteRow extends ConsumerWidget {
  const _FavoriteRow({required this.favorite});

  final Favorite favorite;

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(favoriteRepositoryProvider)
          .removeFavorite(favorite.candidateId);
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text('削除に失敗しました')));
      }
      return;
    }
    // awaitの間にウィジェットが破棄されているとrefの使用自体が例外になる。
    if (!context.mounted) return;
    ref.invalidate(favoritesProvider);
    ref.invalidate(isFavoriteProvider(favorite.candidateId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          favorite.category == CandidateCategory.gourmet
              ? Icons.ramen_dining_rounded
              : Icons.park_rounded,
          size: AppSizes.iconMd,
          color: AppColors.secondary,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                favorite.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppFontSizes.bodyMedium,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                favorite.catchCopy,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFontSizes.caption,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _remove(context, ref),
          icon: const Icon(Icons.delete_outline_rounded),
          color: AppColors.textSecondary,
          tooltip: 'お気に入りから削除',
        ),
      ],
    );
  }
}

class _FavoriteLoadError extends StatelessWidget {
  const _FavoriteLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x2l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'お気に入りを読み込めませんでした',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('再読み込み')),
          ],
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x2l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star_border_rounded,
              size: AppSizes.iconLg,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'まだお気に入りがありません',
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
