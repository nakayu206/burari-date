import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/data/datasources/cloud/gacha_history_firestore_data_source.dart';
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
  group('GachaHistoryRepositoryImpl', () {
    test('addEntryで保存した内容をloadHistoryで新しい順に取得できる', () async {
      final repository = GachaHistoryRepositoryImpl(
        dataSource: GachaHistoryFirestoreDataSource(
          firestore: FakeFirebaseFirestore(),
          uid: 'user1',
        ),
      );

      await repository.addEntry(_entry('古い', DateTime(2026, 1, 1)));
      await repository.addEntry(_entry('新しい', DateTime(2026, 6, 1)));

      final history = await repository.loadHistory();

      expect(history.map((e) => e.arrivalStationName), ['新しい', '古い']);
    });
  });
}
