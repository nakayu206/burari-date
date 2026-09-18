import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:burari_date/data/datasources/local/gacha_history_local_data_source.dart';
import 'package:burari_date/domain/entities/gacha_history_entry.dart';
import 'package:burari_date/domain/entities/railway_line.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GachaHistoryLocalDataSource', () {
    test('何も保存していない場合、loadは空リストを返す', () async {
      const dataSource = GachaHistoryLocalDataSource();

      final entries = await dataSource.load();

      expect(entries, isEmpty);
    });

    test('saveした内容をloadでそのまま取り出せる', () async {
      const dataSource = GachaHistoryLocalDataSource();
      final entry = GachaHistoryEntry(
        departureStationName: '中野駅',
        lineName: '中央線',
        arrivalStationName: '新宿駅',
        stopsCount: 3,
        direction: GachaDirection.up,
        executedAt: DateTime(2026, 9, 18),
      );

      await dataSource.save([entry]);
      final loaded = await dataSource.load();

      expect(loaded, hasLength(1));
      expect(loaded.single.arrivalStationName, '新宿駅');
    });

    test('saveは以前の内容を置き換える(追記ではない)', () async {
      const dataSource = GachaHistoryLocalDataSource();
      final first = GachaHistoryEntry(
        departureStationName: 'a',
        lineName: 'l',
        arrivalStationName: 'b',
        stopsCount: 1,
        direction: GachaDirection.up,
        executedAt: DateTime(2026, 1, 1),
      );
      final second = GachaHistoryEntry(
        departureStationName: 'c',
        lineName: 'l',
        arrivalStationName: 'd',
        stopsCount: 2,
        direction: GachaDirection.down,
        executedAt: DateTime(2026, 1, 2),
      );

      await dataSource.save([first]);
      await dataSource.save([second]);
      final loaded = await dataSource.load();

      expect(loaded, hasLength(1));
      expect(loaded.single.arrivalStationName, 'd');
    });

    test('壊れたエントリが1件混ざっていても、他の正常なエントリは読み込める', () async {
      final prefs = await SharedPreferences.getInstance();
      final validEntry = GachaHistoryEntry(
        departureStationName: 'x',
        lineName: 'l',
        arrivalStationName: 'y',
        stopsCount: 1,
        direction: GachaDirection.up,
        executedAt: DateTime(2026, 1, 1),
      );
      // キー名はGachaHistoryLocalDataSourceの内部キーと一致させる必要がある。
      await prefs.setStringList('gacha_history_entries', [
        '{"broken": true}',
        jsonEncode(validEntry.toJson()),
      ]);
      const dataSource = GachaHistoryLocalDataSource();

      final entries = await dataSource.load();

      expect(entries, hasLength(1));
      expect(entries.single.arrivalStationName, 'y');
    });
  });
}
