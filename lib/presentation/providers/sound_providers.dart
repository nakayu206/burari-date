import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/audioplayers_sound_player.dart';
import '../../domain/services/sound_player.dart';

/// 効果音の再生。アプリの間、1つのプレイヤーを使い回す。
final soundPlayerProvider = Provider<SoundPlayer>((ref) {
  final player = AudioplayersSoundPlayer();
  ref.onDispose(player.dispose);
  return player;
});
