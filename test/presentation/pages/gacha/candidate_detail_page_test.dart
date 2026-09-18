import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/candidate.dart';
import 'package:burari_date/domain/entities/station.dart';
import 'package:burari_date/presentation/pages/gacha/candidate_detail_page.dart';

void main() {
  group('CandidateDetailPage', () {
    const candidateWithoutLocation = Candidate(
      id: 'c1',
      category: CandidateCategory.gourmet,
      name: 'テスト洋食屋',
      catchCopy: 'キャッチコピー',
      reason: 'おすすめ理由',
      walkMinutes: 3,
    );

    testWidgets('候補にも到着駅にも座標が無い場合は地図の代わりにプレースホルダーを表示する', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CandidateDetailPage(candidate: candidateWithoutLocation),
        ),
      );

      expect(find.byType(FlutterMap), findsNothing);
      expect(find.byIcon(Icons.map_rounded), findsOneWidget);
      expect(find.text('経路案内を開く'), findsNothing);
    });

    testWidgets('候補自体に座標が無くても、到着駅の座標をフォールバックとして地図を表示する', (tester) async {
      const station = Station(
        id: 's1',
        name: '新宿駅',
        lineId: 'l1',
        orderIndex: 0,
        latitude: 35.69,
        longitude: 139.70,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: CandidateDetailPage(
            candidate: candidateWithoutLocation,
            fallbackStation: station,
          ),
        ),
      );

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(MarkerLayer), findsOneWidget);
      expect(find.text('経路案内を開く'), findsOneWidget);
    });

    testWidgets('候補自体に座標がある場合は、到着駅ではなくそちらを使う', (tester) async {
      const candidateWithLocation = Candidate(
        id: 'c2',
        category: CandidateCategory.sightseeing,
        name: 'テスト公園',
        catchCopy: 'キャッチコピー',
        reason: 'おすすめ理由',
        walkMinutes: 4,
        latitude: 35.0,
        longitude: 135.0,
      );
      const station = Station(
        id: 's1',
        name: '新宿駅',
        lineId: 'l1',
        orderIndex: 0,
        latitude: 35.69,
        longitude: 139.70,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: CandidateDetailPage(
            candidate: candidateWithLocation,
            fallbackStation: station,
          ),
        ),
      );

      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.options.initialCenter.latitude, 35.0);
      expect(map.options.initialCenter.longitude, 135.0);
    });
  });
}
