import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../widgets/app_bottom_nav.dart';
import '../gacha/station_select_page.dart';

/// S-01 ホーム画面
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text(
                'デートガチャ',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '駅ガチャで、ふらっとデート',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const Spacer(flex: 3),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StationSelectPage()),
                ),
                child: const Text('ガチャを始める'),
              ),
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
