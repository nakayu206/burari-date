import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/candidate.dart';
import 'package:burari_date/domain/entities/gacha_result.dart';
import 'package:burari_date/domain/entities/railway_line.dart';
import 'package:burari_date/domain/entities/station.dart';
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
  });
}
