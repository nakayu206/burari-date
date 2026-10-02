import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/railway_line.dart';
import 'package:burari_date/domain/entities/station.dart';

void main() {
  Station station(int i) =>
      Station(id: 's$i', name: '$i駅', lineId: 'l', orderIndex: i);
  final stations = [for (var i = 0; i < 4; i++) station(i)];

  group('RailwayLine.reachableDirections', () {
    final line = RailwayLine(id: 'l', name: 'テスト線', stations: stations);

    test('途中の駅は、両方の方面に進める', () {
      expect(line.reachableDirections(stations[1]), {
        GachaDirection.up,
        GachaDirection.down,
      });
    });

    test('終点では、先のない方面(up)に進めない', () {
      expect(line.reachableDirections(stations[3]), {GachaDirection.down});
    });

    test('起点では、先のない方面(down)に進めない', () {
      expect(line.reachableDirections(stations[0]), {GachaDirection.up});
    });

    test('環状路線は、端の駅でも両方の方面に進める', () {
      final circular = RailwayLine(
        id: 'l',
        name: '環状線',
        stations: stations,
        isCircular: true,
      );
      expect(circular.reachableDirections(stations[3]), {
        GachaDirection.up,
        GachaDirection.down,
      });
    });

    test('路線に含まれない駅は、判断できないので両方を返す', () {
      expect(line.reachableDirections(station(9)), {
        GachaDirection.up,
        GachaDirection.down,
      });
    });
  });
}
