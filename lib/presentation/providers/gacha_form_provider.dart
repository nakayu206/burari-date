import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/gacha_result.dart';
import '../../domain/entities/railway_line.dart';
import '../../domain/entities/station.dart';
import '../../domain/usecases/run_gacha.dart';
import 'station_providers.dart';

/// S-02 出発駅・路線・駅数範囲選択画面の入力状態。
class GachaFormState {
  const GachaFormState({
    this.departure,
    this.line,
    this.minStops = 2,
    this.maxStops = 7,
    this.direction = GachaDirection.random,
  });

  final Station? departure;
  final RailwayLine? line;
  final int minStops;
  final int maxStops;
  final GachaDirection direction;

  bool get canStartGacha => departure != null && line != null;

  GachaFormState copyWith({
    Station? departure,
    RailwayLine? line,
    int? minStops,
    int? maxStops,
    GachaDirection? direction,
  }) {
    return GachaFormState(
      departure: departure ?? this.departure,
      line: line ?? this.line,
      minStops: minStops ?? this.minStops,
      maxStops: maxStops ?? this.maxStops,
      direction: direction ?? this.direction,
    );
  }
}

class GachaFormNotifier extends Notifier<GachaFormState> {
  @override
  GachaFormState build() => const GachaFormState();

  void selectDeparture(Station station) {
    final line = ref
        .read(stationRepositoryProvider)
        .findLineForStation(station);
    state = state.copyWith(departure: station, line: line);
  }

  void updateStopsRange(int minStops, int maxStops) {
    state = state.copyWith(minStops: minStops, maxStops: maxStops);
  }

  void updateDirection(GachaDirection direction) {
    state = state.copyWith(direction: direction);
  }

  /// 現在の入力状態でガチャを実行する。[canStartGacha]がtrueの場合のみ呼び出すこと。
  GachaResult runGacha() {
    final departure = state.departure;
    final line = state.line;
    assert(
      departure != null && line != null,
      'departure/line must be selected',
    );
    return RunGacha()(
      departure: departure!,
      line: line!,
      minStops: state.minStops,
      maxStops: state.maxStops,
      direction: state.direction,
    );
  }
}

final gachaFormProvider = NotifierProvider<GachaFormNotifier, GachaFormState>(
  GachaFormNotifier.new,
);
