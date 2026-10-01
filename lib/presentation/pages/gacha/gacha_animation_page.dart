import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/gacha_flap_timing.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_train_colors.dart';
import '../../../domain/entities/gacha_result.dart';
import '../../../domain/entities/sound_settings.dart';
import '../../../domain/services/sound_player.dart';
import '../../providers/gacha_form_provider.dart';
import '../../providers/settings_providers.dart';
import '../../providers/sound_providers.dart';
import '../../widgets/train_illustration.dart';
import 'candidate_list_page.dart';

/// 電車の正面イラスト(方向幕は自前のサインボードで上書きする)。assets/images/train_face.png を配置すること。
const _kTrainFaceAsset = 'assets/images/train_face.png';

// このファイルのアニメーション設計は、ユーザー提供の参考実装(gacha_split_flap_train_bg_sunny.html)をベースに、行(駅数/到着駅名)ごとに1枚のカードとして扱い、文字の見えない空フリップを数回行った後に行全体の文字列を1回のフリップで確定させる。

const _kBlankFlipDuration = Duration(milliseconds: kFlapBlankFlipMs);
const _kRevealFlipDuration = Duration(milliseconds: kFlapRevealFlipMs);

/// 上段(駅数)が確定してから下段(到着駅名)のフリップが始まるまでの間。
const _kInterRowPause = Duration(milliseconds: 800);

/// 下段(到着駅名)が確定してから結果カードへ切り替わるまでの間。確定した文字列を読む間を確保してから切り替える。
const _kFinishPause = Duration(seconds: 1);

const _kFlapCellBackground = Color(0xFF1B1B1B);
const _kFlapCellText = Color(0xFFF2C98A);
const _kCaptionColor = Color(0xFFD99A2B);
const _kPlaceholderChar = '−';
// キャプション文字は空の背景(時間帯で色が変わる)に直接乗るため、暗い縁取りを
// 付けて、夕方・昼など明るい背景でも視認性を確保する(ユーザーフィードバック:
// 「結果の何駅隣とかに文字の色が夕方とかだと見づらい」「昼間は影が入っていると
// 見づらい」)。ぼかし付きの影は、明るい空では暗いぼやけが文字の周りに広がって
// かえって読みにくいため、ぼかしのない8方向のずらしで、くっきりした縁取りにする
// (背景のドット絵調にもそろう)。
const _kCaptionOutlineColor = Color(0xFF2E2115);
const _kCaptionShadows = [
  Shadow(color: _kCaptionOutlineColor, offset: Offset(-1.5, 0)),
  Shadow(color: _kCaptionOutlineColor, offset: Offset(1.5, 0)),
  Shadow(color: _kCaptionOutlineColor, offset: Offset(0, -1.5)),
  Shadow(color: _kCaptionOutlineColor, offset: Offset(0, 1.5)),
  Shadow(color: _kCaptionOutlineColor, offset: Offset(-1.5, -1.5)),
  Shadow(color: _kCaptionOutlineColor, offset: Offset(1.5, -1.5)),
  Shadow(color: _kCaptionOutlineColor, offset: Offset(-1.5, 1.5)),
  Shadow(color: _kCaptionOutlineColor, offset: Offset(1.5, 1.5)),
];

/// S-03 ガチャ演出画面。晴天の空・電車が線路を走る背景の上に、発車標(スプリットフラップ)風のセルが1文字ずつ段差をつけてパタッと確定する。確定後は別画面へ自動遷移せず、この場で電車の正面イラストと「この駅に行く」「もう一度ガチャ」を表示する。
class GachaAnimationPage extends ConsumerStatefulWidget {
  const GachaAnimationPage({super.key, required this.result});

  final GachaResult result;

  @override
  ConsumerState<GachaAnimationPage> createState() => _GachaAnimationPageState();
}

class _GachaAnimationPageState extends ConsumerState<GachaAnimationPage> {
  late GachaResult _result;
  late String _row1Text;
  late String _row2Text;
  String _caption1 = '';
  String _caption2 = '';

