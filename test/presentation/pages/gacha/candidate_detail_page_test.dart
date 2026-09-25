import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:burari_date/data/datasources/cloud/favorite_firestore_data_source.dart';
import 'package:burari_date/data/repositories/favorite_repository_impl.dart';
import 'package:burari_date/domain/entities/candidate.dart';
import 'package:burari_date/domain/entities/station.dart';
import 'package:burari_date/presentation/pages/gacha/candidate_detail_page.dart';
import 'package:burari_date/presentation/providers/favorite_providers.dart';

/// テストごとに独立したFakeFirebaseFirestoreを使い、状態が漏れないようにする。
List<Override> _favoriteOverrides() {
  return [
    favoriteRepositoryProvider.overrideWithValue(
      FavoriteRepositoryImpl(
        dataSource: FavoriteFirestoreDataSource(
          firestore: FakeFirebaseFirestore(),
          uid: 'test-uid',
        ),
      ),
    ),
  ];
}

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
        ProviderScope(
          overrides: _favoriteOverrides(),
          child: const MaterialApp(
            home: CandidateDetailPage(candidate: candidateWithoutLocation),
          ),
        ),
      );
      await tester.pump();

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
        ProviderScope(
          overrides: _favoriteOverrides(),
          child: MaterialApp(
            home: CandidateDetailPage(
              candidate: candidateWithoutLocation,
              fallbackStation: station,
            ),
          ),
        ),
      );
      await tester.pump();

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
        ProviderScope(
          overrides: _favoriteOverrides(),
          child: MaterialApp(
            home: CandidateDetailPage(
              candidate: candidateWithLocation,
              fallbackStation: station,
            ),
          ),
        ),
      );
      await tester.pump();

      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.options.initialCenter.latitude, 35.0);
      expect(map.options.initialCenter.longitude, 135.0);
    });

    testWidgets('マーカーには候補名がツールチップとして設定される', (tester) async {
      const station = Station(
        id: 's1',
        name: '新宿駅',
        lineId: 'l1',
        orderIndex: 0,
        latitude: 35.69,
        longitude: 139.70,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _favoriteOverrides(),
          child: MaterialApp(
            home: CandidateDetailPage(
              candidate: candidateWithoutLocation,
              fallbackStation: station,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byTooltip('テスト洋食屋'), findsOneWidget);
    });

    testWidgets('地図アプリを開けなかった場合はダイアログで知らせる', (tester) async {
      const station = Station(
        id: 's1',
        name: '新宿駅',
        lineId: 'l1',
        orderIndex: 0,
        latitude: 35.69,
        longitude: 139.70,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _favoriteOverrides(),
          child: MaterialApp(
            home: CandidateDetailPage(
              candidate: candidateWithoutLocation,
              fallbackStation: station,
              launchUrlOverride:
                  (uri, {mode = LaunchMode.platformDefault}) async => false,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('経路案内を開く'));
      await tester.pumpAndSettle();

      expect(find.text('地図アプリを開けませんでした'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      expect(find.text('地図アプリを開けませんでした'), findsNothing);
    });

    testWidgets('地図アプリが開けた場合はダイアログを出さない', (tester) async {
      const station = Station(
        id: 's1',
        name: '新宿駅',
        lineId: 'l1',
        orderIndex: 0,
        latitude: 35.69,
        longitude: 139.70,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _favoriteOverrides(),
          child: MaterialApp(
            home: CandidateDetailPage(
              candidate: candidateWithoutLocation,
              fallbackStation: station,
              launchUrlOverride:
                  (uri, {mode = LaunchMode.platformDefault}) async => true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('経路案内を開く'));
      await tester.pumpAndSettle();

      expect(find.text('地図アプリを開けませんでした'), findsNothing);
    });

    testWidgets('経路案内は検索ではなくルート案内(dir)モードでGoogleマップを開く', (tester) async {
      const station = Station(
        id: 's1',
        name: '新宿駅',
        lineId: 'l1',
        orderIndex: 0,
        latitude: 35.69,
        longitude: 139.70,
      );
      Uri? capturedUri;

      await tester.pumpWidget(
        ProviderScope(
          overrides: _favoriteOverrides(),
          child: MaterialApp(
            home: CandidateDetailPage(
              candidate: candidateWithoutLocation,
              fallbackStation: station,
              launchUrlOverride:
                  (uri, {mode = LaunchMode.platformDefault}) async {
                    capturedUri = uri;
                    return true;
                  },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('経路案内を開く'));
      await tester.pumpAndSettle();

      expect(capturedUri, isNotNull);
      expect(capturedUri!.path, '/maps/dir/');
      expect(capturedUri!.queryParameters['destination'], '35.69,139.7');
    });

    testWidgets('候補の緯度だけ設定されていても、到着駅の座標と混ざらない', (tester) async {
      const candidatePartialLocation = Candidate(
        id: 'c3',
        category: CandidateCategory.gourmet,
        name: 'テスト店',
        catchCopy: 'キャッチコピー',
        reason: 'おすすめ理由',
        walkMinutes: 2,
        latitude: 10.0,
        // longitudeは意図的に未設定。
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
        ProviderScope(
          overrides: _favoriteOverrides(),
          child: MaterialApp(
            home: CandidateDetailPage(
              candidate: candidatePartialLocation,
              fallbackStation: station,
            ),
          ),
        ),
      );
      await tester.pump();

      // 候補側の緯度(10.0)と駅側の経度(139.70)を組み合わせず、
      // 駅の座標をまるごとフォールバックとして使う。
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.options.initialCenter.latitude, 35.69);
      expect(map.options.initialCenter.longitude, 139.70);
    });

    testWidgets('保存する→保存済みに切り替わり、再度タップすると解除できる', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _favoriteOverrides(),
          child: const MaterialApp(
            home: CandidateDetailPage(candidate: candidateWithoutLocation),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('保存する'), findsOneWidget);

      await tester.tap(find.text('保存する'));
      await tester.pumpAndSettle();

      expect(find.text('保存済み(解除する)'), findsOneWidget);
      expect(find.text('お気に入りに保存しました'), findsOneWidget);

      await tester.tap(find.text('保存済み(解除する)'));
      await tester.pumpAndSettle();

      expect(find.text('保存する'), findsOneWidget);
      expect(find.text('お気に入りを解除しました'), findsOneWidget);
    });

    testWidgets('グルメ候補はホットペッパーのクレジットを表示する', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _favoriteOverrides(),
          child: const MaterialApp(
            home: CandidateDetailPage(candidate: candidateWithoutLocation),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('情報提供: ホットペッパーグルメ'), findsOneWidget);
    });

    testWidgets('観光候補はホットペッパーのクレジットを表示しない', (tester) async {
      const sightseeingCandidate = Candidate(
        id: 'c4',
        category: CandidateCategory.sightseeing,
        name: 'テスト公園',
        catchCopy: 'キャッチコピー',
        reason: 'おすすめ理由',
        walkMinutes: 4,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _favoriteOverrides(),
          child: const MaterialApp(
            home: CandidateDetailPage(candidate: sightseeingCandidate),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('情報提供: ホットペッパーグルメ'), findsNothing);
    });
  });
}
