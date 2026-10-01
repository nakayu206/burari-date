/// ガチャ演出の発車標フリップの時間。画面(gacha_animation_page.dart)と、
/// 効果音の生成ツール(tool/generate_sounds.dart)の両方が使う。
/// ここを変えて効果音を作り直せば、音と動きがずれない。
library;

/// 空フリップ(まだ文字を明かさない、ぐるぐる感のためだけのフリップ)1回分の時間。
const kFlapBlankFlipMs = 110;

/// 最終文字列を明かす確定フリップの時間。空フリップよりわずかに長くして「めくれて出てくる」瞬間に間を持たせる。
const kFlapRevealFlipMs = 260;

/// カードが確定するまでに行う空フリップの回数(確定の1回は含まない)。
const kFlapBlankSpinCount = 5;

/// 1枚のフリップカードが確定するまでの所要時間(空フリップ×回数 + 確定フリップ)。
const kFlapCardTotalMs =
    kFlapBlankFlipMs * kFlapBlankSpinCount + kFlapRevealFlipMs;
