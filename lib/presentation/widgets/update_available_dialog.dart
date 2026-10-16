import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_spacing.dart';
import 'train_illustration.dart';

/// 新しいバージョンがあることを知らせるダイアログ(Issue #223)。
///
/// 候補カードと同じ、淡いクリーム色の地・緑の枠・角丸で、ホームと同じドット絵の電車を
/// 添える。更新を促すだけで、利用は止めない(必須更新ではない)。「更新する」を選んだ
/// ときだけtrueを返す(「あとで」や、画面の外を押したときは、false)。Google Playの
/// 商品ページを開く処理と、表示するかの判定は、呼び出し側(Issue #224)で行う。
Future<bool> showUpdateAvailableDialog(BuildContext context) async {
  final update = await showDialog<bool>(
    context: context,
    builder: (context) => const _UpdateAvailableDialog(),
  );
  return update == true;
}

class _UpdateAvailableDialog extends StatelessWidget {
  const _UpdateAvailableDialog();

  /// 電車の絵を縮めて収める高さ。
  static const _trainHeight = 72.0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.primaryLight,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2l,
        vertical: AppSpacing.xl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        side: const BorderSide(color: AppColors.secondary, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x2l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _trainHeight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: const TrainIllustration(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '新しいバージョンがあります',
              textAlign: TextAlign.center,
              // ホームやガチャ演出と同じ、ポップな書体で、見せ場の見出しにする。
              style: GoogleFonts.mochiyPopOne(
                color: AppColors.primary,
                fontSize: AppFontSizes.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              '更新してください。\n新しい機能や、改善が、使えるようになります。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.bodyMedium,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppSpacing.x2l),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('更新する'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('あとで'),
            ),
          ],
        ),
      ),
    );
  }
}
