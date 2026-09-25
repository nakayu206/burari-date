import '../../domain/entities/gacha_history_entry.dart';
import '../../domain/repositories/gacha_history_repository.dart';
import '../datasources/cloud/gacha_history_firestore_data_source.dart';

class GachaHistoryRepositoryImpl implements GachaHistoryRepository {
  GachaHistoryRepositoryImpl({GachaHistoryFirestoreDataSource? dataSource})
    : _dataSource = dataSource ?? GachaHistoryFirestoreDataSource();

  final GachaHistoryFirestoreDataSource _dataSource;

  static const maxEntries = GachaHistoryFirestoreDataSource.maxEntries;

  @override
  Future<List<GachaHistoryEntry>> loadHistory() => _dataSource.load();

  @override
  Future<void> addEntry(GachaHistoryEntry entry) => _dataSource.add(entry);
}
