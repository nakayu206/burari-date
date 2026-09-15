import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/presentation/providers/gacha_form_provider.dart';

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
}
