import 'dart:convert';
import 'dart:math';

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

    test('実際の山手線APIレスポンスで、配列の並びをシャッフルしても正しい隣接順に復元する', () async {
      // https://express.heartrails.com/api/json?method=getStations&line=JR山手線
      // で実際に取得したレスポンス(2026年時点)。CodeRabbit指摘の「配列順を
      // そのまま信頼すべきではない」を検証するため、意図的に配列順を
      // シャッフルしてprev/nextからの復元が機能することを確認する。
      final rawStations = List<Map<String, dynamic>>.from(
        (jsonDecode(_yamanoteLineResponseJson)
                as Map<String, dynamic>)['response']['station']
            as List,
      )..shuffle(Random(42));
      final shuffledJson = jsonEncode({
        'response': {'station': rawStations},
      });
      final client = MockClient((request) async {
        return http.Response(
          shuffledJson,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final dataSource = HeartRailsStationDataSource(client: client);

      final result = await dataSource.fetchStationsForLine('JR山手線');

      expect(result.isCircular, isTrue);
      // 環状路線には「唯一の正しい先頭」が存在しない(全駅がprev/nextを
      // 持つため)ので、復元結果がどこから始まっていても、品川駅を先頭に
      // 回転させれば正しい隣接順に一致することだけを検証すればよい。
      final names = result.stations.map((s) => s.name).toList();
      final startIndex = names.indexOf('品川駅');
      final rotated = [
        ...names.sublist(startIndex),
        ...names.sublist(0, startIndex),
      ];
      expect(rotated, [
        '品川駅',
        '大崎駅',
        '五反田駅',
        '目黒駅',
        '恵比寿駅',
        '渋谷駅',
        '原宿駅',
        '代々木駅',
        '新宿駅',
        '新大久保駅',
        '高田馬場駅',
        '目白駅',
        '池袋駅',
        '大塚駅',
        '巣鴨駅',
        '駒込駅',
        '田端駅',
        '西日暮里駅',
        '日暮里駅',
        '鶯谷駅',
        '上野駅',
        '御徒町駅',
        '秋葉原駅',
        '神田駅',
        '東京駅',
        '有楽町駅',
        '新橋駅',
        '浜松町駅',
        '田町駅',
        '高輪ゲートウェイ駅',
      ]);
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

/// https://express.heartrails.com/api/json?method=getStations&line=JR山手線
/// の実レスポンス(2026年時点で取得)。
const _yamanoteLineResponseJson = '''
{"response":{"station":[{"name":"品川","prefecture":"東京都","line":"JR山手線","x":139.738999,"y":35.62876,"postal":"1080075","prev":"高輪ゲートウェイ","next":"大崎"},{"name":"大崎","prefecture":"東京都","line":"JR山手線","x":139.728439,"y":35.619772,"postal":"1410032","prev":"品川","next":"五反田"},{"name":"五反田","prefecture":"東京都","line":"JR山手線","x":139.723822,"y":35.625974,"postal":"1410022","prev":"大崎","next":"目黒"},{"name":"目黒","prefecture":"東京都","line":"JR山手線","x":139.715775,"y":35.633923,"postal":"1410021","prev":"五反田","next":"恵比寿"},{"name":"恵比寿","prefecture":"東京都","line":"JR山手線","x":139.71007,"y":35.646684,"postal":"1500013","prev":"目黒","next":"渋谷"},{"name":"渋谷","prefecture":"東京都","line":"JR山手線","x":139.701238,"y":35.658871,"postal":"1500002","prev":"恵比寿","next":"原宿"},{"name":"原宿","prefecture":"東京都","line":"JR山手線","x":139.702592,"y":35.670646,"postal":"1500001","prev":"渋谷","next":"代々木"},{"name":"代々木","prefecture":"東京都","line":"JR山手線","x":139.702042,"y":35.683061,"postal":"1510051","prev":"原宿","next":"新宿"},{"name":"新宿","prefecture":"東京都","line":"JR山手線","x":139.700464,"y":35.689729,"postal":"1600022","prev":"代々木","next":"新大久保"},{"name":"新大久保","prefecture":"東京都","line":"JR山手線","x":139.700261,"y":35.700875,"postal":"1690073","prev":"新宿","next":"高田馬場"},{"name":"高田馬場","prefecture":"東京都","line":"JR山手線","x":139.703715,"y":35.712677,"postal":"1690075","prev":"新大久保","next":"目白"},{"name":"目白","prefecture":"東京都","line":"JR山手線","x":139.706228,"y":35.720476,"postal":"1710031","prev":"高田馬場","next":"池袋"},{"name":"池袋","prefecture":"東京都","line":"JR山手線","x":139.711085,"y":35.730256,"postal":"1710021","prev":"目白","next":"大塚"},{"name":"大塚","prefecture":"東京都","line":"JR山手線","x":139.728584,"y":35.731412,"postal":"1700005","prev":"池袋","next":"巣鴨"},{"name":"巣鴨","prefecture":"東京都","line":"JR山手線","x":139.739303,"y":35.733445,"postal":"1700002","prev":"大塚","next":"駒込"},{"name":"駒込","prefecture":"東京都","line":"JR山手線","x":139.748053,"y":35.736825,"postal":"1700003","prev":"巣鴨","next":"田端"},{"name":"田端","prefecture":"東京都","line":"JR山手線","x":139.761229,"y":35.737781,"postal":"1140013","prev":"駒込","next":"西日暮里"},{"name":"西日暮里","prefecture":"東京都","line":"JR山手線","x":139.766857,"y":35.731954,"postal":"1160013","prev":"田端","next":"日暮里"},{"name":"日暮里","prefecture":"東京都","line":"JR山手線","x":139.771287,"y":35.727908,"postal":"1100001","prev":"西日暮里","next":"鶯谷"},{"name":"鶯谷","prefecture":"東京都","line":"JR山手線","x":139.778015,"y":35.721484,"postal":"1100003","prev":"日暮里","next":"上野"},{"name":"上野","prefecture":"東京都","line":"JR山手線","x":139.777043,"y":35.71379,"postal":"1100005","prev":"鶯谷","next":"御徒町"},{"name":"御徒町","prefecture":"東京都","line":"JR山手線","x":139.774727,"y":35.707282,"postal":"1100005","prev":"上野","next":"秋葉原"},{"name":"秋葉原","prefecture":"東京都","line":"JR山手線","x":139.773288,"y":35.698619,"postal":"1010028","prev":"御徒町","next":"神田"},{"name":"神田","prefecture":"東京都","line":"JR山手線","x":139.770641,"y":35.691173,"postal":"1010044","prev":"秋葉原","next":"東京"},{"name":"東京","prefecture":"東京都","line":"JR山手線","x":139.766103,"y":35.681391,"postal":"1000005","prev":"神田","next":"有楽町"},{"name":"有楽町","prefecture":"東京都","line":"JR山手線","x":139.763806,"y":35.675441,"postal":"1000006","prev":"東京","next":"新橋"},{"name":"新橋","prefecture":"東京都","line":"JR山手線","x":139.758587,"y":35.666195,"postal":"1050004","prev":"有楽町","next":"浜松町"},{"name":"浜松町","prefecture":"東京都","line":"JR山手線","x":139.757135,"y":35.655391,"postal":"1050022","prev":"新橋","next":"田町"},{"name":"田町","prefecture":"東京都","line":"JR山手線","x":139.747575,"y":35.645737,"postal":"1080023","prev":"浜松町","next":"高輪ゲートウェイ"},{"name":"高輪ゲートウェイ","prefecture":"東京都","line":"JR山手線","x":139.740651,"y":35.635476,"postal":"1080075","prev":"田町","next":"品川"}]}}
''';
