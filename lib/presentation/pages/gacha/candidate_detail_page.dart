import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            Container(
              height: 160,
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
            const SizedBox(height: 16),
            Text(
              candidate.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'AI: ${candidate.catchCopy}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              candidate.reason,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 120,
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
            const SizedBox(height: 12),
            Text(
              '住所: ${candidate.address ?? '(外部API連携後に表示)'}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 32),
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
