import '../../domain/entities/railway_line.dart';
import '../../domain/entities/station.dart';
import '../../domain/repositories/station_repository.dart';
import '../datasources/remote/heartrails_station_data_source.dart';

class StationRepositoryImpl implements StationRepository {
  StationRepositoryImpl({HeartRailsStationDataSource? dataSource})
    : _dataSource = dataSource ?? HeartRailsStationDataSource();

  final HeartRailsStationDataSource _dataSource;

  @override
  Future<List<Station>> searchStations(String query) {
    if (query.isEmpty) return Future.value(const []);
    return _dataSource.searchStationsByName(query);
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
