import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_train_colors.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/couple_silhouette.dart';
import '../../widgets/station_silhouette.dart';
import '../../widgets/train_illustration.dart';
import '../gacha/station_select_page.dart';

/// S-01 ホーム画面
///
/// Spacerのflex比はFigma実測の縦スペーサー比率をベースに、下部へ電車・駅の
/// イラストを添える分だけ再配分したもの(ユーザーフィードバック:「ホーム
/// 画面がなんかさみしい」→ 電車イラストや駅のシルエットを追加)。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(flex: 3),
              // タイトルの左上に「ぶらり」を斜めに添えて、アプリ名「ぶらり
              // デートガチャ」の由来を見せる小さなアクセントにする。
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(
                    'デートガチャ',
                    style: GoogleFonts.mochiyPopOne(
                      color: AppColors.primary,
                      fontSize: AppFontSizes.displayLarge,
                    ),
                  ),
                  Positioned(
                    left: -10,
                    top: -16,
                    child: Transform.rotate(
                      angle: -0.3,
                      child: Text(
                        'ぶらり',
                        style: GoogleFonts.mochiyPopOne(
                          color: AppColors.secondary,
                          fontSize: AppFontSizes.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                '駅ガチャで、ふらっとデート',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFontSizes.bodyMedium,
                ),
              ),
              const Spacer(flex: 4),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StationSelectPage()),
                ),
                child: const Text('ガチャを始める'),
              ),
              const Spacer(flex: 5),
              const _HomeIllustration(),
              const Spacer(flex: 4),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: AppBottomNav(currentTab: AppTab.home),
      ),
    );
  }
}

/// ボタン下の余白に添える、電車+駅+待ち合わせる二人のシルエット。決め打ち
/// の絶対座標(TrainIllustration)を持つため、狭い画面でも崩れないよう
/// FittedBoxで縮小のみ許可する。
class _HomeIllustration extends StatelessWidget {
  const _HomeIllustration();

  static const _stationWidth = 96.0;
  static const _coupleWidth = 34.0;
  static const _gap = 44.0;
  static const _totalWidth = TrainIllustration.width + _gap + _stationWidth;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: _totalWidth,
        height: TrainIllustration.height + 14,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 駅は電車の奥に隠れないよう、右側に間隔を空けて並べる。
            Positioned(
              left: TrainIllustration.width + _gap,
              bottom: 14,
              child: Opacity(
                opacity: 0.45,
                child: StationSilhouette(width: _stationWidth),
              ),
            ),
            const Positioned(left: 0, bottom: 14, child: TrainIllustration()),
            // 電車と駅の間、ホーム上で待ち合わせる二人(デート感を出す)。
            Positioned(
              left: TrainIllustration.width + (_gap - _coupleWidth) / 2,
              bottom: 14,
              child: const CoupleSilhouette(width: _coupleWidth),
            ),
            // 線路。
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Container(height: 3, color: AppTrainColors.rail),
            ),
          ],
        ),
      ),
    );
  }
}
