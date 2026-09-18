import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../domain/entities/station.dart';

/// HeartRails Express(無料・APIキー不要の駅データWebサービス)から
/// 駅データを取得するリモートデータソース(Issue #2, #28)。
/// https://express.heartrails.com/api.html
///
/// 実装上の注意点:
/// - 駅名検索の結果は「東京」のように「駅」抜きの表記で返るため、アプリ内の
///   既存表記(「東京駅」)に合わせて末尾に「駅」を補って返す。
/// - 同APIは駅・路線に安定した数値IDを持たないため、[Station.id]には
///   「路線名-駅名」、[Station.lineId]には路線名そのものを用いる(路線名を
///   そのままキーとして扱う)。
/// - `line=`指定時に返る駅の並び順が実際の営業キロ順と一致する保証は
///   公式には明記されていない(路線によっては前後する可能性がある)。
class HeartRailsStationDataSource {
  HeartRailsStationDataSource({http.Client? client})
    : _client = client ?? http.Client();

  static final _baseUri = Uri.parse('https://express.heartrails.com/api/json');

  final http.Client _client;

  /// 駅名の部分一致で駅を検索する(S-02b)。
  Future<List<Station>> searchStationsByName(String query) async {
    final uri = _baseUri.replace(
      queryParameters: {'method': 'getStations', 'name': query},
    );
    final rawList = await _fetchRawStations(uri);
    return _toStations(rawList);
  }

  /// 指定した路線名に属する全駅を、APIが返す並び順のまま取得する。
  /// あわせて、始発・終着が隣接する環状路線(山手線・大阪環状線等)かどうかも
  /// 判定して返す(RunGachaの隣接駅数計算で末端打ち切りにしないため)。
  Future<({List<Station> stations, bool isCircular})> fetchStationsForLine(
    String lineName,
  ) async {
    final uri = _baseUri.replace(
      queryParameters: {'method': 'getStations', 'line': lineName},
    );
    final rawList = await _fetchRawStations(uri);
    return (stations: _toStations(rawList), isCircular: _isCircular(rawList));
  }

  /// 配列末尾の駅のnextが先頭の駅名と一致する場合、環状路線と判定する。
  bool _isCircular(List<Map<String, dynamic>> rawList) {
    if (rawList.length < 3) return false;
    final firstName = rawList.first['name'] as String;
    final lastNext = rawList.last['next'] as String?;
    return lastNext == firstName;
  }

  List<Station> _toStations(List<Map<String, dynamic>> rawList) {
    return [for (var i = 0; i < rawList.length; i++) _toStation(rawList[i], i)];
  }

  Future<List<Map<String, dynamic>>> _fetchRawStations(Uri uri) async {
    final http.Response response;
    try {
      response = await _client.get(uri);
    } on Exception catch (e) {
      throw HeartRailsException('駅データの取得に失敗しました: $e');
    }
    if (response.statusCode != 200) {
      throw HeartRailsException(
        '駅データの取得に失敗しました(status: ${response.statusCode})',
      );
    }

    final Map<String, dynamic> body;
    try {
      body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw HeartRailsException('駅データの解析に失敗しました: $e');
    }

    final responseBody = body['response'] as Map<String, dynamic>?;
    final rawStations = responseBody?['station'];
    if (rawStations == null) return const [];
    // 該当が1件のみの場合、HeartRails Expressはオブジェクト単体を返す
    // (配列ではない)ことがあるため、両方のケースを吸収する。
    final list = rawStations is List ? rawStations : [rawStations];
    return list.cast<Map<String, dynamic>>();
  }

  Station _toStation(Map<String, dynamic> json, int orderIndex) {
    final rawName = json['name'] as String;
    final lineName = json['line'] as String;
    return Station(
      id: '$lineName-$rawName',
      name: '$rawName駅',
      lineId: lineName,
      orderIndex: orderIndex,
      latitude: (json['y'] as num?)?.toDouble(),
      longitude: (json['x'] as num?)?.toDouble(),
    );
  }
}

/// HeartRails Expressへのアクセス失敗(通信エラー/非200応答/解析失敗)を表す。
class HeartRailsException implements Exception {
  HeartRailsException(this.message);

  final String message;

  @override
  String toString() => message;
}
