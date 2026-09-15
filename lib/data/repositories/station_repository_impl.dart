import '../../domain/entities/railway_line.dart';
import '../../domain/entities/station.dart';
import '../../domain/repositories/station_repository.dart';
import '../datasources/local/mock_station_data_source.dart';

class StationRepositoryImpl implements StationRepository {
  StationRepositoryImpl({MockStationDataSource? dataSource})
    : _dataSource = dataSource ?? const MockStationDataSource();

  final MockStationDataSource _dataSource;

  @override
  List<Station> searchStations(String query) {
    if (query.isEmpty) return const [];
    final results = <Station>[];
    for (final line in _dataSource.lines) {
      for (final station in line.stations) {
        if (station.name.contains(query)) results.add(station);
      }
    }
    return results;
  }

  @override
  RailwayLine? findLineForStation(Station station) {
    for (final line in _dataSource.lines) {
      if (line.stations.any((s) => s.id == station.id)) return line;
    }
    return null;
  }
}
