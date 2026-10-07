import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/entities/candidate.dart';
import '../../../domain/entities/gacha_result.dart';
import '../../../domain/entities/station.dart';
import '../../../domain/repositories/candidate_repository.dart';
import '../../providers/auth_providers.dart';
import '../../providers/candidate_providers.dart';
import '../../widgets/pixel_icon.dart';
import 'candidate_detail_page.dart';
import 'limit_reached_view.dart';

/// S-05 候補一覧画面(グルメ/観光タブ)
class CandidateListPage extends ConsumerStatefulWidget {
  const CandidateListPage({super.key, required this.result});

  final GachaResult result;

  @override
  ConsumerState<CandidateListPage> createState() => _CandidateListPageState();
}

class _CandidateListPageState extends ConsumerState<CandidateListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('おでかけスポット'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(
            fontSize: AppFontSizes.bodyMedium,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: AppFontSizes.bodyMedium,
            fontWeight: FontWeight.normal,
          ),
          tabs: const [
            Tab(text: 'グルメ'),
            Tab(text: '観光'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CandidateListTab(
            result: widget.result,
            category: CandidateCategory.gourmet,
          ),
          _CandidateListTab(
            result: widget.result,
            category: CandidateCategory.sightseeing,
          ),
        ],
      ),
    );
  }
}

class _CandidateListTab extends ConsumerStatefulWidget {
  const _CandidateListTab({required this.result, required this.category});

  final GachaResult result;
  final CandidateCategory category;

  @override
  ConsumerState<_CandidateListTab> createState() => _CandidateListTabState();
}

/// 取得に失敗した理由を画面に出す文言にする。利用者向けの理由(無料枠の上限の
/// 案内など)はそのまま出し、想定外のエラーは内部の表記を出さない。
String _errorMessage(Object error) {
  return error is CandidateFetchException ? error.message : '候補の取得に失敗しました';
}

/// TabBarViewは表示していないタブのWidgetを破棄するため、そのままだとタブを
/// 切り替えるたびに候補を取り直す(AIの呼び出しと無料枠の消費が毎回発生する)。
/// 一度取得した候補は同じガチャ結果の間は変わらないので、タブを保持する。
class _CandidateListTabState extends ConsumerState<_CandidateListTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final result = widget.result;
    final category = widget.category;
    final args = (result: result, category: category);
    final candidatesAsync = ref.watch(candidatesProvider(args));

    return candidatesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) {
        // 利用上限は、再読み込みしても解消しないため、取り直しではなく、状況に
        // 応じた案内(登録・課金・来月まで待つ)を出す。
        if (error is CandidateLimitException) {
          return LimitReachedView(
            error: error,
            hasAccount: ref.watch(hasAccountProvider),
            // 購入して戻ったときと、購入の反映を待つときに、候補を取り直す。
            onRetry: () => ref.invalidate(candidatesProvider(args)),
          );
        }
        // タブを保持するため、失敗したときはここから取り直せるようにする。
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _errorMessage(error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFontSizes.bodyMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: () => ref.invalidate(candidatesProvider(args)),
                  child: const Text('再読み込み'),
                ),
              ],
            ),
          ),
        );
      },
      data: (candidates) => Column(
        children: [
          Expanded(
            child: _CandidateListView(
              candidates: candidates,
              arrivalStation: result.arrivalStation,
            ),
          ),
          if (category == CandidateCategory.gourmet) const _HotPepperCredit(),
        ],
      ),
    );
  }
}

/// ホットペッパーグルメAPIの利用規約上の表示義務(Issue #50)。
class _HotPepperCredit extends StatelessWidget {
  const _HotPepperCredit();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        '情報提供: ホットペッパーグルメ',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppFontSizes.caption,
        ),
      ),
    );
  }
}

class _CandidateListView extends StatelessWidget {
  const _CandidateListView({
    required this.candidates,
    required this.arrivalStation,
  });

  final List<Candidate> candidates;
  final Station arrivalStation;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: candidates.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
      itemBuilder: (context, index) {
        final candidate = candidates[index];
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CandidateDetailPage(
                candidate: candidate,
                fallbackStation: arrivalStation,
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.secondary, width: 1.2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: GenreIcon(
                      category: candidate.category,
                      categoryName: candidate.categoryName,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppFontSizes.bodyLarge,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        candidate.catchCopy,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppFontSizes.labelSmall,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '駅から徒歩${candidate.walkMinutes}分',
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontSize: AppFontSizes.caption,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (candidate.budget != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '予算の目安 ${candidate.budget}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppFontSizes.caption,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
