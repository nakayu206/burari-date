import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/entities/gacha_result.dart';
import '../../providers/gacha_form_provider.dart';
import 'candidate_list_page.dart';
import 'gacha_animation_page.dart';

/// S-04 到着駅決定画面
class ArrivalResultPage extends ConsumerWidget {
  const ArrivalResultPage({super.key, required this.result});

  final GachaResult result;

  void _reroll(BuildContext context, WidgetRef ref) {
    final rerolled = ref.read(gachaFormProvider.notifier).runGacha();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GachaAnimationPage(result: rerolled)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('到着駅決定')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            children: [
              // Figma実測比(rect 160px : 140px ≒ 8:7)を再現するフレックス比。
              const Spacer(flex: 8),
              Text(
                '出発駅から${result.stopsCount}駅隣',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFontSizes.bodySmall,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                result.arrivalStation.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppFontSizes.displayLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(flex: 7),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CandidateListPage(result: result),
                  ),
                ),
                child: const Text('候補を見る'),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: () => _reroll(context, ref),
                child: const Text('もう一度ガチャ'),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
