import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../widgets/app_bottom_nav.dart';
import 'account_page.dart';
import 'ai_preference_page.dart';
import 'notification_settings_page.dart';
import 'terms_page.dart';

/// S-08 設定画面
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static final _items = <(String, WidgetBuilder)>[
    ('通知設定', (_) => const NotificationSettingsPage()),
    ('AI提案の好み設定', (_) => const AiPreferencePage()),
    ('アカウント', (_) => const AccountPage()),
    ('利用規約・お問い合わせ', (_) => const TermsPage()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          itemCount: _items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final (label, builder) = _items[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppFontSizes.bodyMedium,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: builder)),
            );
          },
        ),
      ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: AppBottomNav(currentTab: AppTab.settings),
      ),
    );
  }
}
