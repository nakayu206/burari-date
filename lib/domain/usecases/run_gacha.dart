import 'dart:math';

import '../entities/gacha_result.dart';
import '../entities/railway_line.dart';
import '../entities/station.dart';

/// 駅ガチャの抽選ロジック(仕様書 2. 主要機能一覧 / 4.2 S-02 バリデーション)。
class RunGacha {
  RunGacha({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 出発駅・路線・駅数範囲・方向からガチャを実行する。
  ///
  /// - 最小駅数が路線内の実際の駅数を超える場合は自動で上限を調整
  /// - 方向指定時に最大駅数が終点を超える場合は終点駅でクリップ
  GachaResult call({
    required Station departure,
    required RailwayLine line,
    required int minStops,
    required int maxStops,
    required GachaDirection direction,
  }) {
    final departureIndex = line.stations.indexWhere(
      (s) => s.id == departure.id,
    );
    assert(departureIndex != -1, 'departure station must belong to line');

    final resolvedDirection = direction == GachaDirection.random
        ? (_random.nextBool() ? GachaDirection.up : GachaDirection.down)
        : direction;

    final stationCount = line.stations.length;
    // 環状路線(山手線・大阪環状線等)は始発・終着が実際には隣接しているため、
    // 配列の端で打ち切らず一周分(stationCount-1駅)まで狙えるようにする。
    final maxReachable = line.isCircular
        ? stationCount - 1
        : resolvedDirection == GachaDirection.up
        ? stationCount - 1 - departureIndex
        : departureIndex;

    final clampedMax = min(maxStops, maxReachable);
    final clampedMin = min(minStops, clampedMax).clamp(0, clampedMax);

    final stopsCount = clampedMax <= clampedMin
        ? clampedMax
        : clampedMin + _random.nextInt(clampedMax - clampedMin + 1);

    final rawArrivalIndex = resolvedDirection == GachaDirection.up
        ? departureIndex + stopsCount
        : departureIndex - stopsCount;
    // Dartの%は除数が正なら常に非負を返す(Euclidean mod)ため、
    // 負の値でも折り返しのインデックス計算にそのまま使える。
    final arrivalIndex = line.isCircular
        ? rawArrivalIndex % stationCount
        : rawArrivalIndex;

    return GachaResult(
      departureStation: departure,
      line: line,
      minStops: minStops,
      maxStops: maxStops,
      direction: resolvedDirection,
      arrivalStation: line.stations[arrivalIndex],
      stopsCount: stopsCount,
      executedAt: DateTime.now(),
    );
  }
}
