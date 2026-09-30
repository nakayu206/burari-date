import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// 画像を表示する分、画面下のボタンが小さなテスト画面に収まらないため、縦長の画面にする。
void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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

    testWidgets('駅からの徒歩分数を表示する(直線距離からの概算なので「約」を付ける)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _favoriteOverrides(),
          child: const MaterialApp(
            home: CandidateDetailPage(candidate: candidateWithoutLocation),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('駅から徒歩約3分'), findsOneWidget);
    });

    testWidgets('名前のコピーボタンで、名前をクリップボードに入れる', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _favoriteOverrides(),
          child: const MaterialApp(
            home: CandidateDetailPage(candidate: candidateWithoutLocation),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('名前をコピー'));
      await tester.pump();

      expect(copied, 'テスト洋食屋');
      expect(find.text('名前をコピーしました'), findsOneWidget);
    });

    testWidgets('地図は操作できない見せるだけの地図にする', (tester) async {
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

      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.options.interactionOptions.flags, InteractiveFlag.none);
    });

    testWidgets('画像URLがある候補は、画像を表示する', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _favoriteOverrides(),
          child: const MaterialApp(
            home: CandidateDetailPage(
              candidate: Candidate(
                id: 'c3',
                category: CandidateCategory.gourmet,
                name: 'テスト洋食屋',
                catchCopy: 'キャッチコピー',
                reason: 'おすすめ理由',
                walkMinutes: 3,
                imageUrl: 'https://example.com/shop.jpg',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('画像URLがない・画像の読み込みに失敗した候補は、空の枠を出さず、名前の横のアイコンだけを表示する', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _favoriteOverrides(),
          child: const MaterialApp(
            home: CandidateDetailPage(candidate: candidateWithoutLocation),
          ),
        ),
      );
      await tester.pump();

      // 画像URLなし。
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.ramen_dining_rounded), findsOneWidget);

      // 画像URLはあるが、テスト環境ではネットワークに接続できず読み込みに失敗する。
      await tester.pumpWidget(
        ProviderScope(
          overrides: _favoriteOverrides(),
          child: const MaterialApp(
            home: CandidateDetailPage(
              candidate: Candidate(
                id: 'c4',
                category: CandidateCategory.sightseeing,
                name: 'テスト公園',
                catchCopy: 'キャッチコピー',
                reason: 'おすすめ理由',
                walkMinutes: 3,
                imageUrl: 'https://example.com/broken.jpg',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 読み込みに失敗したら、空の枠は出さず、画像の部品ごと消える。名前の横の
      // カテゴリのアイコンだけが残る。
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.park_rounded), findsOneWidget);
    });

    testWidgets('地図のタイルはAPIキー不要のOpenStreetMapを使う(CARTOは使わない)', (tester) async {
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

      final layer = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(layer.urlTemplate, contains('tile.openstreetmap.org'));
      expect(layer.urlTemplate, isNot(contains('cartocdn')));
      expect(find.textContaining('CARTO'), findsNothing);
    });

    testWidgets('住所がある候補は住所を表示する', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _favoriteOverrides(),
          child: const MaterialApp(
            home: CandidateDetailPage(
              candidate: Candidate(
                id: 'c2',
                category: CandidateCategory.gourmet,
                name: 'テスト洋食屋',
                catchCopy: 'キャッチコピー',
                reason: 'おすすめ理由',
                walkMinutes: 3,
                address: '東京都新宿区1-1-1',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('住所: 東京都新宿区1-1-1'), findsOneWidget);
    });

    testWidgets('住所が無い候補は、住所の行も開発用メッセージも表示しない', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _favoriteOverrides(),
          child: const MaterialApp(
            home: CandidateDetailPage(candidate: candidateWithoutLocation),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('住所'), findsNothing);
      expect(find.textContaining('外部API'), findsNothing);
    });

    testWidgets('候補自体に座標が無くても、到着駅の座標をフォールバックとして地図を表示する', (tester) async {
      _useTallScreen(tester);
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

    testWidgets('候補自体に座標がある場合は、駅と場所の両方を地図に出す', (tester) async {
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

      // 駅と場所の両方のマーカーを出し、両方が入る範囲に地図を合わせる。
      final markers = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers
          .map((m) => (m.point.latitude, m.point.longitude))
          .toList();
      expect(markers, containsAll([(35.69, 139.70), (35.0, 135.0)]));
      expect(markers, hasLength(2));
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.options.initialCameraFit, isNotNull);
      // 駅と場所を結ぶ線を引く。
      expect(find.byType(PolylineLayer), findsOneWidget);
      // 場所のマーカーには候補名、駅のマーカーには「駅」のツールチップを付ける。
      expect(find.byTooltip('テスト公園'), findsOneWidget);
      expect(find.byTooltip('駅'), findsOneWidget);
    });

    testWidgets('場所の座標がない候補は、地図に駅のマーカーだけを出す', (tester) async {
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

      // 場所の座標がない候補は、駅のマーカーだけを出す(場所のピンも線も出さない)。
      expect(find.byTooltip('駅'), findsOneWidget);
      expect(find.byTooltip('テスト洋食屋'), findsNothing);
      expect(find.byType(PolylineLayer), findsNothing);
    });

    testWidgets('地図アプリを開けなかった場合はダイアログで知らせる', (tester) async {
      _useTallScreen(tester);
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
      _useTallScreen(tester);
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
      _useTallScreen(tester);
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
      _useTallScreen(tester);
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
