import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:burari_date/data/repositories/gacha_history_repository_impl.dart';
import 'package:burari_date/domain/entities/gacha_history_entry.dart';
import 'package:burari_date/domain/entities/railway_line.dart';

GachaHistoryEntry _entry(String name, DateTime executedAt) {
  return GachaHistoryEntry(
    departureStationName: 'x',
    lineName: 'l',
    arrivalStationName: name,
    stopsCount: 1,
    direction: GachaDirection.up,
    executedAt: executedAt,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GachaHistoryRepositoryImpl', () {
    test('loadHistoryは新しい順に並べ替えて返す', () async {
      final repository = GachaHistoryRepositoryImpl();
      await repository.addEntry(_entry('古い', DateTime(2026, 1, 1)));
      await repository.addEntry(_entry('新しい', DateTime(2026, 6, 1)));
      await repository.addEntry(_entry('中間', DateTime(2026, 3, 1)));

      final history = await repository.loadHistory();

      expect(history.map((e) => e.arrivalStationName), ['新しい', '中間', '古い']);
    });

    test('保存件数がmaxEntriesを超えると、古いものから捨てられる', () async {
      final repository = GachaHistoryRepositoryImpl();
      for (var i = 0; i < GachaHistoryRepositoryImpl.maxEntries + 5; i++) {
        await repository.addEntry(
          _entry('駅$i', DateTime(2026, 1, 1).add(Duration(days: i))),
        );
      }

      final history = await repository.loadHistory();

      expect(history, hasLength(GachaHistoryRepositoryImpl.maxEntries));
      // 一番新しく追加したものが先頭に残っているはず。
      expect(
        history.first.arrivalStationName,
        '駅${GachaHistoryRepositoryImpl.maxEntries + 4}',
      );
    });

    test('同時にaddEntryを呼んでも両方保存される(直列化されている)', () async {
      final repository = GachaHistoryRepositoryImpl();

      final future1 = repository.addEntry(_entry('A', DateTime(2026, 1, 1)));
      final future2 = repository.addEntry(_entry('B', DateTime(2026, 1, 2)));
      await Future.wait([future1, future2]);

      final history = await repository.loadHistory();

      expect(
        history.map((e) => e.arrivalStationName),
        unorderedEquals(['A', 'B']),
      );
    });
  });
}
