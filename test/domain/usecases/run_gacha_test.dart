import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/railway_line.dart';
import 'package:burari_date/domain/entities/station.dart';
import 'package:burari_date/domain/usecases/run_gacha.dart';

void main() {
  final line = RailwayLine(
    id: 'line_test',
    name: 'テスト線',
    stations: const [
      Station(id: 's0', name: '0駅', lineId: 'line_test', orderIndex: 0),
      Station(id: 's1', name: '1駅', lineId: 'line_test', orderIndex: 1),
      Station(id: 's2', name: '2駅', lineId: 'line_test', orderIndex: 2),
      Station(id: 's3', name: '3駅', lineId: 'line_test', orderIndex: 3),
      Station(id: 's4', name: '4駅', lineId: 'line_test', orderIndex: 4),
    ],
  );

  group('RunGacha', () {
    test('up方向では出発駅より終点寄りの駅が選ばれる', () {
      final result = RunGacha()(
        departure: line.stations[0],
        line: line,
        minStops: 1,
        maxStops: 3,
        direction: GachaDirection.up,
      );

      expect(result.direction, GachaDirection.up);
      expect(result.stopsCount, inInclusiveRange(1, 3));
      expect(result.arrivalStation.orderIndex, 0 + result.stopsCount);
    });

    test('down方向では出発駅より起点寄りの駅が選ばれる', () {
      final result = RunGacha()(
        departure: line.stations[4],
        line: line,
        minStops: 1,
        maxStops: 3,
        direction: GachaDirection.down,
      );

      expect(result.direction, GachaDirection.down);
      expect(result.arrivalStation.orderIndex, 4 - result.stopsCount);
    });

    test('終点を超える駅数指定は終点駅でクリップされる', () {
      final result = RunGacha()(
        departure: line.stations[3],
        line: line,
        minStops: 5,
        maxStops: 10,
        direction: GachaDirection.up,
      );

      expect(result.arrivalStation, line.endTerminus);
    });

    test('random方向はupかdownのいずれかに解決される', () {
      final result = RunGacha()(
        departure: line.stations[2],
        line: line,
        minStops: 1,
        maxStops: 1,
        direction: GachaDirection.random,
      );

      expect(result.direction, isNot(GachaDirection.random));
    });
  });
}
