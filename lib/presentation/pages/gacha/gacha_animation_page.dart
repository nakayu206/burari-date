import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/entities/gacha_result.dart';
import 'arrival_result_page.dart';

/// S-03 ガチャ演出画面。発車標(スプリットフラップ)風に上下2パネルが
/// パラパラとフリップしてから、駅数→到着駅の順に確定する。
class GachaAnimationPage extends StatefulWidget {
  const GachaAnimationPage({super.key, required this.result});

  final GachaResult result;

  @override
  State<GachaAnimationPage> createState() => _GachaAnimationPageState();
}

enum _Phase { stops, arrival, done }

class _GachaAnimationPageState extends State<GachaAnimationPage> {
  final _random = Random();
  _Phase _phase = _Phase.stops;
  String _topPanel = '?駅隣';
  String _bottomPanel = '到着駅：―';
  String _caption = '駅隣を決定中…';
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _runSequence();
  }

  Future<void> _runSequence() async {
    // 上パネル: 何駅隣か をパラパラ確定させる
    for (var i = 0; i < 8; i++) {
      if (!mounted) return;
      setState(() => _topPanel = '${_random.nextInt(9) + 1}駅隣…?');
      await Future.delayed(const Duration(milliseconds: 90));
    }
    if (!mounted) return;
    setState(() {
      _topPanel = '${widget.result.stopsCount}駅隣に決定!';
      _caption = '到着駅を表示中…';
      _phase = _Phase.arrival;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    // 下パネル: 到着駅名 をパラパラ確定させる
    final dummyNames = widget.result.line.stations.map((s) => s.name).toList();
    for (var i = 0; i < 8; i++) {
      if (!mounted) return;
      setState(
        () => _bottomPanel = dummyNames[_random.nextInt(dummyNames.length)],
      );
      await Future.delayed(const Duration(milliseconds: 90));
    }
    if (!mounted) return;
    setState(() {
      _bottomPanel = '到着駅：${widget.result.arrivalStation.name}';
      _caption = '到着駅：${widget.result.arrivalStation.name}';
      _phase = _Phase.done;
      _finished = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));
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
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FlipPanel(text: _topPanel),
              const SizedBox(height: AppSpacing.x2l),
              _FlipPanel(text: _phase == _Phase.stops ? '' : _bottomPanel),
              const SizedBox(height: AppSpacing.x4l),
              Text(
                _caption,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFontSizes.bodyMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.x4l),
              if (!_finished)
                const Text(
                  '(タップでスキップ)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFontSizes.caption,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlipPanel extends StatelessWidget {
  const _FlipPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox(height: 60);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 80),
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x2l,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.background,
            fontSize: AppFontSizes.headlineLarge,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
