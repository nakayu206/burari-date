import '../../domain/entities/favorite.dart';
import '../../domain/repositories/favorite_repository.dart';
import '../datasources/local/favorite_local_data_source.dart';

class FavoriteRepositoryImpl implements FavoriteRepository {
  FavoriteRepositoryImpl({FavoriteLocalDataSource? dataSource})
    : _dataSource = dataSource ?? const FavoriteLocalDataSource();

  final FavoriteLocalDataSource _dataSource;

  /// add/removeのread-modify-writeを直列化し、同時書き込みでの更新の取りこぼしを防ぐキュー。
  Future<void> _writeQueue = Future<void>.value();

  @override
  Future<List<Favorite>> loadFavorites() async {
    final favorites = await _dataSource.load();
    favorites.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return favorites;
  }

  @override
  Future<void> addFavorite(Favorite favorite) {
    return _enqueueWrite(() async {
      final favorites = await _dataSource.load()
        ..removeWhere((f) => f.candidateId == favorite.candidateId)
        ..add(favorite);
      await _dataSource.save(favorites);
    });
  }

  @override
  Future<void> removeFavorite(String candidateId) {
    return _enqueueWrite(() async {
      final favorites = await _dataSource.load()
        ..removeWhere((f) => f.candidateId == candidateId);
      await _dataSource.save(favorites);
    });
  }

  @override
  Future<bool> isFavorite(String candidateId) async {
    final favorites = await _dataSource.load();
    return favorites.any((f) => f.candidateId == candidateId);
  }

  Future<void> _enqueueWrite(Future<void> Function() write) {
    final result = _writeQueue.then((_) => write());
    _writeQueue = result.catchError((_) {}); // 失敗してもキューを詰まらせない。
    return result;
  }
}
