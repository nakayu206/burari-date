import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
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
    final maxStopsBound = line == null
        ? 15.0
        : (line.stations.length - 1).toDouble();
    final stopsRange = RangeValues(
      formState.minStops.toDouble(),
      formState.maxStops.toDouble(),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('出発駅・路線を選ぶ')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '出発駅',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 6),
              _SelectField(
                label: formState.departure?.name ?? '駅名を入力(サジェスト表示)',
                onTap: () => _pickDeparture(context, ref),
              ),
              const SizedBox(height: 20),
              const Text(
                '路線',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 6),
              _SelectField(
                label: line?.name ?? '路線を選択',
                onTap: formState.departure == null
                    ? null
                    : () => _pickDeparture(context, ref),
              ),
              const SizedBox(height: 28),
              Text(
                '駅数範囲: ${formState.minStops}〜${formState.maxStops}駅隣',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
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
              const SizedBox(height: 12),
              const Text(
                '方面',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 32),
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
        height: 44,
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
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}
