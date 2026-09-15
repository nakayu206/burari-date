import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/entities/candidate.dart';

/// S-06 候補詳細画面
class CandidateDetailPage extends StatelessWidget {
  const CandidateDetailPage({super.key, required this.candidate});

  final Candidate candidate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('候補詳細')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          children: [
            Container(
              height: 130,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.secondary, width: 1.5),
              ),
              child: Icon(
                candidate.category == CandidateCategory.gourmet
                    ? Icons.ramen_dining_rounded
                    : Icons.park_rounded,
                size: 48,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              candidate.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.titleMedium,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'AI: ${candidate.catchCopy}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.labelSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              candidate.reason,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.secondary, width: 1.5),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.map_rounded,
                size: 40,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '住所: ${candidate.address ?? '(外部API連携後に表示)'}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.labelSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('お気に入りに保存しました')));
              },
              child: const Text('保存する'),
            ),
          ],
        ),
      ),
    );
  }
}
