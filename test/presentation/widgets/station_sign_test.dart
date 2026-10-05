import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/presentation/widgets/station_sign.dart';

void main() {
  Future<void> pumpSign(
    WidgetTester tester, {
    String stationName = '新宿駅',
    VoidCallback? onReroll,
    VoidCallback? onViewCandidates,
    double width = 360,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: StationSign(
                stationName: stationName,
                lineName: 'JR山手線',
                stopsCount: 3,
                onReroll: onReroll ?? () {},
                onViewCandidates: onViewCandidates ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('到着駅・路線名・N駅隣・2つの操作を表示する', (tester) async {
    await pumpSign(tester);

    expect(find.text('新宿駅'), findsOneWidget);
    expect(find.text('JR山手線'), findsOneWidget);
    expect(find.text('3駅隣'), findsOneWidget);
    expect(find.text('もう一度ガチャ'), findsOneWidget);
    expect(find.text('この駅に行く'), findsOneWidget);
  });

  testWidgets('左の矢印で再ガチャ、右の矢印で候補へ進む', (tester) async {
    var rerolled = 0;
    var viewed = 0;
    await pumpSign(
      tester,
      onReroll: () => rerolled++,
      onViewCandidates: () => viewed++,
    );

    await tester.tap(find.text('もう一度ガチャ'));
    expect((rerolled, viewed), (1, 0));

    await tester.tap(find.text('この駅に行く'));
    expect((rerolled, viewed), (1, 1));
  });

  testWidgets('左が「もう一度ガチャ」、右が「この駅に行く」の並びになる', (tester) async {
    await pumpSign(tester);

    final left = tester.getCenter(find.text('もう一度ガチャ')).dx;
    final right = tester.getCenter(find.text('この駅に行く')).dx;
    expect(left, lessThan(right));
  });

  testWidgets('押す範囲は、高さ48以上', (tester) async {
    await pumpSign(tester);

    final size = tester.getSize(
      find.ancestor(
        of: find.text('この駅に行く'),
        matching: find.byType(GestureDetector),
      ),
    );
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('長い駅名でも、はみ出さない', (tester) async {
    await pumpSign(tester, stationName: 'ものすごく長い名前の駅がここにあります駅', width: 300);

    expect(tester.takeException(), isNull);
    final sign = tester.getRect(find.byType(StationSign));
    final name = tester.getRect(find.text('ものすごく長い名前の駅がここにあります駅'));
    expect(name.right, lessThanOrEqualTo(sign.right));
    expect(name.left, greaterThanOrEqualTo(sign.left));
  });
}
