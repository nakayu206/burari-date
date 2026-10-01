import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// ガチャ演出の効果音を、プログラムで作って `assets/sounds/` に書き出す(Issue #64)。
///
/// 昔の駅の発車標(反転フラップ式)の「パタパタ」と、蒸気機関車の汽笛の
/// 「ポッポー」を、合成で作る。録音ではなく自作のため、ライセンスの心配がない。
/// 音を変えたいときは、ここを直して再実行する。
///
/// - flip.wav: 発車標のパタパタ(空回り5回+最後の確定のフリップ)
/// - confirm.wav: 上段が決まったときの、重めの「パタン」
/// - decide.wav: 到着駅が決まったときの、汽笛の「ポッポー」
///
/// 使い方: `dart run tool/generate_sounds.dart`
const _sampleRate = 22050;

/// 2次の帯域通過フィルター(中心[hz]付近だけを通す。[q]が大きいほど狭い)。
List<double> _bandpass(List<double> x, double hz, double q) {
  final w0 = 2 * pi * hz / _sampleRate;
  final alpha = sin(w0) / (2 * q);
  final a0 = 1 + alpha;
  final a1 = -2 * cos(w0) / a0;
  final a2 = (1 - alpha) / a0;
  final b0 = alpha / a0;
  final b2 = -alpha / a0;
  final y = List<double>.filled(x.length, 0);
  for (var n = 0; n < x.length; n++) {
    final x1 = n >= 1 ? x[n - 1] : 0.0;
    final x2 = n >= 2 ? x[n - 2] : 0.0;
    final y1 = n >= 1 ? y[n - 1] : 0.0;
    final y2 = n >= 2 ? y[n - 2] : 0.0;
    y[n] = b0 * x[n] + b2 * x2 - a1 * y1 - a2 * y2;
    // x1は、帯域通過ではb1が0のため使わない。
    assert(x1 == x1);
  }
  return y;
}

/// 指数関数的に減衰する白色雑音。
List<double> _decayingNoise(Random random, int ms, double decayPerMs) {
  final n = _sampleRate * ms ~/ 1000;
  return List<double>.generate(n, (i) {
    final tMs = i * 1000 / _sampleRate;
    return (random.nextDouble() * 2 - 1) * exp(-decayPerMs * tMs);
  });
}

List<double> _scale(List<double> x, double gain) =>
    x.map((v) => v * gain).toList();

/// 薄い板(フラップ)がぶつかる「カチャッ」。板の鳴り(中域)と、ぶつかる音(高域)を
/// 重ね、[pitch]で全体の高さを少しずらす。[heavy]を大きくすると、重い音になる。
List<double> _clack(
  Random random, {
  double pitch = 1.0,
  double volume = 1.0,
  double heavy = 0.0,
}) {
  // 低中域の板の響きを残して、乾いた「パタッ」にする。
  final body = _bandpass(
    _decayingNoise(random, 65, 0.075 - heavy * 0.02),
    720 * pitch,
    1.1,
  );
  final tap = _bandpass(_decayingNoise(random, 35, 0.16), 2100 * pitch, 0.9);
  final n = max(body.length, tap.length);
  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    out[i] =
        (i < body.length ? body[i] * 2.3 : 0) +
        (i < tap.length ? tap[i] * 0.55 : 0);
    final t = i / _sampleRate;
    out[i] += sin(2 * pi * 390 * pitch * t) * exp(-t * 95) * 0.32;
    out[i] *= min(1.0, t / 0.0008);
  }
  // 重い「パタン」には、低い「ドン」を足す。
  if (heavy > 0) {
    final thumpLen = _sampleRate * 40 ~/ 1000;
    for (var i = 0; i < thumpLen && i < n; i++) {
      final t = i / _sampleRate;
      out[i] += sin(2 * pi * 220 * t) * exp(-t * 110) * heavy * 0.35;
    }
  }
  return _scale(out, volume);
}

/// [parts]を、それぞれの開始位置[atMs]に重ねて、1本の音にする。
List<double> _mix(int totalMs, List<(double, List<double>)> parts) {
  final out = List<double>.filled(_sampleRate * totalMs ~/ 1000, 0);
  for (final (atMs, samples) in parts) {
    // ばらつきで0msより前になった場合は、0msから始める。
    final start = max(0, (_sampleRate * atMs / 1000).round());
    for (var i = 0; i < samples.length && start + i < out.length; i++) {
      out[start + i] += samples[i];
    }
  }
  return out;
}

