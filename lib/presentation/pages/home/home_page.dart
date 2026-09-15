import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../widgets/app_bottom_nav.dart';
import '../gacha/station_select_page.dart';

/// S-01 ホーム画面
///
/// Spacerのflex比(3:4:9)はFigma実測の縦スペーサー(60px:80px:189px)の比率を
/// 画面サイズに関わらず再現するためのもの。
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
              Text(
                'デートガチャ',
                style: GoogleFonts.mochiyPopOne(
                  color: AppColors.primary,
                  fontSize: AppFontSizes.displayLarge,
                ),
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
              const Spacer(flex: 9),
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
