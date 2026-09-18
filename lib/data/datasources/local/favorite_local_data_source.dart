import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/favorite.dart';

/// 端末内(SharedPreferences)にお気に入りを保存するデータソース。
/// バックエンド(#1)は未構築のため、まずは端末ローカルのみで完結させる。
class FavoriteLocalDataSource {
  const FavoriteLocalDataSource();

  static const _key = 'favorite_entries';

  Future<List<Favorite>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawEntries = prefs.getStringList(_key) ?? const [];
    final favorites = <Favorite>[];
    for (final raw in rawEntries) {
      try {
        favorites.add(
          Favorite.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (_) {
        continue; // 壊れた1件だけ読み飛ばす(キャスト失敗はTypeErrorなのでExceptionでは拾えない)。
      }
    }
    return favorites;
  }

  Future<void> save(List<Favorite> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final didSave = await prefs.setStringList(_key, [
      for (final favorite in favorites) jsonEncode(favorite.toJson()),
    ]);
    // setStringListはfalseを返すことがあり、その場合保存されていない。
    if (!didSave) {
      throw Exception('お気に入りの保存に失敗しました');
    }
  }
}
