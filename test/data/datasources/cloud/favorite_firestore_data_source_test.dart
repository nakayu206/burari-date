import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/data/datasources/cloud/favorite_firestore_data_source.dart';
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

void main() {
  group('FavoriteFirestoreDataSource', () {
    test('upsertで保存した内容をloadで取得できる', () async {
      final dataSource = FavoriteFirestoreDataSource(
        firestore: FakeFirebaseFirestore(),
        uid: 'user1',
      );

      await dataSource.upsert(_favorite('c1', DateTime(2026, 1, 1)));

      final favorites = await dataSource.load();
      expect(favorites, hasLength(1));
      expect(favorites.single.candidateId, 'c1');
    });

    test('同じcandidateIdへのupsertは上書きする(重複保存されない)', () async {
      final dataSource = FavoriteFirestoreDataSource(
        firestore: FakeFirebaseFirestore(),
        uid: 'user1',
      );

      await dataSource.upsert(_favorite('c1', DateTime(2026, 1, 1)));
      await dataSource.upsert(_favorite('c1', DateTime(2026, 1, 2)));

      final favorites = await dataSource.load();
      expect(favorites, hasLength(1));
      expect(favorites.single.savedAt, DateTime(2026, 1, 2));
    });

    test('removeで削除するとexistsがfalseになる', () async {
      final dataSource = FavoriteFirestoreDataSource(
        firestore: FakeFirebaseFirestore(),
        uid: 'user1',
      );
      await dataSource.upsert(_favorite('c1', DateTime(2026, 1, 1)));

      await dataSource.remove('c1');

      expect(await dataSource.exists('c1'), isFalse);
      expect(await dataSource.load(), isEmpty);
    });

    test('loadは新しい順に並べ替えて返す', () async {
      final dataSource = FavoriteFirestoreDataSource(
        firestore: FakeFirebaseFirestore(),
        uid: 'user1',
      );
      await dataSource.upsert(_favorite('old', DateTime(2026, 1, 1)));
      await dataSource.upsert(_favorite('new', DateTime(2026, 6, 1)));

      final favorites = await dataSource.load();

      expect(favorites.map((f) => f.candidateId), ['new', 'old']);
    });

    test('異なるUIDのデータは混ざらない', () async {
      final firestore = FakeFirebaseFirestore();
      final user1 = FavoriteFirestoreDataSource(
        firestore: firestore,
        uid: 'user1',
      );
      final user2 = FavoriteFirestoreDataSource(
        firestore: firestore,
        uid: 'user2',
      );
      await user1.upsert(_favorite('c1', DateTime(2026, 1, 1)));

      expect(await user1.load(), hasLength(1));
      expect(await user2.load(), isEmpty);
    });
  });
}
