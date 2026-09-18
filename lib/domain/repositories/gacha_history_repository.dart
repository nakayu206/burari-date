import '../entities/gacha_history_entry.dart';

/// 駅ガチャの実行履歴の永続化を抽象化する(仕様書 6.2 GachaHistory)。
abstract interface class GachaHistoryRepository {
  /// 保存済みの履歴を新しい順に取得する。
  Future<List<GachaHistoryEntry>> loadHistory();

  /// ガチャ実行結果を1件履歴に追加する。
  Future<void> addEntry(GachaHistoryEntry entry);
}
