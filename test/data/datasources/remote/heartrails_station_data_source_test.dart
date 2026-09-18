import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:burari_date/data/datasources/remote/heartrails_station_data_source.dart';

void main() {
  group('HeartRailsStationDataSource.searchStationsByName', () {
    test('複数駅がヒットした場合、駅名に「駅」を補い順序通りにStationへ変換する', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['method'], 'getStations');
        expect(request.url.queryParameters['name'], '東京');
        return http.Response(
          '''
          {
            "response": {
              "station": [
                {"name": "東京", "line": "JR山手線", "x": 139.767, "y": 35.681, "prefecture": "東京都"},
                {"name": "東京", "line": "JR東海道線", "x": 139.767, "y": 35.681, "prefecture": "東京都"}
              ]
            }
          }
          ''',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final dataSource = HeartRailsStationDataSource(client: client);

      final stations = await dataSource.searchStationsByName('東京');

      expect(stations, hasLength(2));
      expect(stations[0].name, '東京駅');
      expect(stations[0].lineId, 'JR山手線');
      expect(stations[0].id, 'JR山手線-東京');
      expect(stations[0].orderIndex, 0);
      expect(stations[0].latitude, 35.681);
      expect(stations[0].longitude, 139.767);
      expect(stations[1].lineId, 'JR東海道線');
      expect(stations[1].orderIndex, 1);
    });

    test('該当が1件のみの場合、station がオブジェクト単体でもリストとして扱う', () async {
      final client = MockClient((request) async {
        return http.Response(
          '''
          {
            "response": {
              "station": {"name": "渋谷", "line": "JR山手線", "x": 139.70, "y": 35.65}
            }
          }
          ''',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final dataSource = HeartRailsStationDataSource(client: client);

      final stations = await dataSource.searchStationsByName('渋谷');

      expect(stations, hasLength(1));
      expect(stations.single.name, '渋谷駅');
    });

    test('該当なしの場合は空リストを返す', () async {
      final client = MockClient((request) async {
        return http.Response('{"response": {}}', 200);
      });
      final dataSource = HeartRailsStationDataSource(client: client);

      final stations = await dataSource.searchStationsByName('存在しない駅名');

      expect(stations, isEmpty);
    });

    test('非200応答の場合はHeartRailsExceptionを投げる', () async {
      final client = MockClient((request) async {
        return http.Response('error', 500);
      });
      final dataSource = HeartRailsStationDataSource(client: client);

      expect(
        () => dataSource.searchStationsByName('東京'),
        throwsA(isA<HeartRailsException>()),
      );
    });
  });

  group('HeartRailsStationDataSource.fetchStationsForLine', () {
    test('line指定で駅一覧を取得し、APIが返す順序を維持する', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['line'], 'JR山手線');
        return http.Response(
          '''
          {
            "response": {
              "station": [
                {"name": "東京", "line": "JR山手線", "x": 0, "y": 0, "next": "神田"},
                {"name": "神田", "line": "JR山手線", "x": 0, "y": 0, "next": "秋葉原"},
                {"name": "秋葉原", "line": "JR山手線", "x": 0, "y": 0, "next": "御徒町"}
              ]
            }
          }
          ''',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final dataSource = HeartRailsStationDataSource(client: client);

      final result = await dataSource.fetchStationsForLine('JR山手線');

      expect(result.stations.map((s) => s.name), ['東京駅', '神田駅', '秋葉原駅']);
      expect(result.stations.map((s) => s.orderIndex), [0, 1, 2]);
      expect(result.isCircular, isFalse);
    });

    test('末尾の駅のnextが先頭の駅名と一致する場合、環状路線と判定する', () async {
      final client = MockClient((request) async {
        return http.Response(
          '''
          {
            "response": {
              "station": [
                {"name": "品川", "line": "JR山手線", "x": 0, "y": 0, "next": "大崎"},
                {"name": "大崎", "line": "JR山手線", "x": 0, "y": 0, "next": "五反田"},
                {"name": "五反田", "line": "JR山手線", "x": 0, "y": 0, "next": "品川"}
              ]
            }
          }
          ''',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final dataSource = HeartRailsStationDataSource(client: client);

      final result = await dataSource.fetchStationsForLine('JR山手線');

      expect(result.isCircular, isTrue);
    });

    test('駅数が2以下の場合は環状路線と判定しない', () async {
      final client = MockClient((request) async {
        return http.Response(
          '''
          {
            "response": {
              "station": [
                {"name": "品川", "line": "x", "x": 0, "y": 0, "next": "大崎"},
                {"name": "大崎", "line": "x", "x": 0, "y": 0, "next": "品川"}
              ]
            }
          }
          ''',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final dataSource = HeartRailsStationDataSource(client: client);

      final result = await dataSource.fetchStationsForLine('x');

      expect(result.isCircular, isFalse);
    });
  });
}
