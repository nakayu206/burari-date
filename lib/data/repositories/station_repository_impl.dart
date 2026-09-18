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
    // 駅名一致と路線名一致を並行して検索し、まとめて返す
    // (ユーザーフィードバック:「路線も検索できるようにしたい」)。
    final results = await Future.wait([
      _dataSource.searchStationsByName(query),
      _dataSource.searchStationsByLine(query),
    ]);
    final byId = <String, Station>{};
    for (final stations in results) {
      for (final station in stations) {
        byId[station.id] = station;
      }
    }
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
