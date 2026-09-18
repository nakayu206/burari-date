import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/gacha_result.dart';
import '../../domain/entities/railway_line.dart';
import '../../domain/entities/station.dart';
import '../../domain/usecases/run_gacha.dart';
import 'station_providers.dart';

/// スライダー/ステッパーで選択できる駅数範囲の実用上限。
///
/// 路線の実際の長さがこれより長くても、UIではここまでしか選ばせない
/// (長大な路線でスライダーの目盛りが細かくなりすぎて操作しづらくなるのを防ぐ。
/// Issue #38)。
const kMaxSelectableStops = 30;

/// S-02 出発駅・路線・駅数範囲選択画面の入力状態。
class GachaFormState {
  const GachaFormState({
    this.departure,
    this.line,
    this.minStops = 2,
    this.maxStops = 7,
    this.direction = GachaDirection.random,
    this.isLoadingLine = false,
    this.lineError,
  });

  final Station? departure;
  final RailwayLine? line;
  final int minStops;
  final int maxStops;
  final GachaDirection direction;

  /// 出発駅選択後、所属路線の全駅リストを外部APIから取得している間true
  /// (Issue #2: HeartRails Expressへのリモートアクセスに置き換えたため)。
  final bool isLoadingLine;

  /// 路線データの取得に失敗した場合のメッセージ。画面内表示用
  /// (docs/コード規約.md: 受動的なロード失敗は画面内表示でよい)。
  final String? lineError;

  bool get canStartGacha => departure != null && line != null;

  /// 現在選択中の路線に対する駅数範囲の実用上限(kMaxSelectableStops参照)。
  int get maxSelectableStops {
    final line = this.line;
    if (line == null) return kMaxSelectableStops;
    final lineMax = line.stations.length - 1;
    return lineMax < kMaxSelectableStops ? lineMax : kMaxSelectableStops;
  }

  GachaFormState copyWith({
    Station? departure,
    RailwayLine? line,
    int? minStops,
    int? maxStops,
    GachaDirection? direction,
    bool? isLoadingLine,
    String? lineError,
  }) {
    return GachaFormState(
      departure: departure ?? this.departure,
      line: line ?? this.line,
      minStops: minStops ?? this.minStops,
      maxStops: maxStops ?? this.maxStops,
      direction: direction ?? this.direction,
      isLoadingLine: isLoadingLine ?? this.isLoadingLine,
      lineError: lineError ?? this.lineError,
    );
  }
}

class GachaFormNotifier extends Notifier<GachaFormState> {
  @override
  GachaFormState build() => const GachaFormState();

  /// [selectDeparture]の呼び出しを識別する通し番号。駅名だけでは、同じ駅を
  /// ローディング中に再選択した場合に新旧どちらのリクエストか区別できない
  /// ため、単調増加のトークンで「一番最後に発行したリクエストか」を判定する。
  int _selectDepartureRequestId = 0;

  /// 出発駅を選び、所属路線の全駅データをHeartRails Expressから取得する
  /// (Issue #2)。ネットワークI/Oを伴うため、取得完了までは[isLoadingLine]、
  /// 失敗時は[lineError]で画面側に伝える。
  Future<void> selectDeparture(Station station) async {
    final requestId = ++_selectDepartureRequestId;
    state = GachaFormState(
      departure: station,
      minStops: state.minStops,
      maxStops: state.maxStops,
      direction: state.direction,
      isLoadingLine: true,
    );
    RailwayLine? line;
    String? error;
    try {
      line = await ref
          .read(stationRepositoryProvider)
          .findLineForStation(station);
      if (line == null) error = '路線情報を取得できませんでした';
    } on Exception catch (e) {
      error = '路線情報の取得に失敗しました: $e';
    }

    // awaitの間に別のselectDeparture呼び出しが発行されていたら、この結果は
    // 古いので捨てる(同じ駅の再選択も含めて、最新のリクエストだけを反映)。
    if (requestId != _selectDepartureRequestId) return;

    final maxSelectable = line == null
        ? kMaxSelectableStops
        : (line.stations.length - 1).clamp(0, kMaxSelectableStops);
    final newMax = state.maxStops > maxSelectable
        ? maxSelectable
        : state.maxStops;
    final newMin = state.minStops > newMax ? newMax : state.minStops;
    state = GachaFormState(
      departure: station,
      line: line,
      minStops: newMin,
      maxStops: newMax,
      direction: state.direction,
      lineError: error,
    );
  }

  void updateStopsRange(int minStops, int maxStops) {
    state = state.copyWith(minStops: minStops, maxStops: maxStops);
  }

  void updateDirection(GachaDirection direction) {
    state = state.copyWith(direction: direction);
  }

  /// 最小駅数を1駅減らす(1駅未満にはしない)。
  void decrementMinStops() {
    final next = (state.minStops - 1).clamp(1, state.maxStops);
    state = state.copyWith(minStops: next);
  }

  /// 最小駅数を1駅増やす(最大駅数は超えない)。
  void incrementMinStops() {
    final next = (state.minStops + 1).clamp(1, state.maxStops);
    state = state.copyWith(minStops: next);
  }

  /// 最大駅数を1駅減らす(最小駅数は下回らない)。
  void decrementMaxStops() {
    final next = (state.maxStops - 1).clamp(
      state.minStops,
      state.maxSelectableStops,
    );
    state = state.copyWith(maxStops: next);
  }

  /// 最大駅数を1駅増やす(maxSelectableStopsは超えない)。
  void incrementMaxStops() {
    final next = (state.maxStops + 1).clamp(
      state.minStops,
      state.maxSelectableStops,
    );
    state = state.copyWith(maxStops: next);
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
