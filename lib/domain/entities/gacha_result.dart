import 'railway_line.dart';
import 'station.dart';

/// 駅ガチャの実行結果(仕様書 6.2 GachaHistory)
class GachaResult {
  const GachaResult({
    required this.departureStation,
    required this.line,
    required this.minStops,
    required this.maxStops,
    required this.direction,
    required this.arrivalStation,
    required this.stopsCount,
    required this.executedAt,
  });

  final Station departureStation;
  final RailwayLine line;
  final int minStops;
  final int maxStops;
  final GachaDirection direction;
  final Station arrivalStation;
  final int stopsCount;
  final DateTime executedAt;
}
