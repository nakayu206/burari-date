import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/core/config/gacha_flap_timing.dart';

/// 16bit・モノラルのWAVの長さ(ミリ秒)。ヘッダーは44バイト。
double _wavMs(String path) {
  final bytes = File(path).readAsBytesSync();
  final sampleRate = bytes.buffer.asByteData().getUint32(24, Endian.little);
  return (bytes.length - 44) / 2 / sampleRate * 1000;
}

void main() {
  test('パタパタ音の長さは、画面のフリップの所要時間と同じ(ずれたら音を作り直す)', () {
    // 画面の速度(gacha_flap_timing.dart)を変えたら、
    // `dart run tool/generate_sounds.dart` で音を作り直す。
    expect(
      _wavMs('assets/sounds/flip.wav'),
      closeTo(kFlapCardTotalMs.toDouble(), 2),
    );
  });
}
