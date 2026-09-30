import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/candidate.dart';
import 'package:burari_date/domain/entities/gacha_result.dart';
import 'package:burari_date/domain/entities/railway_line.dart';
import 'package:burari_date/domain/entities/station.dart';
import 'package:burari_date/domain/repositories/candidate_repository.dart';
import 'package:burari_date/presentation/pages/gacha/candidate_list_page.dart';
import 'package:burari_date/presentation/providers/candidate_providers.dart';

void main() {
  group('CandidateListPage', () {
    const departure = Station(
      id: 'l-departure',
      name: '出発駅',
      lineId: 'l',
      orderIndex: 0,
    );
    const arrival = Station(
      id: 'l-arrival',
      name: '到着駅',
      lineId: 'l',
      orderIndex: 1,
    );
    final result = GachaResult(
      departureStation: departure,
      line: const RailwayLine(
        id: 'l',
        name: 'テスト線',
        stations: [departure, arrival],
      ),
      minStops: 1,
      maxStops: 3,
      direction: GachaDirection.up,
      arrivalStation: arrival,
      stopsCount: 1,
      executedAt: DateTime(2026, 1, 1),
    );

    const gourmetCandidate = Candidate(
      id: 'c1',
      category: CandidateCategory.gourmet,
      name: 'テスト洋食屋',
      catchCopy: 'キャッチコピー',
      reason: 'おすすめ理由',
      walkMinutes: 3,
    );
    const sightseeingCandidate = Candidate(
      id: 'c2',
      category: CandidateCategory.sightseeing,
      name: 'テスト公園',
      catchCopy: 'キャッチコピー',
      reason: 'おすすめ理由',
      walkMinutes: 4,
    );

    testWidgets('グルメタブにはホットペッパーのクレジットを表示する', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            candidatesProvider.overrideWith(
              (ref, args) async => args.category == CandidateCategory.gourmet
                  ? [gourmetCandidate]
                  : [sightseeingCandidate],
            ),
          ],
          child: MaterialApp(home: CandidateListPage(result: result)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('情報提供: ホットペッパーグルメ'), findsOneWidget);
    });

    testWidgets('観光タブにはホットペッパーのクレジットを表示しない', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            candidatesProvider.overrideWith(
              (ref, args) async => args.category == CandidateCategory.gourmet
                  ? [gourmetCandidate]
                  : [sightseeingCandidate],
            ),
          ],
          child: MaterialApp(home: CandidateListPage(result: result)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('観光'));
      await tester.pumpAndSettle();

      expect(find.text('情報提供: ホットペッパーグルメ'), findsNothing);
    });

    testWidgets('タブを切り替えても、一度取得した候補は取り直さない', (tester) async {
      final fetchCounts = <CandidateCategory, int>{};
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            candidatesProvider.overrideWith((ref, args) async {
              fetchCounts[args.category] =
                  (fetchCounts[args.category] ?? 0) + 1;
              return args.category == CandidateCategory.gourmet
                  ? [gourmetCandidate]
                  : [sightseeingCandidate];
            }),
          ],
          child: MaterialApp(home: CandidateListPage(result: result)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('観光'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('グルメ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('観光'));
      await tester.pumpAndSettle();

      expect(fetchCounts[CandidateCategory.gourmet], 1);
      expect(fetchCounts[CandidateCategory.sightseeing], 1);
    });

    testWidgets('キャッチコピーに「AI:」の接頭辞を付けない', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            candidatesProvider.overrideWith(
              (ref, args) async => [gourmetCandidate],
            ),
          ],
          child: MaterialApp(home: CandidateListPage(result: result)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('キャッチコピー'), findsOneWidget);
      expect(find.textContaining('AI:'), findsNothing);
    });

    testWidgets('無料枠の上限などの案内は、内部の表記を付けずにそのまま表示する', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            candidatesProvider.overrideWith(
              (ref, args) async => throw const CandidateFetchException(
                '無料利用の上限(10回)に達しました。継続利用にはアカウント登録と課金が必要です。',
              ),
            ),
          ],
          child: MaterialApp(home: CandidateListPage(result: result)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('無料利用の上限(10回)に達しました。継続利用にはアカウント登録と課金が必要です。'),
        findsOneWidget,
      );
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('候補の取得に失敗しました'), findsNothing);
    });

    testWidgets('想定外のエラーは、内部の表記を出さずに汎用の文言を表示する', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            candidatesProvider.overrideWith(
              (ref, args) async => throw StateError('internal detail'),
            ),
          ],
          child: MaterialApp(home: CandidateListPage(result: result)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('候補の取得に失敗しました'), findsOneWidget);
      expect(find.textContaining('internal detail'), findsNothing);
    });

    testWidgets('取得に失敗したら「再読み込み」で取り直せる', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            candidatesProvider.overrideWith((ref, args) async {
              calls++;
              if (calls == 1) throw Exception('network');
              return [gourmetCandidate];
            }),
          ],
          child: MaterialApp(home: CandidateListPage(result: result)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('候補の取得に失敗しました'), findsOneWidget);

      await tester.tap(find.text('再読み込み'));
      await tester.pumpAndSettle();

      expect(find.text('テスト洋食屋'), findsOneWidget);
      expect(find.textContaining('候補の取得に失敗しました'), findsNothing);
    });
  });
}