  /// 「ガチャる」ボタンが押されてフリップ演出が始まったかどうか。画面遷移直後には自動開始せず、ボタン押下を待ってから[_runSequence]を開始する。
  bool _started = false;

  /// 下段(到着駅名)のフリップを開始してよいかどうか。上段が確定し[_kInterRowPause]分の間を置いた後にtrueにする(falseの間、下段はプレースホルダーのまま)。
  bool _row2Active = false;
  bool _finished = false;

  /// [_runSequence]が予約する各段階のタイマー。スキップ/再ガチャ時に確実にキャンセルできるよう保持しておく。
  Timer? _sequenceTimer;

  /// 効果音のプレイヤー。dispose中は[ref]を使えないため、最初に取っておく。
  late final SoundPlayer _soundPlayer;

  @override
  void initState() {
    super.initState();
    _result = widget.result;
    _setUpTexts();
    _soundPlayer = ref.read(soundPlayerProvider);
    // 効果音の設定を、演出の開始前に読み込んでおく(最初の音から設定に従うため)。
    ref.read(soundSettingsProvider);
  }

  /// 効果音を鳴らす。設定がオフのときは鳴らさない。設定を読み込み中の間は、
  /// 初期値(オン)として扱う。
  void _play(GachaSound sound) {
    final settings =
        ref.read(soundSettingsProvider).value ?? const SoundSettings();
    if (!settings.isSoundEnabled) return;
    unawaited(_soundPlayer.play(sound, volume: settings.volume));
  }

  /// 「ガチャる」ボタン押下でフリップ演出を開始する。
  void _start() {
    if (_started) return;
    setState(() {
      _started = true;
      _caption1 = '駅隣を決定中…';
    });
    _play(GachaSound.flip);
    _runSequence();
  }

  @override
  void dispose() {
    _sequenceTimer?.cancel();
    // 画面を閉じたあとに、音だけが鳴り続けないようにする。
    unawaited(_soundPlayer.stopAll());
    super.dispose();
  }

  void _setUpTexts() {
    _row1Text = '${_result.stopsCount}駅隣';
    _row2Text = _result.arrivalStation.name;
  }

  /// 1枚のフリップカードが確定するまでの時間。
  static const _rowDuration = Duration(milliseconds: kFlapCardTotalMs);

  void _runSequence() {
    _sequenceTimer?.cancel();
    _sequenceTimer = Timer(_rowDuration, () {
      if (!mounted) return;
      setState(() {
        _caption1 = '${_result.stopsCount}駅隣に決定!';
      });
      _play(GachaSound.confirm);

      _sequenceTimer = Timer(_kInterRowPause, () {
        if (!mounted) return;
        setState(() {
          _caption2 = '到着駅を表示中…';
          _row2Active = true;
        });
        _play(GachaSound.flip);

        _sequenceTimer = Timer(_rowDuration, () {
          if (!mounted) return;
          setState(() {
            _caption2 = '到着駅：${_result.arrivalStation.name}';
          });
          _play(GachaSound.decide);

          _sequenceTimer = Timer(_kFinishPause, () {
            if (!mounted) return;
            setState(() => _finished = true);
          });
        });
      });
    });
  }

  /// タップでスキップした場合、その場で確定状態まで進める(演出だけを省略し遷移は行わない)。演出が始まっていない間は何もしない。
  void _skip() {
    if (!_started || _finished) return;
    _sequenceTimer?.cancel();
    // 途中まで鳴っていたフリップ音を止め、決定音だけを鳴らす。
    unawaited(_soundPlayer.stopAll());
    setState(() {
      _caption1 = '${_result.stopsCount}駅隣に決定!';
      _caption2 = '到着駅：${_result.arrivalStation.name}';
      _row2Active = true;
      _finished = true;
    });
    _play(GachaSound.decide);
  }

