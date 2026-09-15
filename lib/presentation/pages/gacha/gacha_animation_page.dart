import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/entities/gacha_result.dart';
import 'arrival_result_page.dart';

// このファイルのアニメーション設計は、ユーザー提供の参考実装
// (gacha_split_flap_train_bg_sunny.html: 1文字ずつのセルが段差をつけて
// 1回だけパタッとめくれる発車標)に忠実に合わせている。
// パラパラと何度もランダム表示してから確定する旧実装ではなく、
// 各セルが「プレースホルダー→最終文字」に一度だけフリップする。

/// 1セルのフリップにかかる時間。
const _kFlipDuration = Duration(milliseconds: 420);

/// 同じ行の中で、セルごとにフリップを開始する時間差(左から順に確定していく)。
const _kFlipStagger = Duration(milliseconds: 220);

/// 上段(駅数)が確定してから下段(到着駅名)のフリップが始まるまでの間。
const _kInterRowPause = Duration(milliseconds: 500);

/// 確定してから次画面へ自動遷移するまでの間。結果を読む時間を確保する
/// (ユーザーフィードバック: 「決まってから画面移動もはやい」)。
const _kResultHoldDuration = Duration(milliseconds: 2200);

const _kFlapCellBackground = Color(0xFF1B1B1B);
const _kFlapCellText = Color(0xFFF2C98A);
const _kCaptionColor = Color(0xFFD99A2B);
const _kPlaceholderChar = '−';

/// S-03 ガチャ演出画面。晴天の空・電車が線路を走る背景の上に、発車標
/// (スプリットフラップ)風のセルが1文字ずつ段差をつけてパタッと確定する。
class GachaAnimationPage extends StatefulWidget {
  const GachaAnimationPage({super.key, required this.result});

  final GachaResult result;

  @override
  State<GachaAnimationPage> createState() => _GachaAnimationPageState();
}

enum _Phase { stops, arrival, done }

class _GachaAnimationPageState extends State<GachaAnimationPage> {
  late final List<String> _row1Chars;
  late final List<String> _row2Chars;
  _Phase _phase = _Phase.stops;
  String _caption1 = '駅隣を決定中…';
  String _caption2 = '';
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _row1Chars = '${widget.result.stopsCount}駅隣'.split('');
    _row2Chars = widget.result.arrivalStation.name.split('');
    _runSequence();
  }

  Duration _rowDuration(int cellCount) =>
      _kFlipStagger * (cellCount - 1) + _kFlipDuration;

  Future<void> _runSequence() async {
    await Future.delayed(_rowDuration(_row1Chars.length));
    if (!mounted) return;
    setState(() {
      _caption1 = '${widget.result.stopsCount}駅隣に決定!';
      _phase = _Phase.arrival;
    });

    await Future.delayed(_kInterRowPause);
    if (!mounted) return;
    setState(() => _caption2 = '到着駅を表示中…');

    await Future.delayed(_rowDuration(_row2Chars.length));
    if (!mounted) return;
    setState(() {
      _caption2 = '到着駅：${widget.result.arrivalStation.name}';
      _phase = _Phase.done;
      _finished = true;
    });

    await Future.delayed(_kResultHoldDuration);
    _goToResult();
  }

  void _goToResult() {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ArrivalResultPage(result: widget.result),
      ),
    );
  }

  void _skip() => _goToResult();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ガチャ演出')),
      body: GestureDetector(
        onTap: _finished ? null : _skip,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _SkyScene(),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.x3l),
                  _FlapBoard(
                    row1Chars: _row1Chars,
                    row2Chars: _row2Chars,
                    caption1: _caption1,
                    caption2: _caption2,
                    showRow2: _phase != _Phase.stops,
                  ),
                  const Spacer(),
                  if (!_finished)
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
                  const SizedBox(height: AppSpacing.x2l),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 発車標の見た目をまとめたオーバーレイ(駅数の行 + キャプション + 到着駅名の行)。
class _FlapBoard extends StatelessWidget {
  const _FlapBoard({
    required this.row1Chars,
    required this.row2Chars,
    required this.caption1,
    required this.caption2,
    required this.showRow2,
  });

