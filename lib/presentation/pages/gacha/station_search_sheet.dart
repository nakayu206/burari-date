import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/entities/station.dart';
import '../../providers/station_providers.dart';

/// このモーダル内の全要素間の縦ギャップ。Figmaのノード座標では実測14pxだったが、
/// 他画面と同じ16pxリズムに統一し、デザイントークンからの逸脱をなくした
/// (docs/デザイントークン.md参照)。
const _kGap = AppSpacing.lg;

/// S-02b 出発駅検索(サジェスト)。S-02 の出発駅欄タップでモーダル表示する。
Future<Station?> showStationSearchSheet(BuildContext context) {
  return showModalBottomSheet<Station>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _StationSearchSheet(),
  );
}

class _StationSearchSheet extends ConsumerStatefulWidget {
  const _StationSearchSheet();

  @override
  ConsumerState<_StationSearchSheet> createState() =>
      _StationSearchSheetState();
}

class _StationSearchSheetState extends ConsumerState<_StationSearchSheet> {
  final _controller = TextEditingController();
  List<Station> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final repository = ref.read(stationRepositoryProvider);
    setState(() => _results = repository.searchStations(value));
  }

  @override
  Widget build(BuildContext context) {
    final stationRepository = ref.watch(stationRepositoryProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '出発駅',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSizes.labelSmall,
            ),
          ),
          const SizedBox(height: _kGap),
          Container(
            height: AppSizes.inputHeight,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.secondary, width: 2),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.train_rounded,
                  size: AppSizes.iconSm,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    onChanged: _onChanged,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppFontSizes.bodyLarge,
                    ),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: '駅名を入力',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _kGap),
          const Text(
            '候補',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSizes.caption,
            ),
          ),
          const SizedBox(height: _kGap),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (_, _) => const SizedBox(height: _kGap),
              itemBuilder: (context, index) {
                final station = _results[index];
                final line = stationRepository.findLineForStation(station);
                return Material(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => Navigator.of(context).pop(station),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 8,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                station.name,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: AppFontSizes.bodyLarge,
                                ),
                              ),
                              if (line != null)
                                Text(
                                  line.name,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: AppFontSizes.caption,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: _kGap),
          const Text(
            '※タップすると入力欄に反映され、キーボードは閉じる',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSizes.footnote,
            ),
          ),
        ],
      ),
    );
  }
}
