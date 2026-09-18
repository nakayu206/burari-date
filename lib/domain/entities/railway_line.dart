import 'station.dart';

/// 路線マスタ(仕様書 6.1 Line)。駅は起点→終点の順で保持する。
class RailwayLine {
  const RailwayLine({
    required this.id,
    required this.name,
    required this.stations,
    this.isCircular = false,
  });

  final String id;
  final String name;
  final List<Station> stations;

  /// 山手線・大阪環状線のような環状路線の場合true。
  /// 始発・終着が実際には隣接しているため、駅ガチャの隣接駅数計算(RunGacha)
  /// で末端打ち切りではなく一周する計算に切り替える必要がある。
  final bool isCircular;

  Station get startTerminus => stations.first;
  Station get endTerminus => stations.last;
}

/// S-02 の方面セレクタ(仕様書 4.2 S-02)
enum GachaDirection { up, down, random }
