import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// ガチャ演出の効果音(8ビット風)を、プログラムで作って `assets/sounds/` に書き出す。
///
/// 電車・背景のドット絵に合う、ピコピコした矩形波の音。自作のため、ライセンスの
/// 心配がない(Issue #64)。音を変えたいときは、ここを直して再実行する。
///
/// 使い方: `dart run tool/generate_sounds.dart`
const _sampleRate = 22050;

/// 矩形波のスイープ(周波数を[fromHz]から[toHz]へ動かす)を[ms]ミリ秒鳴らす。
/// 音量は指数関数的に減衰させる(ピコッという短い音になる)。
List<double> _square(
  double fromHz,
  double toHz,
  int ms, {
  double volume = 0.3,
  double decay = 4.0,
}) {
  final n = _sampleRate * ms ~/ 1000;
  final out = List<double>.filled(n, 0);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / n;
    final hz = fromHz + (toHz - fromHz) * t;
    phase += hz / _sampleRate;
    final wave = (phase % 1.0) < 0.5 ? 1.0 : -1.0;
    out[i] = wave * volume * exp(-decay * t);
  }
  return out;
}

/// ノイズの短いバースト(カチッというアタック音)。
List<double> _click(int ms, Random random, {double volume = 0.25}) {
  final n = _sampleRate * ms ~/ 1000;
  return List<double>.generate(n, (i) {
    final t = i / n;
    return (random.nextDouble() * 2 - 1) * volume * exp(-6 * t);
  });
}

/// [parts]を、それぞれの開始位置[atMs]に重ねて、1本の音にする。
List<double> _mix(int totalMs, List<(int, List<double>)> parts) {
  final out = List<double>.filled(_sampleRate * totalMs ~/ 1000, 0);
  for (final (atMs, samples) in parts) {
    final start = _sampleRate * atMs ~/ 1000;
    for (var i = 0; i < samples.length && start + i < out.length; i++) {
      out[start + i] += samples[i];
    }
  }
  return out;
}

Uint8List _toWav(List<double> samples) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(i * 2, v, Endian.little);
  }
  final header = ByteData(44);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + data.lengthInBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // fmtチャンクの大きさ
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // モノラル
  header.setUint32(24, _sampleRate, Endian.little);
  header.setUint32(28, _sampleRate * 2, Endian.little); // 1秒あたりのバイト数
  header.setUint16(32, 2, Endian.little); // 1サンプルのバイト数
  header.setUint16(34, 16, Endian.little); // ビット数
  ascii(36, 'data');
  header.setUint32(40, data.lengthInBytes, Endian.little);
  return Uint8List.fromList([
    ...header.buffer.asUint8List(),
    ...data.buffer.asUint8List(),
  ]);
}

void _write(String name, List<double> samples) {
  final file = File('assets/sounds/$name.wav');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(_toWav(samples));
  stdout.writeln('$name.wav: ${samples.length * 1000 ~/ _sampleRate}ms');
}

void main() {
  final random = Random(20260930);

  // フリップ音: 発車標のパタパタ。空回り5回(110msごと)と、最後の確定のフリップ
  // (550msから)で、gacha_animation_page.dartの_kFlapCardTotalMs(810ms)に合わせる。
  final flipParts = <(int, List<double>)>[];
  for (var i = 0; i < 5; i++) {
    final at = i * 110;
    flipParts.add((at, _click(14, random)));
    flipParts.add((at, _square(2400 - i * 90, 1500, 40, volume: 0.22)));
  }
  flipParts.add((550, _click(26, random, volume: 0.32)));
  flipParts.add((550, _square(1000, 620, 110, volume: 0.3, decay: 3)));
  flipParts.add((640, _square(1500, 1500, 150, volume: 0.28, decay: 5)));
  _write('flip', _mix(810, flipParts));

  // 確定音: 上段(何駅隣か)が決まったときの、上がる3音。
  _write(
    'confirm',
    _mix(380, [
      (0, _square(1047, 1047, 80, decay: 3)),
      (80, _square(1319, 1319, 80, decay: 3)),
      (160, _square(1568, 1568, 200, decay: 4)),
    ]),
  );

  // 決定音: 到着駅が決まったときの、少し長いファンファーレ。
  _write(
    'decide',
    _mix(900, [
      (0, _square(523, 523, 100, decay: 2)),
      (100, _square(659, 659, 100, decay: 2)),
      (200, _square(784, 784, 100, decay: 2)),
      (300, _square(1047, 1047, 420, volume: 0.32, decay: 2.5)),
      (300, _square(523, 523, 420, volume: 0.16, decay: 2.5)),
      (620, _square(1568, 1568, 260, volume: 0.2, decay: 4)),
    ]),
  );
}
