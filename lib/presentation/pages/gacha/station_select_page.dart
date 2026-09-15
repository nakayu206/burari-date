import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/entities/railway_line.dart';
import '../../providers/gacha_form_provider.dart';
import 'gacha_animation_page.dart';
import 'station_search_sheet.dart';

/// S-02 出発駅・路線・駅数範囲選択画面
class StationSelectPage extends ConsumerWidget {
  const StationSelectPage({super.key});

  Future<void> _pickDeparture(BuildContext context, WidgetRef ref) async {
    final station = await showStationSearchSheet(context);
    if (station == null) return;
    ref.read(gachaFormProvider.notifier).selectDeparture(station);
  }

  void _startGacha(BuildContext context, WidgetRef ref) {
    final result = ref.read(gachaFormProvider.notifier).runGacha();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GachaAnimationPage(result: result)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(gachaFormProvider);
    final line = formState.line;
    final maxStopsBound = formState.maxSelectableStops.toDouble();
    final stopsRange = RangeValues(
      formState.minStops.toDouble(),
      formState.maxStops.toDouble(),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('出発駅・路線を選ぶ')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '出発駅',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFontSizes.labelSmall,
                ),
              ),
              const SizedBox(height: 6),
              _SelectField(
                label: formState.departure?.name ?? '駅名を入力(サジェスト表示)',
                onTap: () => _pickDeparture(context, ref),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                '路線',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFontSizes.labelSmall,
                ),
              ),
              const SizedBox(height: 6),
              _SelectField(
                label: line?.name ?? '路線を選択',
                onTap: formState.departure == null
                    ? null
                    : () => _pickDeparture(context, ref),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '駅数範囲: ${formState.minStops}〜${formState.maxStops}駅隣',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppFontSizes.bodyMedium,
                ),
              ),
              RangeSlider(
                values: stopsRange,
                min: 1,
                max: maxStopsBound < 2 ? 2 : maxStopsBound,
                divisions: (maxStopsBound < 2 ? 2 : maxStopsBound).round() - 1,
                activeColor: AppColors.primary,
                labels: RangeLabels(
                  '${formState.minStops}',
                  '${formState.maxStops}',
                ),
                onChanged: (values) => ref
                    .read(gachaFormProvider.notifier)
                    .updateStopsRange(values.start.round(), values.end.round()),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StopsStepper(
                    label: '最小',
                    value: formState.minStops,
                    onDecrement: () => ref
                        .read(gachaFormProvider.notifier)
                        .decrementMinStops(),
                    onIncrement: () => ref
                        .read(gachaFormProvider.notifier)
                        .incrementMinStops(),
                  ),
                  _StopsStepper(
                    label: '最大',
                    value: formState.maxStops,
                    onDecrement: () => ref
                        .read(gachaFormProvider.notifier)
                        .decrementMaxStops(),
                    onIncrement: () => ref
                        .read(gachaFormProvider.notifier)
                        .incrementMaxStops(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                '方面',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFontSizes.labelSmall,
                ),
              ),
              const SizedBox(height: 6),
              SegmentedButton<GachaDirection>(
                segments: [
                  ButtonSegment(
                    value: GachaDirection.up,
                    label: Text(
                      line == null ? '○○方面' : '${line.endTerminus.name}方面',
                    ),
                  ),
                  ButtonSegment(
                    value: GachaDirection.down,
                    label: Text(
                      line == null ? '△△方面' : '${line.startTerminus.name}方面',
                    ),
                  ),
                  const ButtonSegment(
                    value: GachaDirection.random,
                    label: Text('おまかせ'),
                  ),
                ],
                selected: {formState.direction},
                onSelectionChanged: (selection) => ref
                    .read(gachaFormProvider.notifier)
                    .updateDirection(selection.first),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: formState.canStartGacha
                    ? () => _startGacha(context, ref)
                    : null,
                child: const Text('ガチャをする'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 駅数範囲の1駅単位の微調整用ステッパー(Issue #38)。
/// スライダーは大まかな調整、こちらは正確な値の指定に使う。
class _StopsStepper extends StatelessWidget {
  const _StopsStepper({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final int value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppFontSizes.labelSmall,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepperButton(
              icon: Icons.remove_circle_outline,
              onTap: onDecrement,
            ),
            SizedBox(
              width: 44,
              child: Text(
                '$value駅',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppFontSizes.bodyLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _StepperButton(icon: Icons.add_circle_outline, onTap: onIncrement),
          ],
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.primary, size: AppSizes.iconMd),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }
}

class _SelectField extends StatelessWidget {
  const _SelectField({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: AppSizes.inputHeight,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.textSecondary),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppFontSizes.bodyMedium,
          ),
        ),
      ),
    );
  }
}
