import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:burari_date/domain/entities/gacha_result.dart';
import 'package:burari_date/domain/entities/railway_line.dart';
import 'package:burari_date/domain/entities/station.dart';
import 'package:burari_date/domain/services/sound_player.dart';
import 'package:burari_date/presentation/pages/gacha/gacha_animation_page.dart';
import 'package:burari_date/presentation/providers/sound_providers.dart';

/// 鳴らした音を記録するだけの偽のプレイヤー。
class _FakeSoundPlayer implements SoundPlayer {
  final played = <GachaSound>[];
  final volumes = <double>[];
  int stopAllCount = 0;

  /// 設定すると、stopAllの完了を、これが完了するまで遅らせる。
  Completer<void>? stopGate;
  bool isDisposed = false;

  @override
  Future<void> play(GachaSound sound, {double volume = 1.0}) async {
    played.add(sound);
    volumes.add(volume);
  }

  @override
  Future<void> stopAll() async {
    stopAllCount++;
    await stopGate?.future;
  }

  @override
  Future<void> dispose() async => isDisposed = true;
}

void main() {
  const departure = Station(
    id: 'l-departure',
    name: '出発駅',
    lineId: 'l',
    orderIndex: 0,
  );
  const arrival = Station(
    id: 'l-arrival',
    name: '到着駅',
    lineId: 'l',
    orderIndex: 1,
  );
  final result = GachaResult(
    departureStation: departure,
    line: const RailwayLine(
      id: 'l',
      name: 'テスト線',
      stations: [departure, arrival],
    ),
    minStops: 1,
    maxStops: 3,
    direction: GachaDirection.up,
    arrivalStation: arrival,
    stopsCount: 1,
    executedAt: DateTime(2026, 9, 30),
  );

  // 演出の時間(gacha_animation_page.dart)。1行の確定まで810ms、行の間に800ms、
  // 最後に1秒。
  const rowMs = Duration(milliseconds: 810);
  const pauseMs = Duration(milliseconds: 800);

  Future<_FakeSoundPlayer> pumpPage(WidgetTester tester) async {
    final player = _FakeSoundPlayer();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [soundPlayerProvider.overrideWithValue(player)],
        child: MaterialApp(home: GachaAnimationPage(result: result)),
      ),
    );
    // 設定(SharedPreferences)の読み込みを待つ。
    await tester.pump();
    await tester.pump();
    return player;
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('画面のタイトルは、利用者の言葉の「駅ガチャ」(開発者向けの呼び名は、出さない)', (tester) async {
    await pumpPage(tester);

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('駅ガチャ')),
      findsOneWidget,
    );
    expect(find.text('ガチャ演出'), findsNothing);
  });

  testWidgets('効果音がオンなら、演出に合わせて、フリップ・確定・フリップ・決定の順に鳴らす', (tester) async {
    final player = await pumpPage(tester);
    expect(player.played, isEmpty, reason: '「ガチャる」を押すまでは鳴らさない');

    await tester.tap(find.text('ガチャる'));
    await tester.pump();
    expect(player.played, [GachaSound.flip]);

    await tester.pump(rowMs); // 上段が確定
    expect(player.played, [GachaSound.flip, GachaSound.confirm]);

    await tester.pump(pauseMs); // 下段のフリップが始まる
    expect(player.played, [
      GachaSound.flip,
      GachaSound.confirm,
      GachaSound.flip,
    ]);

    await tester.pump(rowMs); // 到着駅が確定
    expect(player.played, [
      GachaSound.flip,
      GachaSound.confirm,
      GachaSound.flip,
      GachaSound.decide,
    ]);

    // 残りのタイマーを進めて、演出を終わらせる。
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('保存した音量で鳴らす', (tester) async {
    SharedPreferences.setMockInitialValues({'settings.sound.volume': 0.4});
    final player = await pumpPage(tester);

    await tester.tap(find.text('ガチャる'));
    await tester.pump();
    await tester.pump(rowMs);

    expect(player.volumes, [0.4, 0.4]);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('効果音がオフなら、何も鳴らさない', (tester) async {
    SharedPreferences.setMockInitialValues({'settings.sound.enabled': false});
    final player = await pumpPage(tester);

    await tester.tap(find.text('ガチャる'));
    await tester.pump();
    await tester.pump(rowMs);
    await tester.pump(pauseMs);
    await tester.pump(rowMs);
    await tester.pump(const Duration(seconds: 2));

    expect(player.played, isEmpty);
  });

  testWidgets('タップでスキップしたら、鳴っている音を止めて、決定音だけを鳴らす', (tester) async {
    final player = await pumpPage(tester);
    await tester.tap(find.text('ガチャる'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final stopsBefore = player.stopAllCount;

    // 画面をタップしてスキップする。
    await tester.tapAt(const Offset(200, 300));
    await tester.pump();

    expect(player.stopAllCount, greaterThan(stopsBefore));
    expect(player.played, [GachaSound.flip, GachaSound.decide]);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('スキップで、音の停止が遅れても、決定音は停止が終わってから鳴らす(止められない)', (tester) async {
    final player = await pumpPage(tester);
    await tester.tap(find.text('ガチャる'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 停止が終わらない間にスキップする。
    player.stopGate = Completer<void>();
    await tester.tapAt(const Offset(200, 300));
    await tester.pump();
    expect(player.played, [GachaSound.flip]);

    // 停止が終わったあとに、決定音を鳴らす。
    player.stopGate!.complete();
    await tester.pump();
    expect(player.played, [GachaSound.flip, GachaSound.decide]);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('画面を閉じたら、鳴っている音を止める', (tester) async {
    final player = await pumpPage(tester);
    await tester.tap(find.text('ガチャる'));
    await tester.pump();
    final stopsBefore = player.stopAllCount;

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(player.stopAllCount, greaterThan(stopsBefore));
  });
}
