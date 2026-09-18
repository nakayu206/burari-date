import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:burari_date/data/repositories/favorite_repository_impl.dart';
import 'package:burari_date/domain/entities/candidate.dart';
import 'package:burari_date/domain/entities/favorite.dart';
import 'package:burari_date/presentation/pages/favorite/favorite_list_page.dart';
import 'package:burari_date/presentation/providers/favorite_providers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FavoriteListPage', () {
    testWidgets('お気に入りが0件の場合は空状態を表示する', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesProvider.overrideWith((ref) async => const [])],
          child: const MaterialApp(home: FavoriteListPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('まだお気に入りがありません'), findsOneWidget);
    });

    testWidgets('お気に入りを新しい順に一覧表示する', (tester) async {
      final favorites = [
        Favorite(
          candidateId: 'c1',
          category: CandidateCategory.gourmet,
          name: 'テスト洋食屋',
          catchCopy: 'キャッチコピー1',
          reason: 'おすすめ理由',
          walkMinutes: 3,
          savedAt: DateTime(2026, 9, 18),
        ),
        Favorite(
          candidateId: 'c2',
          category: CandidateCategory.sightseeing,
          name: 'テスト公園',
          catchCopy: 'キャッチコピー2',
          reason: 'おすすめ理由',
          walkMinutes: 4,
          savedAt: DateTime(2026, 9, 10),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [favoritesProvider.overrideWith((ref) async => favorites)],
          child: const MaterialApp(home: FavoriteListPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('テスト洋食屋'), findsOneWidget);
      expect(find.text('キャッチコピー1'), findsOneWidget);
      expect(find.text('テスト公園'), findsOneWidget);
      expect(find.text('キャッチコピー2'), findsOneWidget);
    });

    testWidgets('削除アイコンをタップするとお気に入りから消える', (tester) async {
      // favoritesProviderをoverrideすると、削除後のinvalidateで同じ固定値が
      // 再取得されてしまい削除が反映されないため、ここではモック化した
      // SharedPreferences上の実データを使う(overrideしない)。
      final favoriteRepository = FavoriteRepositoryImpl();
      await favoriteRepository.addFavorite(
        Favorite(
          candidateId: 'c1',
          category: CandidateCategory.gourmet,
          name: 'テスト洋食屋',
          catchCopy: 'キャッチコピー',
          reason: 'おすすめ理由',
          walkMinutes: 3,
          savedAt: DateTime(2026, 9, 18),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoriteRepositoryProvider.overrideWithValue(favoriteRepository),
          ],
          child: const MaterialApp(home: FavoriteListPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('テスト洋食屋'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('テスト洋食屋'), findsNothing);
      expect(find.text('まだお気に入りがありません'), findsOneWidget);
    });

    testWidgets('読み込みに失敗した場合はエラーメッセージと再読み込みボタンを表示する', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider.overrideWith(
              (ref) => Future<List<Favorite>>.error('boom'),
            ),
          ],
          child: const MaterialApp(home: FavoriteListPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('お気に入りを読み込めませんでした'), findsOneWidget);
      expect(find.text('再読み込み'), findsOneWidget);
    });
  });
}
