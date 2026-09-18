import 'dart:async';

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
  bool _isSearching = false;
  bool _hasError = false;
  Timer? _debounce;

  /// 連打/連続入力のたびにAPIを叩かないよう、入力が止まってから検索する。
  static const _debounceDuration = Duration(milliseconds: 400);

  /// awaitの間に別の検索が走った場合、古い結果を捨てるための通し番号。
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // 通し番号はデバウンス発火時ではなく、入力が変わった時点で進める。
    // でないと「Aで検索中(通信待ち)→デバウンス中にABへ変更」のケースで、
    // Aの結果がABの表示中に届いても無効化できない
    // (CodeRabbit指摘: search Aがデバウンス期間中に完了しうる)。
    final requestId = ++_requestId;
    if (value.isEmpty) {
      setState(() {
        _results = const [];
        _isSearching = false;
        _hasError = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(_debounceDuration, () => _search(value, requestId));
  }

  Future<void> _search(String query, int requestId) async {
    final repository = ref.read(stationRepositoryProvider);
    List<Station> results;
    var hasError = false;
    try {
      results = await repository.searchStations(query);
    } on Exception {
      results = const [];
      hasError = true;
    }
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _results = results;
      _isSearching = false;
      _hasError = hasError;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              const Text(
                '候補',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFontSizes.caption,
                ),
              ),
              if (_isSearching) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          if (_hasError) ...[
            const SizedBox(height: 4),
            const Text(
              '検索に失敗しました。通信環境をご確認ください。',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: AppFontSizes.footnote,
              ),
            ),
          ],
          const SizedBox(height: _kGap),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (_, _) => const SizedBox(height: _kGap),
              itemBuilder: (context, index) {
                final station = _results[index];
                // HeartRails Express実装ではlineIdが路線の表示名そのものなので、
                // 一覧表示のためだけに1行ずつ路線検索APIを呼ばずに済む。
                final lineName = station.lineId;
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
                              Text(
                                lineName,
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
