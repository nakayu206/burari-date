import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/gacha_history_entry.dart';
import 'package:burari_date/domain/entities/gacha_result.dart';
import 'package:burari_date/domain/entities/railway_line.dart';
import 'package:burari_date/domain/entities/station.dart';

void main() {
  group('GachaHistoryEntry', () {
    test('fromGachaResultは駅・路線の全リストではなく必要な項目だけを抜き出す', () {
      const departure = Station(
        id: 's1',
        name: '中野駅',
        lineId: 'l1',
        orderIndex: 0,
      );
      const arrival = Station(
        id: 's2',
        name: '新宿駅',
        lineId: 'l1',
        orderIndex: 3,
      );
      const line = RailwayLine(
        id: 'l1',
        name: '中央線',
        stations: [departure, arrival],
      );
      final result = GachaResult(
        departureStation: departure,
        line: line,
        minStops: 1,
        maxStops: 5,
        direction: GachaDirection.up,
        arrivalStation: arrival,
        stopsCount: 3,
        executedAt: DateTime(2026, 9, 18, 12, 0),
      );

      final entry = GachaHistoryEntry.fromGachaResult(result);

      expect(entry.departureStationName, '中野駅');
      expect(entry.lineName, '中央線');
      expect(entry.arrivalStationName, '新宿駅');
      expect(entry.stopsCount, 3);
      expect(entry.direction, GachaDirection.up);
      expect(entry.executedAt, DateTime(2026, 9, 18, 12, 0));
    });

    test('toJson/fromJsonが値を保ったまま往復する', () {
      final entry = GachaHistoryEntry(
        departureStationName: '中野駅',
        lineName: '中央線',
        arrivalStationName: '新宿駅',
        stopsCount: 3,
        direction: GachaDirection.down,
        executedAt: DateTime(2026, 9, 18, 12, 0),
      );

      final restored = GachaHistoryEntry.fromJson(entry.toJson());

      expect(restored.departureStationName, entry.departureStationName);
      expect(restored.lineName, entry.lineName);
      expect(restored.arrivalStationName, entry.arrivalStationName);
      expect(restored.stopsCount, entry.stopsCount);
      expect(restored.direction, entry.direction);
      expect(restored.executedAt, entry.executedAt);
    });
  });
}
