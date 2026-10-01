/// 効果音の設定(S-08 設定画面 > 効果音)。端末ローカルに保存する。
///
/// 以前は「通知設定」として、通知のスイッチも持っていた。送るべき通知の場面が
/// ないため外した(Issue #64)。通知を作るときに、あらためて足す。
class SoundSettings {
  const SoundSettings({this.isSoundEnabled = true});

  /// ガチャ演出の効果音(フリップ音・確定音)を鳴らすか(仕様書4.2 S-03のミュート設定)。
  final bool isSoundEnabled;

  SoundSettings copyWith({bool? isSoundEnabled}) {
    return SoundSettings(isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled);
  }

  @override
  bool operator ==(Object other) =>
      other is SoundSettings && other.isSoundEnabled == isSoundEnabled;

  @override
  int get hashCode => isSoundEnabled.hashCode;
}