  final List<String> row1Chars;
  final List<String> row2Chars;
  final String caption1;
  final String caption2;
  final bool showRow2;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.87),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FlapRow(chars: row1Chars, cellWidth: 38, cellHeight: 46),
          const SizedBox(height: AppSpacing.sm),
          Text(
            caption1,
            style: const TextStyle(
              color: _kCaptionColor,
              fontSize: AppFontSizes.caption,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Opacity(
            opacity: showRow2 ? 1 : 0,
            child: _FlapRow(chars: row2Chars, cellWidth: 34, cellHeight: 42),
          ),
          const SizedBox(height: AppSpacing.sm),
          Opacity(
            opacity: showRow2 ? 1 : 0,
            child: Text(
              caption2.isEmpty ? ' ' : caption2,
              style: const TextStyle(
                color: _kCaptionColor,
                fontSize: AppFontSizes.caption,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 1文字ずつのフリップセルを、左から順に段差をつけて並べた行。
class _FlapRow extends StatelessWidget {
  const _FlapRow({
    required this.chars,
    required this.cellWidth,
    required this.cellHeight,
  });

  final List<String> chars;
  final double cellWidth;
  final double cellHeight;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < chars.length; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            _FlapCell(
              finalChar: chars[i],
              startDelay: _kFlipStagger * i,
              width: cellWidth,
              height: cellHeight,
            ),
          ],
        ],
      ),
    );
  }
}

/// 発車標の1セル。表示開始から[startDelay]後に、プレースホルダーから
/// [finalChar]へ縦軸で1回だけパタッとフリップする。
class _FlapCell extends StatefulWidget {
  const _FlapCell({
    required this.finalChar,
    required this.startDelay,
    required this.width,
    required this.height,
  });

  final String finalChar;
  final Duration startDelay;
  final double width;
  final double height;

  @override
  State<_FlapCell> createState() => _FlapCellState();
}

