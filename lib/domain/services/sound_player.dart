/// ガチャ演出で鳴らす効果音の種類。音のファイルは `assets/sounds/`
/// (tool/generate_sounds.dartで作る)。昔の駅の発車標と、蒸気機関車の汽笛の音。
enum GachaSound {
  /// 発車標のパタパタ(板がめくれる音)。
  flip,

  /// 上段(何駅隣か)が決まったとき。板が最後に落ちる、重い「パタン」。
  confirm,

  /// 到着駅が決まったとき。蒸気機関車の汽笛の「ポッポー」。
  decide,
}

/// 効果音を鳴らす。鳴らす・鳴らさないの判断(設定)は、呼び出し側が行う。
abstract interface class SoundPlayer {
  /// [sound]を[volume](0.0〜1.0)で鳴らす。鳴らせなくても例外を投げない(効果音は、
  /// なくてもアプリの動作に影響しないため)。
  Future<void> play(GachaSound sound, {double volume = 1.0});

  /// 鳴らしている音を、すべて止める(スキップ・画面を閉じるとき)。
  Future<void> stopAll();

  /// 使っているリソースを解放する。
  Future<void> dispose();
}
