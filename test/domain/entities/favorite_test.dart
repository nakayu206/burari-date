import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/candidate.dart';
import 'package:burari_date/domain/entities/favorite.dart';

void main() {
  group('Favorite', () {
    test('fromCandidateは候補のスナップショットを複製する', () {
      const candidate = Candidate(
        id: 'c1',
        category: CandidateCategory.gourmet,
        name: 'テスト洋食屋',
        catchCopy: 'キャッチコピー',
        reason: 'おすすめ理由',
        walkMinutes: 3,
        address: '東京都〇〇区',
        imageUrl: 'https://example.com/a.png',
        latitude: 35.0,
        longitude: 139.0,
      );

      final favorite = Favorite.fromCandidate(candidate);

      expect(favorite.candidateId, 'c1');
      expect(favorite.category, CandidateCategory.gourmet);
      expect(favorite.name, 'テスト洋食屋');
      expect(favorite.catchCopy, 'キャッチコピー');
      expect(favorite.reason, 'おすすめ理由');
      expect(favorite.walkMinutes, 3);
      expect(favorite.address, '東京都〇〇区');
      expect(favorite.imageUrl, 'https://example.com/a.png');
      expect(favorite.latitude, 35.0);
      expect(favorite.longitude, 139.0);
    });

    test('toJson/fromJsonが値を保ったまま往復する', () {
      final favorite = Favorite(
        candidateId: 'c1',
        category: CandidateCategory.sightseeing,
        name: 'テスト公園',
        catchCopy: 'キャッチコピー',
        reason: 'おすすめ理由',
        walkMinutes: 4,
        savedAt: DateTime(2026, 9, 18, 12, 0),
      );

      final restored = Favorite.fromJson(favorite.toJson());

      expect(restored.candidateId, favorite.candidateId);
      expect(restored.category, favorite.category);
      expect(restored.name, favorite.name);
      expect(restored.catchCopy, favorite.catchCopy);
      expect(restored.reason, favorite.reason);
      expect(restored.walkMinutes, favorite.walkMinutes);
      expect(restored.savedAt, favorite.savedAt);
      expect(restored.address, isNull);
      expect(restored.latitude, isNull);
    });
  });
}
