import '../../domain/entities/gacha_history_entry.dart';
import '../../domain/repositories/gacha_history_repository.dart';
import '../datasources/local/gacha_history_local_data_source.dart';

class GachaHistoryRepositoryImpl implements GachaHistoryRepository {
  GachaHistoryRepositoryImpl({GachaHistoryLocalDataSource? dataSource})
    : _dataSource = dataSource ?? const GachaHistoryLocalDataSource();

  final GachaHistoryLocalDataSource _dataSource;

  /// 際限なく増え続けないよう、直近この件数だけ保持する。
  static const maxEntries = 50;

  @override
  Future<List<GachaHistoryEntry>> loadHistory() async {
    final entries = await _dataSource.load();
    entries.sort((a, b) => b.executedAt.compareTo(a.executedAt));
    return entries;
  }

  @override
  Future<void> addEntry(GachaHistoryEntry entry) async {
    final entries = await _dataSource.load()
      ..add(entry)
      ..sort((a, b) => b.executedAt.compareTo(a.executedAt));
    final trimmed = entries.take(maxEntries).toList();
    await _dataSource.save(trimmed);
  }
}