/// 汽笛の1音。ほぼ同じ高さの管のうなりに、倍音と、息の雑音、小さなゆらぎを
/// 足す。立ち上がりは速く、終わりは、ゆっくり消える。
List<double> _whistle(
  Random random,
  double rootHz,
  int ms, {
  double vibratoHz = 0,
  double scoop = 0,
  double rise = 0,
}) {
  final n = _sampleRate * ms ~/ 1000;
  final out = List<double>.filled(n, 0);
  const chord = [0.995, 1.0, 1.006];
  const harmonics = 4;
  final phases = List<double>.filled(chord.length * harmonics, 0);
  for (var i = 0; i < n; i++) {
    final t = i / _sampleRate;
    final progress = i / n;
    // 出だしは[scoop]だけ低いところから、すっと上がる。そのあとも[rise]だけ、
    // ゆっくり上がり続ける(下げない)。後半は、小さくゆらぐ。
    final pitch =
        1.0 -
        scoop * exp(-t / 0.07) +
        rise * progress +
        (vibratoHz > 0 ? 0.004 * sin(2 * pi * vibratoHz * t) * progress : 0);
    var sample = 0.0;
    var p = 0;
    for (final ratio in chord) {
      for (var h = 1; h <= harmonics; h++) {
        phases[p] += 2 * pi * rootHz * ratio * h * pitch / _sampleRate;
        // 基音中心の丸い汽笛。強い高次倍音による電子音っぽさを抑える。
        final weight = [1.0, 0.24, 0.11, 0.035][h - 1];
        sample += sin(phases[p]) * weight;
        p++;
      }
    }
    final attack = min(1.0, t / 0.018);
    final release = min(1.0, (n - 1 - i) / (_sampleRate * 0.10));
    out[i] = sample * attack * release / (chord.length * 1.6);
  }
  // 息の雑音(笛の鳴る帯域だけ)。
  final breath = _bandpass(
    List<double>.generate(n, (_) => random.nextDouble() * 2 - 1),
    1300,
    0.7,
  );
  for (var i = 0; i < n; i++) {
    final env =
        min(1.0, (i / _sampleRate) / 0.012) *
        min(1.0, (n - i) / (_sampleRate * 0.12));
    out[i] += breath[i] * 0.11 * env;
  }
  return out;
}

/// 簡単な反響(遅れて返る音)。屋外の汽笛らしい広がりをつける。
List<double> _echo(
  List<double> x, {
  int delayMs = 110,
  double feedback = 0.22,
  double mix = 0.3,
}) {
  final delay = _sampleRate * delayMs ~/ 1000;
  final y = List<double>.from(x);
  for (var i = delay; i < y.length; i++) {
    y[i] += y[i - delay] * feedback * mix * 2;
  }
  return y;
}

/// 最大の振幅を[peak]にそろえる。
List<double> _normalize(List<double> x, double peak) {
  final m = x.fold<double>(0, (a, v) => max(a, v.abs()));
  return m == 0 ? x : _scale(x, peak / m);
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
  final random = Random(20261001);

  // 110msごとの動きに、板が離れる音と当たる音を対応させる。
  // 連打を詰めすぎず「パタ・パタ」と聞き取れる間隔にする。
  // gacha_animation_page.dartの_kFlapCardTotalMs(810ms)に合わせる。
  final flipParts = <(double, List<double>)>[];
  const flipPitch = 1.2; // 板の響きを残しつつ、パタパタ音を少し高めにする。
  for (var k = 0; k < 5; k++) {
    final base = k * 110.0;
    const clacks = 2;
    for (var c = 0; c < clacks; c++) {
      // 強さと音の高さに少しばらつきをつける。
      final at = base + c * 43;
      final volume = (c == 0 ? 0.72 : 1.0) * (0.9 + random.nextDouble() * 0.2);
      final pitch = (0.88 + random.nextDouble() * 0.16) * flipPitch;
      flipParts.add((at, _clack(random, pitch: pitch, volume: volume * 0.8)));
    }
  }
  flipParts.add((550, _clack(random, pitch: 1.1 * flipPitch, volume: 0.75)));
  flipParts.add((665, _clack(random, pitch: 0.95 * flipPitch, volume: 0.85)));
  flipParts.add((
    740,
    _clack(random, pitch: 0.82 * flipPitch, volume: 1.0, heavy: 0.3),
  ));
  _write('flip', _normalize(_mix(810, flipParts), 0.72));

  // 確定音: 上段が決まったときの、重めの「パタン」(板が最後に落ちる音)。
  _write(
    'confirm',
    _normalize(
      _mix(320, [
        (0, _clack(random, pitch: 1.1, volume: 0.7)),
        (28, _clack(random, pitch: 0.92, volume: 1.0, heavy: 0.25)),
      ]),
      0.6,
    ),
  );

  // 決定音: 到着駅が決まったときの、蒸気機関車の汽笛「ポッポー」。短い「ポッ」の
  // あと、少し間をおいて、長い「ポー」。
  _write(
    'decide',
    _normalize(
      _echo(
        _mix(1900, [
          // 同じ汽笛を短く、長く。2音目を別の音程にしない。
          (0, _whistle(random, 440, 180, scoop: 0.045)),
          (290, _whistle(random, 440, 1100, vibratoHz: 3.2, scoop: 0.045)),
        ]),
      ),
      0.55,
    ),
  );
}
