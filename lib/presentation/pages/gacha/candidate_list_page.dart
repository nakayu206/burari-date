import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/entities/candidate.dart';
import '../../../domain/entities/gacha_result.dart';
import '../../providers/candidate_providers.dart';
import 'candidate_detail_page.dart';

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
        title: const Text('候補一覧'),
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

class _CandidateListTab extends ConsumerWidget {
  const _CandidateListTab({required this.result, required this.category});

  final GachaResult result;
  final CandidateCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidatesAsync = ref.watch(
      candidatesProvider((result: result, category: category)),
    );

    return candidatesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('候補の取得に失敗しました: $error')),
      data: (candidates) => ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.xl),
        itemCount: candidates.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
        itemBuilder: (context, index) {
          final candidate = candidates[index];
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CandidateDetailPage(candidate: candidate),
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
                    child: Icon(
                      candidate.category == CandidateCategory.gourmet
                          ? Icons.ramen_dining_rounded
                          : Icons.park_rounded,
                      color: AppColors.textSecondary,
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
                          'AI: ${candidate.catchCopy}',
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
