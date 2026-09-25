import '../../domain/entities/favorite.dart';
import '../../domain/repositories/favorite_repository.dart';
import '../datasources/cloud/favorite_firestore_data_source.dart';

class FavoriteRepositoryImpl implements FavoriteRepository {
  FavoriteRepositoryImpl({FavoriteFirestoreDataSource? dataSource})
    : _dataSource = dataSource ?? FavoriteFirestoreDataSource();

  final FavoriteFirestoreDataSource _dataSource;

  @override
  Future<List<Favorite>> loadFavorites() => _dataSource.load();

  @override
  Future<void> addFavorite(Favorite favorite) => _dataSource.upsert(favorite);

  @override
  Future<void> removeFavorite(String candidateId) =>
      _dataSource.remove(candidateId);

  @override
  Future<bool> isFavorite(String candidateId) =>
      _dataSource.exists(candidateId);
}
