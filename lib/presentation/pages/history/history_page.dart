import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../widgets/app_bottom_nav.dart';

/// S-07 履歴画面
///
/// 仕様書 4.2 に記載の通り詳細は今後の拡張フェーズで検討中のプレースホルダー。
/// 実装時は GachaHistory テーブル(仕様書 6.2)からの取得に置き換える。
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  static const _placeholderEntries = [
    (station: '△△駅', summary: 'グルメ2件保存', date: '9/1'),
    (station: '□□駅', summary: '観光1件保存', date: '8/24'),
    (station: '◇◇駅', summary: '', date: '8/10'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('履歴')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          itemCount: _placeholderEntries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = _placeholderEntries[index];
            return Row(
              children: [
                const Icon(Icons.circle, size: 10, color: AppColors.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.station,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (entry.summary.isNotEmpty)
                        Text(
                          entry.summary,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  entry.date,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const SafeArea(
        top: false,
        child: AppBottomNav(currentTab: AppTab.history),
      ),
    );
  }
}
