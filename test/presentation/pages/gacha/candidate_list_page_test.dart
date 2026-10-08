import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/candidate.dart';
import 'package:burari_date/domain/entities/gacha_result.dart';
import 'package:burari_date/domain/entities/railway_line.dart';
import 'package:burari_date/domain/entities/station.dart';
import 'package:burari_date/domain/repositories/candidate_repository.dart';
import 'package:burari_date/presentation/pages/gacha/candidate_list_page.dart';
import 'package:burari_date/presentation/widgets/pixel_icon.dart';
import 'package:burari_date/presentation/widgets/pixel_icon_data.dart';
import 'package:burari_date/presentation/providers/auth_providers.dart';
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

    testWidgets('題名・タブ・店名は、ドット書体ではなく、ほかの画面と同じ普通の書体', (tester) async {
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

      // 題名・タブ・店名の文字の、書体の名前に、ドット書体(DotGothic16)が入っていない。
      for (final text in ['おでかけスポット', 'グルメ', '観光', 'テスト洋食屋']) {
        final style = tester.widget<Text>(find.text(text).first).style;
        final family = style?.fontFamily ?? '';
        expect(
          family.contains('DotGothic16'),
          isFalse,
          reason: '「$text」が、ドット書体になっている: $family',
        );
      }
    });

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

      expect(find.text('店舗情報: ホットペッパーグルメ'), findsOneWidget);
    });

    testWidgets('AIが作ったキャッチコピーには「AI紹介」を付け、店名・クレジットには付けない', (tester) async {
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

      // 候補1件につき、1つ(キャッチコピーの上)。
      expect(find.text('AI紹介'), findsOneWidget);
      // ラベルは、キャッチコピーの上にある。
      expect(
        tester.getTopLeft(find.text('AI紹介')).dy,
        lessThan(tester.getTopLeft(find.text(gourmetCandidate.catchCopy)).dy),
      );
      // クレジットは、店舗情報のものであり、AIの文章とは別の文言。
      expect(find.text('店舗情報: ホットペッパーグルメ'), findsOneWidget);
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

      expect(find.text('店舗情報: ホットペッパーグルメ'), findsNothing);
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

    testWidgets('候補ごとに、ジャンルに合うアイコンと予算の目安を表示する', (tester) async {
      const chinese = Candidate(
        id: 'g1',
        category: CandidateCategory.gourmet,
        name: 'テスト中華',
        catchCopy: 'キャッチコピー',
        reason: 'おすすめ理由',
        walkMinutes: 3,
        categoryName: '中華',
        budget: '900円',
      );
      const cafe = Candidate(
        id: 'g2',
        category: CandidateCategory.gourmet,
        name: 'テストカフェ',
        catchCopy: 'キャッチコピー',
        reason: 'おすすめ理由',
        walkMinutes: 5,
        categoryName: 'カフェ・スイーツ',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            candidatesProvider.overrideWith(
              (ref, args) async => [chinese, cafe],
            ),
          ],
          child: MaterialApp(home: CandidateListPage(result: result)),
        ),
      );
      await tester.pumpAndSettle();

      final kinds = tester
          .widgetList<PixelIcon>(find.byType(PixelIcon))
          .map((i) => i.kind)
          .toList();
      expect(kinds, [PixelIconKind.ramen, PixelIconKind.coffee]);
      // 予算があるのは1件だけ。
      expect(find.text('予算の目安 900円'), findsOneWidget);
      expect(find.textContaining('予算の目安'), findsOneWidget);
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

    testWidgets('上限に達したときは「再読み込み」を出さず、案内のボタンを出す', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hasAccountProvider.overrideWithValue(false),
            candidatesProvider.overrideWith(
              (ref, args) async => throw const CandidateLimitException(
                '無料利用の上限(10回)に達しました。継続利用にはアカウント登録と課金が必要です。',
              ),
            ),
          ],
          child: MaterialApp(home: CandidateListPage(result: result)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('アカウント登録と課金'), findsOneWidget);
      expect(find.text('再読み込み'), findsNothing);
    });

    testWidgets('アカウントがあるときは、課金のボタンを出す', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hasAccountProvider.overrideWithValue(true),
            candidatesProvider.overrideWith(
              (ref, args) async =>
                  throw const CandidateLimitException('上限に達しました'),
            ),
          ],
          child: MaterialApp(home: CandidateListPage(result: result)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('課金する'), findsOneWidget);
      expect(find.text('再読み込み'), findsNothing);
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
