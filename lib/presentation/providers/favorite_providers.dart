import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/favorite_repository_impl.dart';
import '../../domain/entities/favorite.dart';
import '../../domain/repositories/favorite_repository.dart';

final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  return FavoriteRepositoryImpl();
});

/// お気に入り一覧画面用。
final favoritesProvider = FutureProvider<List<Favorite>>((ref) {
  return ref.watch(favoriteRepositoryProvider).loadFavorites();
});

/// S-06の「保存する」ボタンの表示切り替え用。
final isFavoriteProvider = FutureProvider.family<bool, String>((
  ref,
  candidateId,
) {
  return ref.watch(favoriteRepositoryProvider).isFavorite(candidateId);
});
