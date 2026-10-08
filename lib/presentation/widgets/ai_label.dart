import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';

/// AIが作った文章(キャッチコピー・おすすめ理由)につける、小さなラベル(Issue #174)。
///
/// 店名・住所・予算などの店舗情報(ホットペッパーグルメ・Foursquareの情報)と、AIが
/// 作った紹介文を、画面の上で区別する。ホットペッパーグルメのクレジットを、AIの文章まで
/// リクルートが提供したものと、誤解されないようにするため。
class AiLabel extends StatelessWidget {
  const AiLabel({super.key});

  /// ラベルの文言。
  static const text = 'AI紹介';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.textSecondary, width: 0.8),
      ),
      child: const Text(
        text,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppFontSizes.caption,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
