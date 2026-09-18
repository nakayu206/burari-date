import 'gacha_result.dart';
import 'railway_line.dart';

/// 駅ガチャの実行履歴(仕様書 6.2 GachaHistory)。S-07 履歴画面に表示する。
///
/// [GachaResult]は駅・路線を丸ごと([Station]/[RailwayLine]、路線内の全駅
/// リストを含む)保持しているため、そのまま永続化すると無駄が大きい。
/// 履歴表示に必要な項目だけを平坦なフィールドとして持つ、保存専用の
/// 軽量なエントリとして分離している。
class GachaHistoryEntry {
  const GachaHistoryEntry({
    required this.departureStationName,
    required this.lineName,
    required this.arrivalStationName,
    required this.stopsCount,
    required this.direction,
    required this.executedAt,
  });

  factory GachaHistoryEntry.fromGachaResult(GachaResult result) {
    return GachaHistoryEntry(
      departureStationName: result.departureStation.name,
      lineName: result.line.name,
      arrivalStationName: result.arrivalStation.name,
      stopsCount: result.stopsCount,
      direction: result.direction,
      executedAt: result.executedAt,
    );
  }

  factory GachaHistoryEntry.fromJson(Map<String, dynamic> json) {
    return GachaHistoryEntry(
      departureStationName: json['departureStationName'] as String,
      lineName: json['lineName'] as String,
      arrivalStationName: json['arrivalStationName'] as String,
      stopsCount: json['stopsCount'] as int,
      direction: GachaDirection.values.byName(json['direction'] as String),
      executedAt: DateTime.parse(json['executedAt'] as String),
    );
  }

  final String departureStationName;
  final String lineName;
  final String arrivalStationName;
  final int stopsCount;
  final GachaDirection direction;
  final DateTime executedAt;

  Map<String, dynamic> toJson() {
    return {
      'departureStationName': departureStationName,
      'lineName': lineName,
      'arrivalStationName': arrivalStationName,
      'stopsCount': stopsCount,
      'direction': direction.name,
      'executedAt': executedAt.toIso8601String(),
    };
  }
}