  /// もう一度ガチャ。画面遷移はせず、この場で新しい結果の演出を再生する。
  void _reroll() {
    final rerolled = ref.read(gachaFormProvider.notifier).runGacha();
    setState(() {
      _result = rerolled;
      _setUpTexts();
      _caption1 = '駅隣を決定中…';
      _caption2 = '';
      _row2Active = false;
      _finished = false;
    });
    _play(GachaSound.flip);
    _runSequence();
  }

  void _viewCandidates() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CandidateListPage(result: _result)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ガチャ演出')),
      body: GestureDetector(
        onTap: (_started && !_finished) ? _skip : null,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _SkyScene(),
            SafeArea(
              // 発車標/結果カードは画面中央よりやや上に置き、下部を走る電車との
              // 距離を縮めて一体感を出す(ユーザーフィードバック:「ガチャの
              // 部分もう少し上に、アニメの電車に近い」)。
              child: Align(
                alignment: const Alignment(0, -0.3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 発車標→結果カードへ瞬時に切り替わると唐突に感じるため、フェードでゆるやかに切り替える。
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 800),
                      child: _finished
                          ? _ResultCard(
                              key: const ValueKey('result'),
                              result: _result,
                              onViewCandidates: _viewCandidates,
                              onReroll: _reroll,
                            )
                          : _FlapBoard(
                              key: const ValueKey('flap'),
                              row1Text: _row1Text,
                              row2Text: _row2Text,
                              caption1: _caption1,
                              caption2: _caption2,
                              showRow1: _started,
                              showRow2: _row2Active,
                            ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // 演出開始前は発車標のすぐ下に「ガチャる」ボタンを表示し、押下されるまでフリップを始めない。
                    if (!_started)
                      ElevatedButton(
                        onPressed: _start,
                        // アプリ共通のボタンテーマは横幅いっぱいに広がる設定だが、このボタンは発車標の下に添えるだけなので横幅を内容に合わせる。
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.x3l,
                          ),
                        ),
                        child: const Text('ガチャる'),
                      )
                    else if (!_finished)
                      const Text(
                        '(タップでスキップ)',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppFontSizes.caption,
                          shadows: [
                            Shadow(color: AppColors.background, blurRadius: 6),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 確定後にその場で表示する結果カード。電車の正面イラスト(方向幕に駅情報を表示)+ アクションボタン。
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    super.key,
    required this.result,
    required this.onViewCandidates,
    required this.onReroll,
  });

  final GachaResult result;
  final VoidCallback onViewCandidates;
  final VoidCallback onReroll;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TrainFace(destination: result.arrivalStation.name),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${result.stopsCount}駅隣',
            style: const TextStyle(
              color: _kCaptionColor,
              fontSize: AppFontSizes.bodyLarge,
              shadows: _kCaptionShadows,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: onViewCandidates,
            child: const Text('この駅に行く'),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onReroll, child: const Text('もう一度ガチャ')),
        ],
      ),
    );
  }
}

/// 電車の正面イラスト。train_face.png(クリーム×緑の旧型国電)の上に、行先サインだけ自前で重ねて表示する。
class _TrainFace extends StatelessWidget {
  const _TrainFace({required this.destination});

  final String destination;

  @override
  Widget build(BuildContext context) {
    // train_face.png は電車の輪郭ぴったりにクロップ済み(910×1116、透過背景)。画像内の方向幕の位置に、実際の到着駅名を表示する自前のサインボードを重ねる。透過画像なので、矩形の影は付けない。
    return AspectRatio(
      aspectRatio: 910 / 1116,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Image.asset(
                _kTrainFaceAsset,
                width: width,
                height: height,
                fit: BoxFit.cover,
              ),
              Positioned(
                left: width * 0.182,
                right: width * 0.182,
                top: height * 0.074,
                child: _SignBoard(
                  text: '$destination行',
                  fontSize: AppFontSizes.titleMedium,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SignBoard extends StatelessWidget {
  const _SignBoard({required this.text, required this.fontSize});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppTrainColors.cream,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTrainColors.outline, width: 1.5),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: GoogleFonts.mochiyPopOne(
            color: AppTrainColors.green,
            fontSize: fontSize,
          ),
        ),
      ),
    );
  }
}

