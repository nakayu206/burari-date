import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/gacha_history_entry.dart';

/// 端末内(SharedPreferences)にガチャ履歴を保存するデータソース。
/// バックエンド(#1)は未構築のため、まずは端末ローカルのみで完結させる。
class GachaHistoryLocalDataSource {
  const GachaHistoryLocalDataSource();

  static const _key = 'gacha_history_entries';

  Future<List<GachaHistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawEntries = prefs.getStringList(_key) ?? const [];
    final entries = <GachaHistoryEntry>[];
    for (final raw in rawEntries) {
      try {
        entries.add(
          GachaHistoryEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (_) {
        continue; // 壊れた1件だけ読み飛ばす(キャスト失敗はTypeErrorなのでExceptionでは拾えない)。
      }
    }
    return entries;
  }

  Future<void> save(List<GachaHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, [
      for (final entry in entries) jsonEncode(entry.toJson()),
    ]);
  }
}
