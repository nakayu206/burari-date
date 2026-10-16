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
import '../../widgets/ai_label.dart';
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
    // TabBarViewは表示中のタブしか作らないため、そのままだと観光タブは開いてから
    // 取得を始めて待たされる。一覧を開いた時点で、両方を同時に取得し始める。
    // 同じガチャのグルメ・観光は、無料枠で1回と数えるため、先読みで消費は増えない。
    // listenは、再描画を起こさず、取得中の候補を破棄させない。
    for (final category in CandidateCategory.values) {
      final args = (result: widget.result, category: category);
      ref.listen(candidatesProvider(args), (_, _) {});
      ref.listen(candidateDescriptionsProvider(args), (_, _) {});
    }
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
      data: (candidates) {
        // 周辺に施設がなく、候補が0件のときは、空のリストではなく、案内を出す。
        if (candidates.isEmpty) return const _NoCandidatesView();
        // 店舗情報を先に出し、AIの紹介文は届いたものから差し替える。
        final descriptionsAsync = ref.watch(candidateDescriptionsProvider(args));
        final descriptions = descriptionsAsync.asData?.value;
        final shown = descriptions == null
            ? candidates
            : [
                for (final c in candidates)
                  descriptions[c.id] == null
                      ? c
                      : c.withDescription(descriptions[c.id]!),
              ];
        final descriptionFailed = descriptionsAsync.hasError;
        return Column(
          children: [
            Expanded(
              child: _CandidateListView(
                candidates: shown,
                arrivalStation: result.arrivalStation,
                result: result,
                descriptionLoading: descriptionsAsync.isLoading,
                onRetryDescriptions: descriptionFailed
                    ? () => ref.invalidate(candidateDescriptionsProvider(args))
                    : null,
              ),
            ),
            if (category == CandidateCategory.gourmet) const _HotPepperCredit(),
          ],
        );
      },
    );
  }
}

/// 候補が0件のときの案内(Issue #180)。ガチャの画面へ戻って、別の駅を引き直せる。
class _NoCandidatesView extends StatelessWidget {
  const _NoCandidatesView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'この駅の周辺では、候補が見つかりませんでした。\nもう一度ガチャを引いてみてください。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('ガチャに戻る'),
            ),
          ],
        ),
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
        '店舗情報: ホットペッパーグルメ',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppFontSizes.caption,
        ),
      ),
    );
  }
}

/// 詳細画面。AIの紹介文が、開いたあとに届いても、差し替わるようにする
/// (紹介文が付く前に開くと、お気に入りに仮の説明が保存されてしまうため)。
class _LiveCandidateDetail extends ConsumerWidget {
  const _LiveCandidateDetail({
    required this.result,
    required this.candidate,
    required this.fallbackStation,
  });

  final GachaResult result;
  final Candidate candidate;
  final Station fallbackStation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final description = ref
        .watch(
          candidateDescriptionsProvider((
            result: result,
            category: candidate.category,
          )),
        )
        .asData
        ?.value[candidate.id];
    return CandidateDetailPage(
      candidate: description == null
          ? candidate
          : candidate.withDescription(description),
      fallbackStation: fallbackStation,
    );
  }
}

class _CandidateListView extends StatelessWidget {
  const _CandidateListView({
    required this.candidates,
    required this.arrivalStation,
    required this.result,
    this.descriptionLoading = false,
    this.onRetryDescriptions,
  });

  final List<Candidate> candidates;
  final Station arrivalStation;
  final GachaResult result;

  /// AIの紹介文を作っている間。紹介文のない候補に、作成中の表示を出す。
  final bool descriptionLoading;

  /// 紹介文を取得できなかったときの、取り直し。nullなら、取り直しを出さない。
  final VoidCallback? onRetryDescriptions;

  @override
  Widget build(BuildContext context) {
    final retry = onRetryDescriptions;
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: candidates.length + (retry == null ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
      itemBuilder: (context, index) {
        if (index == candidates.length) {
          return Center(
            child: TextButton(
              onPressed: retry,
              child: const Text('AIの紹介文を取得し直す'),
            ),
          );
        }
        final candidate = candidates[index];
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _LiveCandidateDetail(
                result: result,
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
                      // キャッチコピーは、AIが作った文章。店舗情報と区別する。
                      // 紹介文が付く前の仮の表示には、AIの印を付けない。
                      if (candidate.isAiGenerated) const AiLabel(),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        !candidate.isAiGenerated && descriptionLoading
                            ? 'AIが紹介文を作っています…'
                            : candidate.catchCopy,
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