/// 発車標の見た目をまとめたオーバーレイ(駅数の行 + キャプション + 到着駅名の行)。
class _FlapBoard extends StatelessWidget {
  const _FlapBoard({
    super.key,
    required this.row1Text,
    required this.row2Text,
    required this.caption1,
    required this.caption2,
    required this.showRow1,
    required this.showRow2,
  });

  final String row1Text;
  final String row2Text;
  final String caption1;
  final String caption2;
  final bool showRow1;
  final bool showRow2;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4l,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.87),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // showRow1がfalseの間(「ガチャる」ボタン押下前)は非アニメーションのプレースホルダーを表示し、押下された瞬間に初めて_FlapCardを生成する。
          FittedBox(
            fit: BoxFit.scaleDown,
            child: showRow1
                ? _FlapCard(text: row1Text, height: 70)
                : const _PlaceholderCard(height: 70),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            caption1,
            style: const TextStyle(
              color: _kCaptionColor,
              fontSize: AppFontSizes.bodySmall,
              shadows: _kCaptionShadows,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // showRow2がfalseの間は非アニメーションのプレースホルダーを表示し、trueになった瞬間に初めて_FlapCardを生成する(最初から実体化してOpacityで隠すと上段が終わる前に下段が裏で完了してしまう)。
          FittedBox(
            fit: BoxFit.scaleDown,
            child: showRow2
                ? _FlapCard(text: row2Text, height: 62)
                : const _PlaceholderCard(height: 62),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            caption2,
            style: const TextStyle(
              color: _kCaptionColor,
              fontSize: AppFontSizes.bodySmall,
              shadows: _kCaptionShadows,
            ),
          ),
        ],
      ),
    );
  }
}

/// [_FlapCard]と見た目だけ同じ、アニメーションしない静止状態のプレースホルダー。まだ手番が来ていない行のレイアウトを確保しつつフリップを始めさせないために使う。
class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      constraints: const BoxConstraints(minWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kFlapCellBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _kPlaceholderChar,
        style: GoogleFonts.mochiyPopOne(
          color: _kFlapCellText,
          fontSize: height * 0.42,
        ),
      ),
    );
  }
}

/// 発車標の1行分のフリップカード。マウント直後から文字を明かさない空フリップを数回行った後、行全体の文字列[text]を1回のフリップで確定させる。
class _FlapCard extends StatefulWidget {
  const _FlapCard({required this.text, required this.height});

  final String text;
  final double height;

  @override
  State<_FlapCard> createState() => _FlapCardState();
}

