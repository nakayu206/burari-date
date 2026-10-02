import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/railway_line.dart';
import 'package:burari_date/domain/entities/station.dart';
import 'package:burari_date/domain/repositories/station_repository.dart';
import 'package:burari_date/presentation/pages/gacha/station_select_page.dart';
import 'package:burari_date/presentation/providers/gacha_form_provider.dart';
import 'package:burari_date/presentation/providers/station_providers.dart';

class _FixedLineRepository implements StationRepository {
  const _FixedLineRepository(this.line);

  final RailwayLine line;

  @override
  Future<List<Station>> searchStations(String query) async => const [];

  @override
  Future<RailwayLine?> findLineForStation(Station station) async => line;
}

void main() {
  const stations = [
    Station(id: 'a', name: '起点駅', lineId: 'l', orderIndex: 0),
    Station(id: 'b', name: '途中駅', lineId: 'l', orderIndex: 1),
    Station(id: 'c', name: '終点駅', lineId: 'l', orderIndex: 2),
  ];
  const line = RailwayLine(id: 'l', name: 'テスト線', stations: stations);

  Future<ProviderContainer> pumpWithDeparture(
    WidgetTester tester,
    Station departure,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        stationRepositoryProvider.overrideWithValue(
          const _FixedLineRepository(line),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StationSelectPage()),
      ),
    );
    await container.read(gachaFormProvider.notifier).selectDeparture(departure);
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('途中の駅では、両方の方面とおまかせを出す', (tester) async {
    await pumpWithDeparture(tester, stations[1]);

    expect(find.text('終点駅'), findsOneWidget);
    expect(find.text('起点駅'), findsOneWidget);
    expect(find.text('おまかせ'), findsOneWidget);
  });

  testWidgets('終点では、先のない方面を出さない', (tester) async {
    await pumpWithDeparture(tester, stations[2]);

    // 終点駅は出発駅の欄にも出るため、方面のボタンの有無は、起点駅とおまかせで見る。
    expect(find.text('起点駅'), findsOneWidget);
    expect(find.text('おまかせ'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SegmentedButton<GachaDirection>),
        matching: find.text('終点駅'),
      ),
      findsNothing,
    );
  });
}
