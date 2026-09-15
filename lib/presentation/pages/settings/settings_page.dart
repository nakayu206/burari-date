import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../widgets/app_bottom_nav.dart';

/// S-08 設定画面
///
/// 仕様書 4.2 に記載の通り詳細は今後の拡張フェーズで検討中のプレースホルダー。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _items = ['通知設定', 'AI提案の好み設定', 'アカウント', '利用規約・お問い合わせ'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          itemCount: _items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _items[index],
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
              onTap: () {},
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