class _FlapCellState extends State<_FlapCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  String _displayChar = _kPlaceholderChar;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _kFlipDuration)
      ..addListener(_onTick);
    _startTimer = Timer(widget.startDelay, () {
      if (mounted) _controller.forward();
    });
  }

  void _onTick() {
    if (_controller.value >= 0.5 && _displayChar != widget.finalChar) {
      setState(() => _displayChar = widget.finalChar);
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 0→0.5でπ/2まで倒れ込み(裏面向き)、0.5→1でまた表向きに戻ることで
        // 「カードが縦軸で1回転して裏返る」動きを作る。t=0.5の瞬間は
        // ほぼ真横を向いていて見えないので、そのタイミングで文字を差し替える。
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
        width: widget.width,
        height: widget.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kFlapCellBackground,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              _displayChar,
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

/// 晴天の空・雲・遠くの山並み・電車が線路を走る背景(仕様書4.2 S-03)。
/// 本格イラストはFigmaで別途用意予定のため、簡易な図形構成の仮イラスト。
class _SkyScene extends StatefulWidget {
  const _SkyScene();

  @override
  State<_SkyScene> createState() => _SkySceneState();
}

class _SkySceneState extends State<_SkyScene> with TickerProviderStateMixin {
  late final AnimationController _trainBob;
  late final AnimationController _cloudDrift;
  late final AnimationController _sleepersScroll;

  @override
  void initState() {
    super.initState();
    // 電車の微震動(仕様書4.2「電車シルエットは微震動」)。
    _trainBob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _cloudDrift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _sleepersScroll = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..repeat();
  }

  @override
  void dispose() {
    _trainBob.dispose();
    _cloudDrift.dispose();
    _sleepersScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF6FB8D9),
            Color(0xFFA8D8E8),
            Color(0xFFE8F2E0),
            AppColors.background,
            Color(0xFFDCC99A),
          ],
          stops: [0.0, 0.3, 0.55, 0.68, 1.0],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(top: 40, right: 40, child: _Sun()),
          AnimatedBuilder(
            animation: _cloudDrift,
            builder: (context, child) => Positioned(
              top: 64,
              left: 24 + _cloudDrift.value * 24,
              child: child!,
            ),
            child: const _Cloud(width: 70),
          ),
          AnimatedBuilder(
            animation: _cloudDrift,
            builder: (context, child) => Positioned(
              top: 108,
              right: 70 + (1 - _cloudDrift.value) * 20,
              child: child!,
            ),
            child: const _Cloud(width: 44),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 96,
            height: 90,
            child: _Hills(),
          ),
          // 地面(線路の土台)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 110,
            child: ColoredBox(color: Color(0xFF4A3F30)),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 86,
            child: AnimatedBuilder(
              animation: _sleepersScroll,
              builder: (context, child) =>
                  _ScrollingSleepers(progress: _sleepersScroll.value),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 96,
            child: ColoredBox(
              color: AppColors.textSecondary,
              child: SizedBox(height: 3),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 66,
            child: ColoredBox(
              color: AppColors.textSecondary,
              child: SizedBox(height: 3),
            ),
          ),
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
              child: const Center(child: _Train()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sun extends StatelessWidget {
  const _Sun();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF2C230),
        border: Border.all(color: AppColors.textPrimary, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF2C230).withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _Cloud extends StatelessWidget {
  const _Cloud({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withValues(alpha: 0.85);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width * 0.6,
          height: width * 0.28,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        Transform.translate(
          offset: Offset(-width * 0.15, -width * 0.12),
          child: Container(
            width: width * 0.4,
            height: width * 0.22,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    );
  }
}

/// 遠くの山並みのシルエット。
class _Hills extends StatelessWidget {
  const _Hills();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _HillsPainter(), size: Size.infinite);
  }
}

class _HillsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6B9B6E).withValues(alpha: 0.35);
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.6)
      ..lineTo(size.width * 0.15, size.height * 0.35)
      ..lineTo(size.width * 0.30, size.height * 0.62)
      ..lineTo(size.width * 0.45, size.height * 0.25)
      ..lineTo(size.width * 0.60, size.height * 0.55)
      ..lineTo(size.width * 0.75, size.height * 0.15)
      ..lineTo(size.width * 0.90, size.height * 0.48)
      ..lineTo(size.width, size.height * 0.32)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HillsPainter oldDelegate) => false;
}

/// 線路の枕木。左に流れているように見せるためスクロールさせる。
class _ScrollingSleepers extends StatelessWidget {
  const _ScrollingSleepers({required this.progress});

  final double progress;

  static const _period = 26.0;
  static const _dashWidth = 10.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 6,
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final count = (constraints.maxWidth / _period).ceil() + 2;
            final offset = -progress * _period;
            return Transform.translate(
              offset: Offset(offset, 0),
              child: Row(
                children: List.generate(
                  count,
                  (i) => Padding(
                    padding: const EdgeInsets.only(right: _period - _dashWidth),
                    child: Container(
                      width: _dashWidth,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Train extends StatelessWidget {
  const _Train();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ポール(パンタグラフ支柱の簡略表現)
          Positioned(
            top: 0,
            left: 58,
            child: Container(
              width: 2,
              height: 12,
              color: AppColors.textPrimary,
            ),
          ),
          // 車体
          Positioned(
            left: 6,
            right: 6,
            top: 12,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                border: Border.all(color: AppColors.textPrimary, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          // 窓
          Positioned(
            left: 16,
            top: 22,
            child: Row(
              children: List.generate(
                4,
                (_) => Container(
                  width: 18,
                  height: 14,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border.all(
                      color: AppColors.textPrimary,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          // 車輪
          const Positioned(left: 16, bottom: 0, child: _Wheel()),
          const Positioned(left: 44, bottom: 0, child: _Wheel()),
          const Positioned(right: 44, bottom: 0, child: _Wheel()),
          const Positioned(right: 16, bottom: 0, child: _Wheel()),
        ],
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: const BoxDecoration(
        color: AppColors.textPrimary,
        shape: BoxShape.circle,
      ),
    );
  }
}
