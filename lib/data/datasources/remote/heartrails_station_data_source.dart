import 'dart:async';
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

  /// HeartRails Expressの主な事業者名(路線検索は完全一致のみで、
  /// 「山手線」だけでは「JR山手線」にヒットしないため自動的に補う)。
  static const _commonOperatorPrefixes = [
    'JR',
    '東京メトロ',
    '都営',
    '東急',
    '小田急',
    '京王',
    '西武',
    '東武',
    '京急',
    '京成',
  ];

  /// 路線名で駅を検索する(S-02b)。事業者接頭辞候補のうち最初にヒットした
  /// ものを即返し、全滅時のみ空リスト/通信エラーを伝える。
  Future<List<Station>> searchStationsByLine(String query) async {
    if (query.isEmpty) return const [];
    final candidates = <String>{
      query,
      for (final prefix in _commonOperatorPrefixes) '$prefix$query',
    };

    final completer = Completer<List<Station>>();
    var pending = candidates.length;
    Object? lastError;

    for (final candidate in candidates) {
      _fetchStationsForLineName(candidate).then(
        (stations) {
          if (completer.isCompleted) return;
          if (stations.isNotEmpty) {
            completer.complete(stations);
            return;
          }
          pending--;
          if (pending == 0) {
            if (lastError != null) {
              completer.completeError(lastError!);
            } else {
              completer.complete(const []);
            }
          }
        },
        onError: (Object error) {
          if (completer.isCompleted) return;
          lastError = error;
          pending--;
          if (pending == 0) completer.completeError(error);
        },
      );
    }

    return completer.future;
  }

  Future<List<Station>> _fetchStationsForLineName(String lineName) async {
    final uri = _baseUri.replace(
      queryParameters: {'method': 'getStations', 'line': lineName},
    );
    final rawList = await _fetchRawStations(uri);
    return _toStations(rawList);
  }

  /// 指定した路線名に属する全駅を取得する。あわせて、始発・終着が隣接する
  /// 環状路線(山手線・大阪環状線等)かどうかも判定して返す(RunGachaの
  /// 隣接駅数計算で末端打ち切りにしないため)。
  ///
  /// APIが返す配列の並び順が実際の営業キロ順と一致する保証はないため、
  /// 各駅のprev/nextフィールド(隣の駅名)を辿って並び順を組み立て直す
  /// (CodeRabbit指摘: 配列順をそのまま信頼すべきではない)。
  Future<({List<Station> stations, bool isCircular})> fetchStationsForLine(
    String lineName,
  ) async {
    final uri = _baseUri.replace(
      queryParameters: {'method': 'getStations', 'line': lineName},
    );
    final rawList = await _fetchRawStations(uri);
    final route = _deriveRouteOrder(rawList);
    return (stations: _toStations(route.ordered), isCircular: route.isCircular);
  }

  /// prev/nextのチェーンを辿って、実際の隣接順に駅を並べ替える。
  /// 駅数2以下は「環状」と判定する意味が薄いため対象外とする。
  /// prev/nextの整合が取れずチェーンを最後まで辿れなかった場合は、
  /// (壊れたデータを誤って使うより安全な)APIの返した並び順にフォールバックし、
  /// isCircularはfalse扱いにする。
  ({List<Map<String, dynamic>> ordered, bool isCircular}) _deriveRouteOrder(
    List<Map<String, dynamic>> rawList,
  ) {
    if (rawList.length < 3) return (ordered: rawList, isCircular: false);

    final byName = <String, Map<String, dynamic>>{
      for (final station in rawList) station['name'] as String: station,
    };
    // 駅名が重複していると安全に辿れないため、その場合も元の並びを使う。
    if (byName.length != rawList.length) {
      return (ordered: rawList, isCircular: false);
    }

    // prevがnullの駅(始発)があればそこから辿る。環状路線は全駅にprevが
    // あるため見つからず、その場合は先頭要素から辿り始める。
    final start = rawList.firstWhere(
      (station) => station['prev'] == null,
      orElse: () => rawList.first,
    );

    final ordered = <Map<String, dynamic>>[start];
    final visited = <String>{start['name'] as String};
    var current = start;
    while (ordered.length < rawList.length) {
      final nextName = current['next'] as String?;
      // 終点に到達(直線路線)、または一周して始点に戻った(環状路線)。
      // 環状かどうかは全駅を辿り終えたあとにlast['next']で判定するため、
      // ここでは単にループを打ち切るだけでよい。
      if (nextName == null || nextName == start['name']) break;
      final next = byName[nextName];
      if (next == null || visited.contains(nextName)) {
        break; // prev/nextの整合が取れない、壊れたチェーン
      }
      ordered.add(next);
      visited.add(nextName);
      current = next;
    }

    if (ordered.length != rawList.length) {
      return (ordered: rawList, isCircular: false);
    }
    // 全駅を辿り終えた後、最後の駅のnextが始点と一致するかで環状判定する
    // (ループ途中で打ち切ると最後の駅のnextを確認できないため、ここで行う)。
    final isCircular = ordered.last['next'] == start['name'];
    return (ordered: ordered, isCircular: isCircular);
  }

  List<Station> _toStations(List<Map<String, dynamic>> rawList) {
    return [for (var i = 0; i < rawList.length; i++) _toStation(rawList[i], i)];
  }

  static const _timeout = Duration(seconds: 10);

  Future<List<Map<String, dynamic>>> _fetchRawStations(Uri uri) async {
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on Exception catch (e) {
      // TimeoutExceptionもExceptionを実装しているのでここで一緒に拾える。
      // タイムアウトが無いと、通信が固まった際にローディング表示が
      // 永久に終わらなくなる。
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
