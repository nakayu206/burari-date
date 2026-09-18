import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/railway_line.dart';
import 'package:burari_date/domain/entities/station.dart';
import 'package:burari_date/domain/repositories/station_repository.dart';
import 'package:burari_date/presentation/providers/gacha_form_provider.dart';
import 'package:burari_date/presentation/providers/station_providers.dart';

/// テスト用のフェイクリポジトリ。findLineForStationの完了タイミングと結果を
/// 外から制御できるようにする(ローディング中の状態を検証するため)。
class _FakeStationRepository implements StationRepository {
  Completer<RailwayLine?>? pendingFindLine;

  @override
  Future<List<Station>> searchStations(String query) async => const [];

  @override
  Future<RailwayLine?> findLineForStation(Station station) {
    final completer = Completer<RailwayLine?>();
    pendingFindLine = completer;
    return completer.future;
  }
}

void main() {
  group('GachaFormNotifier stops steppers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('最小駅数は1駅未満に減らせない', () {
      final notifier = container.read(gachaFormProvider.notifier);
      for (var i = 0; i < 5; i++) {
        notifier.decrementMinStops();
      }
      expect(container.read(gachaFormProvider).minStops, 1);
    });

    test('最小駅数は最大駅数を超えて増やせない', () {
      final notifier = container.read(gachaFormProvider.notifier);
      for (var i = 0; i < 20; i++) {
        notifier.incrementMinStops();
      }
      final state = container.read(gachaFormProvider);
      expect(state.minStops, state.maxStops);
    });

    test('最大駅数はmaxSelectableStopsを超えて増やせない', () {
      final notifier = container.read(gachaFormProvider.notifier);
      for (var i = 0; i < 50; i++) {
        notifier.incrementMaxStops();
      }
      final state = container.read(gachaFormProvider);
      expect(state.maxStops, kMaxSelectableStops);
    });

    test('最大駅数は最小駅数を下回らない', () {
      final notifier = container.read(gachaFormProvider.notifier);
      for (var i = 0; i < 20; i++) {
        notifier.decrementMaxStops();
      }
      final state = container.read(gachaFormProvider);
      expect(state.maxStops, state.minStops);
    });
  });

  group('GachaFormNotifier selectDeparture のローディング/エラー状態', () {
    test('路線取得中に無関係な操作をしても isLoadingLine が false に戻らない', () async {
      final fakeRepository = _FakeStationRepository();
      final container = ProviderContainer(
        overrides: [
          stationRepositoryProvider.overrideWithValue(fakeRepository),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(gachaFormProvider.notifier);
      const station = Station(
        id: 's-x',
        name: 'x駅',
        lineId: 'line-x',
        orderIndex: 0,
      );

      final future = notifier.selectDeparture(station);
      expect(container.read(gachaFormProvider).isLoadingLine, isTrue);

      // 路線取得が完了する前に、無関係な状態更新(copyWith経由)を挟む。
      notifier.updateStopsRange(2, 6);
      expect(
        container.read(gachaFormProvider).isLoadingLine,
        isTrue,
        reason: 'copyWithがisLoadingLineを保持できていない可能性がある',
      );

      fakeRepository.pendingFindLine!.complete(null);
      await future;
      expect(container.read(gachaFormProvider).isLoadingLine, isFalse);
      expect(container.read(gachaFormProvider).lineError, isNotNull);
    });

    test('路線取得エラー後に無関係な操作をしても lineError が消えない', () async {
      final fakeRepository = _FakeStationRepository();
      final container = ProviderContainer(
        overrides: [
          stationRepositoryProvider.overrideWithValue(fakeRepository),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(gachaFormProvider.notifier);
      const station = Station(
        id: 's-y',
        name: 'y駅',
        lineId: 'line-y',
        orderIndex: 0,
      );

      final future = notifier.selectDeparture(station);
      fakeRepository.pendingFindLine!.complete(null);
      await future;
      expect(container.read(gachaFormProvider).lineError, isNotNull);

      notifier.incrementMinStops();

      expect(
        container.read(gachaFormProvider).lineError,
        isNotNull,
        reason: 'copyWithがlineErrorを保持できていない可能性がある',
      );
    });
  });
}
