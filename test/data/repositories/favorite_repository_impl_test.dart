import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/data/datasources/cloud/favorite_firestore_data_source.dart';
import 'package:burari_date/data/repositories/favorite_repository_impl.dart';
import 'package:burari_date/domain/entities/candidate.dart';
import 'package:burari_date/domain/entities/favorite.dart';

Favorite _favorite(String candidateId, DateTime savedAt) {
  return Favorite(
    candidateId: candidateId,
    category: CandidateCategory.gourmet,
    name: '店$candidateId',
    catchCopy: 'キャッチコピー',
    reason: 'おすすめ理由',
    walkMinutes: 1,
    savedAt: savedAt,
  );
}

FavoriteRepositoryImpl _repository() {
  return FavoriteRepositoryImpl(
    dataSource: FavoriteFirestoreDataSource(
      firestore: FakeFirebaseFirestore(),
      uid: 'user1',
    ),
  );
}

void main() {
  group('FavoriteRepositoryImpl', () {
    test('addFavoriteで保存した候補はisFavoriteでtrueになる', () async {
      final repository = _repository();

      await repository.addFavorite(_favorite('c1', DateTime(2026, 1, 1)));

      expect(await repository.isFavorite('c1'), isTrue);
      expect(await repository.isFavorite('c2'), isFalse);
    });

    test('同じcandidateIdを再度addFavoriteしても重複保存されない', () async {
      final repository = _repository();

      await repository.addFavorite(_favorite('c1', DateTime(2026, 1, 1)));
      await repository.addFavorite(_favorite('c1', DateTime(2026, 1, 2)));

      final favorites = await repository.loadFavorites();
      expect(favorites, hasLength(1));
      expect(favorites.single.savedAt, DateTime(2026, 1, 2));
    });

    test('removeFavoriteで解除するとisFavoriteがfalseになる', () async {
      final repository = _repository();
      await repository.addFavorite(_favorite('c1', DateTime(2026, 1, 1)));

      await repository.removeFavorite('c1');

      expect(await repository.isFavorite('c1'), isFalse);
      expect(await repository.loadFavorites(), isEmpty);
    });

    test('loadFavoritesは新しい順に並べ替えて返す', () async {
      final repository = _repository();
      await repository.addFavorite(_favorite('old', DateTime(2026, 1, 1)));
      await repository.addFavorite(_favorite('new', DateTime(2026, 6, 1)));

      final favorites = await repository.loadFavorites();

      expect(favorites.map((f) => f.candidateId), ['new', 'old']);
    });
  });
}
