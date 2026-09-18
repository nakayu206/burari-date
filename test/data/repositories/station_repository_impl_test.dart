import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:burari_date/data/datasources/remote/heartrails_station_data_source.dart';
import 'package:burari_date/data/repositories/station_repository_impl.dart';
import 'package:burari_date/domain/entities/station.dart';

void main() {
  group('StationRepositoryImpl', () {
    test('searchStationsは空文字列の場合APIを呼ばず空リストを返す', () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('{"response": {}}', 200);
      });
      final repository = StationRepositoryImpl(
        dataSource: HeartRailsStationDataSource(client: client),
      );

      final result = await repository.searchStations('');

      expect(result, isEmpty);
      expect(called, isFalse);
    });

    test('findLineForStationは取得した駅一覧からRailwayLineを組み立てる', () async {
      final client = MockClient((request) async {
        return http.Response(
          '''
          {
            "response": {
              "station": [
                {"name": "東京", "line": "JR山手線", "x": 0, "y": 0},
                {"name": "神田", "line": "JR山手線", "x": 0, "y": 0}
              ]
            }
          }
          ''',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final repository = StationRepositoryImpl(
        dataSource: HeartRailsStationDataSource(client: client),
      );
      const station = Station(
        id: 'JR山手線-東京',
        name: '東京駅',
        lineId: 'JR山手線',
        orderIndex: 0,
      );

      final line = await repository.findLineForStation(station);

      expect(line, isNotNull);
      expect(line!.id, 'JR山手線');
      expect(line.name, 'JR山手線');
      expect(line.stations.map((s) => s.name), ['東京駅', '神田駅']);
    });

    test('該当路線の駅が0件の場合はnullを返す', () async {
      final client = MockClient((request) async {
        return http.Response('{"response": {}}', 200);
      });
      final repository = StationRepositoryImpl(
        dataSource: HeartRailsStationDataSource(client: client),
      );
      const station = Station(
        id: 'x-y',
        name: 'y駅',
        lineId: 'x',
        orderIndex: 0,
      );

      final line = await repository.findLineForStation(station);

      expect(line, isNull);
    });
  });
}
