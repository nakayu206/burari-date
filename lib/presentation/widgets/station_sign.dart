import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_train_colors.dart';

/// ガチャ結果の駅名標(Issue #121)。駅のホームにある看板のように、中央に到着駅、
/// 下に緑の矢印の帯を置く。矢印は、左が[onReroll]、右が[onViewCandidates]の
/// 操作になる。背景の電車と同じく、曲線やぼかしを使わず、ブロックだけで描く。
class StationSign extends StatelessWidget {
  const StationSign({
    super.key,
    required this.stationName,
    required this.lineName,
    required this.stopsCount,
    required this.onReroll,
    required this.onViewCandidates,
  });

  final String stationName;
  final String lineName;
  final int stopsCount;
  final VoidCallback onReroll;
  final VoidCallback onViewCandidates;

  /// 板の1ドットの大きさ(論理px)。
  static const _cell = 4.0;

  /// 矢印の帯の高さ。タップの範囲として十分な大きさ(48以上)にする。
  static const _bandHeight = 52.0;

  /// 吊り下げの支柱の高さ。
  static const _poleHeight = 14.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 天井から吊るす2本の支柱。
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 36),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_Pole(), _Pole()],
          ),
        ),
        CustomPaint(
          painter: const _BoardPainter(cell: _cell),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _cell * 3,
              _cell * 3,
              _cell * 3,
              _cell * 3,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lineName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTrainColors.roofGrey,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                // 長い駅名でも、板からはみ出さないよう縮めて収める。
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(stationName, maxLines: 1, style: _nameText()),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$stopsCount駅隣',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTrainColors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _ArrowButton(
                        label: 'もう一度ガチャ',
                        pointsLeft: true,
                        onTap: onReroll,
                      ),
                    ),
                    // 写真の駅名標と同じ、帯の中央の青い区切り。
                    Container(
                      width: _cell * 2,
                      height: _bandHeight,
                      color: _blue,
                    ),
                    Expanded(
                      child: _ArrowButton(
                        label: 'この駅に行く',
                        pointsLeft: false,
                        onTap: onViewCandidates,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static const _blue = Color(0xFF2E57C8);

  /// ドット書体は、大きくて短い文字(駅名)だけに使う。小さい文字は、読みやすい
  /// 普通の書体のままにする。
  static TextStyle _nameText() =>
      GoogleFonts.dotGothic16(color: AppTrainColors.outline, fontSize: 36);
}

class _Pole extends StatelessWidget {
  const _Pole();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: StationSign._cell * 2,
      height: StationSign._poleHeight,
      color: AppTrainColors.outline,
    );
  }
}

/// 帯の左右の矢印。押している間は、色を濃くする。
class _ArrowButton extends StatefulWidget {
  const _ArrowButton({
    required this.label,
    required this.pointsLeft,
    required this.onTap,
  });

  final String label;
  final bool pointsLeft;
  final VoidCallback onTap;

  @override
  State<_ArrowButton> createState() => _ArrowButtonState();
}

class _ArrowButtonState extends State<_ArrowButton> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed != value) setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    // 矢印の先の部分に文字がかからないよう、先の側の余白を広げる。
    const tip = StationSign._cell * 6;
    const gap = StationSign._cell * 2;
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: CustomPaint(
          painter: _ArrowPainter(
            cell: StationSign._cell,
            pointsLeft: widget.pointsLeft,
            isPressed: _isPressed,
          ),
          child: SizedBox(
            height: StationSign._bandHeight,
            child: Padding(
              padding: EdgeInsets.only(
                left: widget.pointsLeft ? tip : gap,
                right: widget.pointsLeft ? gap : tip,
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 板。暗い枠の内側に、クリーム色の面。角は1ドット分だけ欠かす。
class _BoardPainter extends CustomPainter {
  const _BoardPainter({required this.cell});

  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;

    void block(double x, double y, double w, double h, Color color) {
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint..color = color);
    }

    // 角を欠いた長方形(階段状)を塗る。
    void notched(double inset, Color color) {
      final w = size.width - inset * 2;
      final h = size.height - inset * 2;
      block(inset + cell, inset, w - cell * 2, h, color);
      block(inset, inset + cell, w, h - cell * 2, color);
    }

    notched(0, AppTrainColors.outline);
    notched(cell, AppTrainColors.cream);
    // 板の下側に、ひと段濃い面を敷いて、厚みを出す。
    block(
      cell * 2,
      size.height - cell * 2,
      size.width - cell * 4,
      cell,
      const Color(0xFFD7CFB4),
    );
  }

  @override
  bool shouldRepaint(_BoardPainter oldDelegate) => oldDelegate.cell != cell;
}

/// 矢印の帯。先端(左向きなら左端)を、1ドットずつの階段で尖らせる。
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({
    required this.cell,
    required this.pointsLeft,
    required this.isPressed,
  });

  final double cell;
  final bool pointsLeft;
  final bool isPressed;

  static const _greenPressed = Color(0xFF2D503B);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    final rows = (size.height / cell).floor();
    final center = (rows - 1) / 2;
    final base = isPressed ? _greenPressed : AppTrainColors.green;

    for (var r = 0; r < rows; r++) {
      // 中央の行ほど、先端が外に出る。上下の端の行は、先端の内側から始まる。
      final inset = ((r - center).abs()) * cell;
      final left = pointsLeft ? inset : 0.0;
      final width = size.width - inset;
      final color = r == rows - 1 ? _greenPressed : base;
      canvas.drawRect(
        Rect.fromLTWH(left, r * cell, width, cell),
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      oldDelegate.pointsLeft != pointsLeft ||
      oldDelegate.isPressed != isPressed ||
      oldDelegate.cell != cell;
}