class _FlapCardState extends State<_FlapCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  String _displayText = _kPlaceholderChar;
  String? _nextText;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _kBlankFlipDuration,
    )..addListener(_onTick);
    // ウィジェットが破棄されるとdisposeがコントローラーを止め、進行中の
    // forward()の完了をawaitしている_runSpinsにTickerCanceledが伝わりうる
    // (例: フリップ中に画面を戻る操作)。ハンドラを付けないとZoneの未処理
    // エラーとして報告されるため、ここで握りつぶす(CodeRabbit指摘)。
    unawaited(_runSpins().catchError((_) {}, test: (e) => e is TickerCanceled));
  }

  /// 文字を明かさない空フリップを数回行ってから、最後に[text]を1回のフリップで確定させる。
  Future<void> _runSpins() async {
    for (var i = 0; i < kFlapBlankSpinCount; i++) {
      if (!mounted) return;
      _nextText = _kPlaceholderChar;
      await _controller.forward(from: 0);
    }
    if (!mounted) return;
    _nextText = widget.text;
    _controller.duration = _kRevealFlipDuration;
    await _controller.forward(from: 0);
  }

  void _onTick() {
    final next = _nextText;
    if (next != null && _controller.value >= 0.5 && _displayText != next) {
      setState(() => _displayText = next);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 0→0.5でπ/2まで倒れ込み、0.5→1でまた表向きに戻ることで「カードが縦軸で1回転して裏返る」動きを作る(t=0.5の瞬間に文字を差し替える)。
        final t = _controller.value;
        final angle = t < 0.5 ? t * pi : (t - 1) * pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(angle),
          child: child,
        );
      },
      child: Container(
        height: widget.height,
        constraints: const BoxConstraints(minWidth: 190),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kFlapCellBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              _displayText,
              style: GoogleFonts.mochiyPopOne(
                color: _kFlapCellText,
                fontSize: widget.height * 0.42,
              ),
            ),
            // 実物の発車標にある、上下パネルの継ぎ目。
            Positioned(
              left: 0,
              right: 0,
              top: widget.height / 2 - 0.5,
              child: Container(height: 1, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}

/// 現在時刻から朝・昼・夕方・夜のどの時間帯かを判定する。
enum _TimeBand { morning, day, evening, night }

_TimeBand _timeBandForHour(int hour) {
  if (hour >= 5 && hour < 10) return _TimeBand.morning;
  if (hour >= 10 && hour < 16) return _TimeBand.day;
  if (hour >= 16 && hour < 19) return _TimeBand.evening;
  return _TimeBand.night;
}

/// 時間帯ごとの空の配色セット。
class _SkyPalette {
  const _SkyPalette({
    required this.gradientColors,
    required this.gradientStops,
    required this.celestialColor,
    required this.celestialGlow,
    required this.isMoon,
    required this.hillColor,
    required this.cloudColor,
    required this.showStars,
  });

  final List<Color> gradientColors;
  final List<double> gradientStops;
  final Color celestialColor;
  final Color celestialGlow;
  final bool isMoon;
  final Color hillColor;
  final Color cloudColor;
  final bool showStars;

  factory _SkyPalette.forBand(_TimeBand band) {
    switch (band) {
      case _TimeBand.morning:
        return const _SkyPalette(
          gradientColors: [
            Color(0xFFF6C89F),
            Color(0xFFF7D9B0),
            Color(0xFFEFE3C0),
            AppColors.background,
            Color(0xFFDCC99A),
          ],
          gradientStops: [0.0, 0.28, 0.5, 0.68, 1.0],
          celestialColor: Color(0xFFFFE29A),
          celestialGlow: Color(0xFFFFE29A),
          isMoon: false,
          hillColor: Color(0xFFB7C08A),
          cloudColor: Colors.white,
          showStars: false,
        );
      case _TimeBand.day:
        return const _SkyPalette(
          gradientColors: [
            Color(0xFF6FB8D9),
            Color(0xFFA8D8E8),
            Color(0xFFE8F2E0),
            AppColors.background,
            Color(0xFFDCC99A),
          ],
          gradientStops: [0.0, 0.3, 0.55, 0.68, 1.0],
          celestialColor: Color(0xFFF2C230),
          celestialGlow: Color(0xFFF2C230),
          isMoon: false,
          hillColor: Color(0xFFAFC08C),
          cloudColor: Colors.white,
          showStars: false,
        );
      case _TimeBand.evening:
        return const _SkyPalette(
          gradientColors: [
            Color(0xFF3E5C8A),
            Color(0xFFA85C6B),
            Color(0xFFE08A5B),
            Color(0xFFF0B27A),
            Color(0xFFDCC99A),
          ],
          gradientStops: [0.0, 0.35, 0.6, 0.78, 1.0],
          celestialColor: Color(0xFFFF9A56),
          celestialGlow: Color(0xFFFF9A56),
          isMoon: false,
          hillColor: Color(0xFF6E5A6B),
          cloudColor: Color(0xFFF5DCC8),
          showStars: false,
        );
      case _TimeBand.night:
        return const _SkyPalette(
          gradientColors: [
            Color(0xFF0E1A33),
            Color(0xFF1B2B4B),
            Color(0xFF2C3E5C),
            Color(0xFF3A3B4A),
            Color(0xFF2E2A28),
          ],
          gradientStops: [0.0, 0.35, 0.6, 0.8, 1.0],
          celestialColor: Color(0xFFE8E8F0),
          celestialGlow: Color(0xFFC9CEEA),
          isMoon: true,
          hillColor: Color(0xFF23324A),
          cloudColor: Color(0xFF4A5570),
          showStars: true,
        );
    }
  }
}

/// 星空(夜間のみ表示)。固定の座標セットを使い、フレームごとの再計算を避ける。
class _Stars extends StatelessWidget {
  const _Stars();

  static const _positions = [
    Offset(0.08, 0.10),
    Offset(0.20, 0.28),
    Offset(0.35, 0.08),
    Offset(0.50, 0.20),
    Offset(0.62, 0.06),
    Offset(0.78, 0.16),
    Offset(0.88, 0.30),
    Offset(0.94, 0.08),
    Offset(0.15, 0.42),
    Offset(0.70, 0.38),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            for (final p in _positions)
              Positioned(
                left: constraints.maxWidth * p.dx,
                top: constraints.maxHeight * p.dy,
                child: const SizedBox(
                  width: 4,
                  height: 4,
                  child: ColoredBox(color: Colors.white),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 晴天の空・雲・遠くの山並み・電車が線路を走る背景のフラットイラスト(ユーザーフィードバック:「アニメーション中は写真だとゲームっぽさがなくなる、フラットイラストに戻したい」)。
/// 実際の現在時刻に応じて、朝・昼・夕方・夜で空の配色や太陽/月の見た目が変わる。
class _SkyScene extends StatefulWidget {
  const _SkyScene();

  @override
  State<_SkyScene> createState() => _SkySceneState();
}

class _SkySceneState extends State<_SkyScene> with TickerProviderStateMixin {
  late final AnimationController _trainBob;
  late final AnimationController _cloudDrift;
  late final AnimationController _sleepersScroll;
  late final AnimationController _hillsScroll;
  // 画面表示中に日をまたぐことはまず無いため、開いた時点の時刻で固定する。
  late final _SkyPalette _palette = _SkyPalette.forBand(
    _timeBandForHour(DateTime.now().hour),
  );

  @override
  void initState() {
    super.initState();
    _trainBob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _cloudDrift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _sleepersScroll = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    // 山並みも継ぎ目なく連続スクロールさせ、背景が流れている感じを出す。
    _hillsScroll = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _trainBob.dispose();
    _cloudDrift.dispose();
    _sleepersScroll.dispose();
    _hillsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SkyBandsPainter(
        colors: _palette.gradientColors,
        stops: _palette.gradientStops,
      ),
      child: Stack(
        children: [
          if (_palette.showStars) const Positioned.fill(child: _Stars()),
          Positioned(
            top: 40,
            right: 40,
            child: _Sun(
              color: _palette.celestialColor,
              glowColor: _palette.celestialGlow,
              isMoon: _palette.isMoon,
            ),
          ),
          AnimatedBuilder(
            animation: _cloudDrift,
            builder: (context, child) => Positioned(
              top: 64,
              left: 24 + _cloudDrift.value * 24,
              child: child!,
            ),
            child: _Cloud(width: 70, color: _palette.cloudColor),
          ),
          AnimatedBuilder(
            animation: _cloudDrift,
            builder: (context, child) => Positioned(
              top: 108,
              right: 70 + (1 - _cloudDrift.value) * 20,
              child: child!,
            ),
            child: _Cloud(width: 42, color: _palette.cloudColor),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 96,
            height: 90,
            child: AnimatedBuilder(
              animation: _hillsScroll,
              builder: (context, child) => _Hills(
                phase: _hillsScroll.value * 2 * pi,
                color: _palette.hillColor,
              ),
            ),
          ),
          // 地面(線路の土台・砂利)。
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 110,
            child: ColoredBox(color: Color(0xFF4A3F30)),
          ),
          // 枕木(2本のレールの間を渡す木製の板)。地面と紛れないよう、はっきりした木の色でコントラストを付ける。
          Positioned(
            left: 0,
            right: 0,
            bottom: 66,
            height: 30,
            child: AnimatedBuilder(
              animation: _sleepersScroll,
              builder: (context, child) =>
                  _ScrollingSleepers(progress: _sleepersScroll.value),
            ),
          ),
          // レール(2本)。
          const Positioned(left: 0, right: 0, bottom: 96, child: _Rail()),
          const Positioned(left: 0, right: 0, bottom: 66, child: _Rail()),
          // 2両編成は画面幅に収まるため中央寄せにする。
          Positioned(
            left: 0,
            right: 0,
            bottom: 66,
            child: AnimatedBuilder(
              animation: _trainBob,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, -_trainBob.value * 3),
                child: child,
              ),
              child: const Center(child: TrainIllustration()),
            ),
          ),
        ],
      ),
    );
  }
}

/// 空を階段状の色帯で塗る。グラデーションの代わりに、時間帯の配色を一定の
/// 高さごとの単色に量子化して、ドット絵の空にする。
class _SkyBandsPainter extends CustomPainter {
  const _SkyBandsPainter({required this.colors, required this.stops});

  final List<Color> colors;
  final List<double> stops;

  static const _bandHeight = 12.0;

  Color _colorAt(double t) {
    for (var i = 1; i < stops.length; i++) {
      if (t <= stops[i]) {
        final span = stops[i] - stops[i - 1];
        return Color.lerp(colors[i - 1], colors[i], (t - stops[i - 1]) / span)!;
      }
    }
    return colors.last;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0.0; y < size.height; y += _bandHeight) {
      paint.color = _colorAt((y + _bandHeight / 2) / size.height);
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, _bandHeight + 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SkyBandsPainter oldDelegate) =>
      oldDelegate.colors != colors || oldDelegate.stops != stops;
}

/// 太陽・月。円を4pxのマスで塗った階段状の円盤にし、外側に淡い1マス分の
/// 光の輪を添える。月は円盤の一部をくり抜いて三日月にする。
class _Sun extends StatelessWidget {
  const _Sun({
    this.color = const Color(0xFFF2C230),
    this.glowColor = const Color(0xFFF2C230),
    this.isMoon = false,
  });

  final Color color;
  final Color glowColor;
  final bool isMoon;

  static const _cell = 4.0;

  @override
  Widget build(BuildContext context) {
    // 夜は月なので一回り小さくする。光の輪の分だけ外側に余白を取る。
    final cells = isMoon ? 11 : 14;
    return SizedBox(
      width: cells * _cell,
      height: cells * _cell,
      child: CustomPaint(
        painter: _SunPainter(
          cells: cells,
          color: color,
          glowColor: glowColor,
          isMoon: isMoon,
        ),
      ),
    );
  }
}

class _SunPainter extends CustomPainter {
  const _SunPainter({
    required this.cells,
    required this.color,
    required this.glowColor,
    required this.isMoon,
  });

  final int cells;
  final Color color;
  final Color glowColor;
  final bool isMoon;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    final cell = size.width / cells;
    final center = (cells - 1) / 2;
    final radius = cells / 2 - 1.5;
    final glowRadius = radius + 1.5;
    // 三日月のくり抜き用の円(右上にずらす)。
    final cutX = center + 2.2;
    final cutY = center - 2.2;
    final cutRadius = radius * 0.85;

    for (var iy = 0; iy < cells; iy++) {
      for (var ix = 0; ix < cells; ix++) {
        final dx = ix - center;
        final dy = iy - center;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist > glowRadius) continue;
        if (dist > radius) {
          paint.color = glowColor.withValues(alpha: isMoon ? 0.25 : 0.35);
        } else {
          if (isMoon) {
            final cx = ix - cutX;
            final cy = iy - cutY;
            if (sqrt(cx * cx + cy * cy) < cutRadius) continue;
          }
          paint.color = color;
        }
        canvas.drawRect(Rect.fromLTWH(ix * cell, iy * cell, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SunPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.glowColor != glowColor ||
      oldDelegate.isMoon != isMoon;
}

/// 雲(14×4マスのドット絵)。時間帯に応じて色を変え、最下段だけ少し暗くして
/// 厚みを出す。`width`は14の倍数にすると、マスがきれいな整数pxになる。
class _Cloud extends StatelessWidget {
  const _Cloud({required this.width, this.color = Colors.white});

  final double width;
  final Color color;

  static const _pattern = [
    '.....XXXX.....',
    '..XX.XXXXXX...',
    '.XXXXXXXXXXXX.',
    'XXXXXXXXXXXXXX',
  ];

  @override
  Widget build(BuildContext context) {
    final cell = width / _pattern.first.length;
    return SizedBox(
      width: width,
      height: cell * _pattern.length,
      child: CustomPaint(painter: _CloudPainter(color)),
    );
  }
}

class _CloudPainter extends CustomPainter {
  const _CloudPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    final cell = size.width / _Cloud._pattern.first.length;
    final shade = Color.lerp(color, Colors.black, 0.1)!;
    for (var iy = 0; iy < _Cloud._pattern.length; iy++) {
      final row = _Cloud._pattern[iy];
      paint.color = iy == _Cloud._pattern.length - 1 ? shade : color;
      for (var ix = 0; ix < row.length; ix++) {
        if (row[ix] != 'X') continue;
        canvas.drawRect(Rect.fromLTWH(ix * cell, iy * cell, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CloudPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 遠くの山並みのシルエット。正弦波ベースの波形を6pxのマスに量子化して
/// 階段状にし、継ぎ目なく連続で左にスクロールさせられるようにしている
/// (ユーザーフィードバック:「背景が流れてる感じになってないから動いてる
/// ように見えない」)。
class _Hills extends StatelessWidget {
  const _Hills({required this.phase, this.color = const Color(0xFFAFC08C)});

  final double phase;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HillsPainter(phase, color),
      size: Size.infinite,
    );
  }
}

class _HillsPainter extends CustomPainter {
  const _HillsPainter(this.phase, this.color);

  final double phase;
  final Color color;

  static const _period = 160.0;
  static const _amplitude = 18.0;
  static const _cell = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = false
      ..color = color;
    for (var x = 0.0; x < size.width; x += _cell) {
      final wave = sin(((x + _cell / 2) / _period) * 2 * pi + phase);
      final y = size.height * 0.4 - _amplitude * wave;
      final top = (y / _cell).round() * _cell;
      canvas.drawRect(Rect.fromLTRB(x, top, x + _cell, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HillsPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}

/// レール1本。地面(こげ茶)から浮き上がって見えるよう金属色にし、上端に明るいハイライトを重ねて立体感を出す(2pxのドット単位)。
class _Rail extends StatelessWidget {
  const _Rail();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 2, color: const Color(0xFFD8DCDD)),
        Container(height: 4, color: const Color(0xFF6B7176)),
      ],
    );
  }
}

/// 線路の枕木(2本のレールの間を渡す木製の板)。左に流れているように見せるためスクロールさせる。
/// 角の丸みは付けず、位置も整数pxに丸めてドット絵の見た目をそろえる。
class _ScrollingSleepers extends StatelessWidget {
  const _ScrollingSleepers({required this.progress});

  final double progress;

  static const _period = 24.0;
  static const _tieWidth = 12.0;

  @override
  Widget build(BuildContext context) {
    // 枕木はスクロール用にわざと表示幅より広く並べている。Row/Flexだとデバッグ時に常に「はみ出し」警告が描画されてしまう仕様のため、Positioned付きのStackで組んで警告そのものを起こさないようにする。
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = (constraints.maxWidth / _period).ceil() + 2;
          final baseOffset = (-progress * _period).floorToDouble();
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (var i = 0; i < count; i++)
                Positioned(
                  left: baseOffset + i * _period,
                  top: 0,
                  bottom: 0,
                  child: const SizedBox(
                    width: _tieWidth,
                    child: Column(
                      children: [
                        Expanded(child: ColoredBox(color: Color(0xFF6B4A2E))),
                        SizedBox(
                          height: 2,
                          child: ColoredBox(color: Color(0xFF4F3520)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
