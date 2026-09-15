import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_spacing.dart';
import '../pages/history/history_page.dart';
import '../pages/home/home_page.dart';
import '../pages/settings/settings_page.dart';

enum AppTab { home, history, settings }

/// S-01/S-07/S-08 共通のボトムナビゲーション(ホーム・履歴・設定)。
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentTab});

  final AppTab currentTab;

  void _navigate(BuildContext context, AppTab tab) {
    if (tab == currentTab) return;
    final Widget page = switch (tab) {
      AppTab.home => const HomePage(),
      AppTab.history => const HistoryPage(),
      AppTab.settings => const SettingsPage(),
    };
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'ホーム',
                selected: currentTab == AppTab.home,
                onTap: () => _navigate(context, AppTab.home),
              ),
              _NavItem(
                icon: Icons.history_rounded,
                label: '履歴',
                selected: currentTab == AppTab.history,
                onTap: () => _navigate(context, AppTab.history),
              ),
              _NavItem(
                icon: Icons.settings_rounded,
                label: '設定',
                selected: currentTab == AppTab.settings,
                onTap: () => _navigate(context, AppTab.settings),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconMd, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: AppFontSizes.caption,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
