import 'station.dart';

/// 路線マスタ(仕様書 6.1 Line)。駅は起点→終点の順で保持する。
class RailwayLine {
  const RailwayLine({
    required this.id,
    required this.name,
    required this.stations,
  });

  final String id;
  final String name;
  final List<Station> stations;

  Station get startTerminus => stations.first;
  Station get endTerminus => stations.last;
}

/// S-02 の方面セレクタ(仕様書 4.2 S-02)
enum GachaDirection { up, down, random }
