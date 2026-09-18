import '../../domain/entities/railway_line.dart';
import '../../domain/entities/station.dart';
import '../../domain/repositories/station_repository.dart';
import '../datasources/remote/heartrails_station_data_source.dart';

class StationRepositoryImpl implements StationRepository {
  StationRepositoryImpl({HeartRailsStationDataSource? dataSource})
    : _dataSource = dataSource ?? HeartRailsStationDataSource();

  final HeartRailsStationDataSource _dataSource;

  @override
  Future<List<Station>> searchStations(String query) async {
    if (query.isEmpty) return const [];
    // まず駅名一致を試す(リクエスト1本)。路線名検索は事業者接頭辞の候補分
    // 最大11並列でリクエストするため、駅名一致で十分な結果が得られている
    // 場合はコストの高い路線名検索を省略する(ユーザーフィードバック:
    // 「路線も検索できるようにしたい」/CodeRabbit指摘: 毎回11並列は無駄)。
    final nameResults = await _dataSource.searchStationsByName(query);
    if (nameResults.isNotEmpty) return nameResults;

    final lineResults = await _dataSource.searchStationsByLine(query);
    final byId = <String, Station>{
      for (final station in lineResults) station.id: station,
    };
    return byId.values.toList();
  }

  @override
  Future<RailwayLine?> findLineForStation(Station station) async {
    final result = await _dataSource.fetchStationsForLine(station.lineId);
    if (result.stations.isEmpty) return null;
    return RailwayLine(
      id: station.lineId,
      name: station.lineId,
      stations: result.stations,
      isCircular: result.isCircular,
    );
  }
}
