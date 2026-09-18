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

  group('RunGacha 環状路線(isCircular)', () {
    final circularLine = RailwayLine(
      id: 'line_loop',
      name: '環状線',
      isCircular: true,
      stations: const [
        Station(id: 'c0', name: '0駅', lineId: 'line_loop', orderIndex: 0),
        Station(id: 'c1', name: '1駅', lineId: 'line_loop', orderIndex: 1),
        Station(id: 'c2', name: '2駅', lineId: 'line_loop', orderIndex: 2),
        Station(id: 'c3', name: '3駅', lineId: 'line_loop', orderIndex: 3),
        Station(id: 'c4', name: '4駅', lineId: 'line_loop', orderIndex: 4),
      ],
    );

    test('up方向で終点を超える駅数指定でも、先頭側に折り返して到達できる', () {
      // 出発駅3から3駅隣(up)は、直線扱いなら終点(4)で打ち切られるが、
      // 環状路線なら3→4→0→1と進み、到着は1駅(index 1)になるはず。
      final result = RunGacha()(
        departure: circularLine.stations[3],
        line: circularLine,
        minStops: 3,
        maxStops: 3,
        direction: GachaDirection.up,
      );

      expect(result.stopsCount, 3);
      expect(result.arrivalStation, circularLine.stations[1]);
    });

    test('down方向で起点を超える駅数指定でも、終点側に折り返して到達できる', () {
      // 出発駅1から3駅隣(down)は、直線扱いなら起点(0)で打ち切られるが、
      // 環状路線なら1→0→4→3と進み、到着は3駅(index 3)になるはず。
      final result = RunGacha()(
        departure: circularLine.stations[1],
        line: circularLine,
        minStops: 3,
        maxStops: 3,
        direction: GachaDirection.down,
      );

      expect(result.stopsCount, 3);
      expect(result.arrivalStation, circularLine.stations[3]);
    });

    test('駅数の総数以上は指定しても一周分(駅数-1)で頭打ちになる', () {
      final result = RunGacha()(
        departure: circularLine.stations[0],
        line: circularLine,
        minStops: 10,
        maxStops: 20,
        direction: GachaDirection.up,
      );

      expect(result.stopsCount, circularLine.stations.length - 1);
    });
  });
}
