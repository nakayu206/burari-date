import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../domain/services/sound_player.dart';

/// audioplayersで効果音を鳴らす。種類ごとにプレイヤーを1つ持ち、続けて鳴らしても
/// 前の音と重ならないよう、鳴らす前に止める。
class AudioplayersSoundPlayer implements SoundPlayer {
  AudioplayersSoundPlayer()
    : _players = {
        for (final sound in GachaSound.values)
          sound: AudioPlayer()..setPlayerMode(PlayerMode.lowLatency),
      };

  final Map<GachaSound, AudioPlayer> _players;

  static String _assetOf(GachaSound sound) => 'sounds/${sound.name}.wav';

  @override
  Future<void> play(GachaSound sound) async {
    try {
      final player = _players[sound]!;
      await player.stop();
      await player.play(AssetSource(_assetOf(sound)));
    } catch (e) {
      // 効果音は、鳴らせなくても演出の進行には影響しない。
      debugPrint('効果音を鳴らせませんでした($sound): $e');
    }
  }

  @override
  Future<void> stopAll() async {
    for (final player in _players.values) {
      try {
        await player.stop();
      } catch (e) {
        debugPrint('効果音を止められませんでした: $e');
      }
    }
  }

  @override
  Future<void> dispose() async {
    for (final player in _players.values) {
      try {
        await player.dispose();
      } catch (e) {
        debugPrint('効果音のプレイヤーを解放できませんでした: $e');
      }
    }
  }
}
