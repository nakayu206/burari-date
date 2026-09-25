import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/data/datasources/cloud/gacha_history_firestore_data_source.dart';
import 'package:burari_date/domain/entities/gacha_history_entry.dart';
import 'package:burari_date/domain/entities/railway_line.dart';

GachaHistoryEntry _entry(DateTime executedAt) {
  return GachaHistoryEntry(
    departureStationName: '出発駅',
    lineName: 'テスト線',
    arrivalStationName: '到着駅',
    stopsCount: 1,
    direction: GachaDirection.up,
    executedAt: executedAt,
  );
}

void main() {
  group('GachaHistoryFirestoreDataSource', () {
    test('addで保存した内容をloadで取得できる', () async {
      final dataSource = GachaHistoryFirestoreDataSource(
        firestore: FakeFirebaseFirestore(),
        uid: 'user1',
      );

      await dataSource.add(_entry(DateTime(2026, 1, 1)));

      final entries = await dataSource.load();
      expect(entries, hasLength(1));
    });

    test('loadは新しい順に並べ替えて返す', () async {
      final dataSource = GachaHistoryFirestoreDataSource(
        firestore: FakeFirebaseFirestore(),
        uid: 'user1',
      );
      await dataSource.add(_entry(DateTime(2026, 1, 1)));
      await dataSource.add(_entry(DateTime(2026, 6, 1)));

      final entries = await dataSource.load();

      expect(entries.map((e) => e.executedAt), [
        DateTime(2026, 6, 1),
        DateTime(2026, 1, 1),
      ]);
    });

    test('保存件数がmaxEntriesを超えると、古いものから捨てられる', () async {
      final dataSource = GachaHistoryFirestoreDataSource(
        firestore: FakeFirebaseFirestore(),
        uid: 'user1',
      );
      for (var i = 0; i < GachaHistoryFirestoreDataSource.maxEntries + 5; i++) {
        await dataSource.add(_entry(DateTime(2026, 1, 1 + i)));
      }

      final entries = await dataSource.load();

      expect(entries, hasLength(GachaHistoryFirestoreDataSource.maxEntries));
      expect(
        entries.first.executedAt,
        DateTime(2026, 1, 1 + GachaHistoryFirestoreDataSource.maxEntries + 4),
      );
    });
  });
}
