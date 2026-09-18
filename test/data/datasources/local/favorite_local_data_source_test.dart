import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:burari_date/data/datasources/local/favorite_local_data_source.dart';
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FavoriteLocalDataSource', () {
    test('何も保存していない場合、loadは空リストを返す', () async {
      const dataSource = FavoriteLocalDataSource();

      final favorites = await dataSource.load();

      expect(favorites, isEmpty);
    });

    test('saveした内容をloadでそのまま取り出せる', () async {
      const dataSource = FavoriteLocalDataSource();
      final favorite = _favorite('c1', DateTime(2026, 1, 1));

      await dataSource.save([favorite]);
      final loaded = await dataSource.load();

      expect(loaded, hasLength(1));
      expect(loaded.single.candidateId, 'c1');
    });

    test('壊れたエントリが1件混ざっていても、他の正常なエントリは読み込める', () async {
      final prefs = await SharedPreferences.getInstance();
      final validFavorite = _favorite('c1', DateTime(2026, 1, 1));
      await prefs.setStringList('favorite_entries', [
        '{"broken": true}',
        '{"candidateId": "c1", "category": "gourmet", "name": "店c1", "catchCopy": "キャッチコピー", "reason": "おすすめ理由", "walkMinutes": 1, "savedAt": "${validFavorite.savedAt.toIso8601String()}"}',
      ]);
      const dataSource = FavoriteLocalDataSource();

      final favorites = await dataSource.load();

      expect(favorites, hasLength(1));
      expect(favorites.single.candidateId, 'c1');
    });
  });
}
