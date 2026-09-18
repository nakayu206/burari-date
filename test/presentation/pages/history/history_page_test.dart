import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/gacha_history_entry.dart';
import 'package:burari_date/domain/entities/railway_line.dart';
import 'package:burari_date/presentation/pages/history/history_page.dart';
import 'package:burari_date/presentation/providers/gacha_history_providers.dart';

void main() {
  group('HistoryPage', () {
    testWidgets('履歴が0件の場合は空状態を表示する', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gachaHistoryProvider.overrideWith((ref) async => const []),
          ],
          child: const MaterialApp(home: HistoryPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('まだガチャの履歴がありません'), findsOneWidget);
    });

    testWidgets('履歴を新しい順に一覧表示する', (tester) async {
      final entries = [
        GachaHistoryEntry(
          departureStationName: '中野駅',
          lineName: '中央線',
          arrivalStationName: '新宿駅',
          stopsCount: 3,
          direction: GachaDirection.up,
          executedAt: DateTime(2026, 9, 18),
        ),
        GachaHistoryEntry(
          departureStationName: '渋谷駅',
          lineName: '山手線',
          arrivalStationName: '恵比寿駅',
          stopsCount: 1,
          direction: GachaDirection.down,
          executedAt: DateTime(2026, 9, 10),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gachaHistoryProvider.overrideWith((ref) async => entries),
          ],
          child: const MaterialApp(home: HistoryPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('新宿駅'), findsOneWidget);
      expect(find.text('中野駅から3駅隣(up方面)'), findsOneWidget);
      expect(find.text('9/18'), findsOneWidget);
      expect(find.text('恵比寿駅'), findsOneWidget);
      expect(find.text('渋谷駅から1駅隣(down方面)'), findsOneWidget);
    });

    testWidgets('読み込み中はローディング表示になる', (tester) async {
      final completer = Completer<List<GachaHistoryEntry>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gachaHistoryProvider.overrideWith((ref) => completer.future),
          ],
          child: const MaterialApp(home: HistoryPage()),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(const []);
      await tester.pumpAndSettle();
    });

    testWidgets('読み込みに失敗した場合はエラーメッセージと再読み込みボタンを画面内表示する', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gachaHistoryProvider.overrideWith(
              (ref) => Future<List<GachaHistoryEntry>>.error('boom'),
            ),
          ],
          child: const MaterialApp(home: HistoryPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('履歴を読み込めませんでした'), findsOneWidget);
      expect(find.text('再読み込み'), findsOneWidget);
    });

    testWidgets('再読み込みボタンをタップすると履歴の取得をやり直す', (tester) async {
      var attempt = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gachaHistoryProvider.overrideWith((ref) {
              attempt++;
              if (attempt == 1) {
                return Future<List<GachaHistoryEntry>>.error('boom');
              }
              return Future.value(const []);
            }),
          ],
          child: const MaterialApp(home: HistoryPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('履歴を読み込めませんでした'), findsOneWidget);

      await tester.tap(find.text('再読み込み'));
      await tester.pumpAndSettle();

      expect(find.text('履歴を読み込めませんでした'), findsNothing);
      expect(find.text('まだガチャの履歴がありません'), findsOneWidget);
    });
  });
}
