import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/gacha_history_repository_impl.dart';
import '../../domain/entities/gacha_history_entry.dart';
import '../../domain/repositories/gacha_history_repository.dart';

final gachaHistoryRepositoryProvider = Provider<GachaHistoryRepository>((ref) {
  return GachaHistoryRepositoryImpl();
});

/// S-07 履歴画面用。ガチャ実行のたびに[gachaFormProvider]側からinvalidateされ、
/// 最新の履歴を再取得する。
final gachaHistoryProvider = FutureProvider<List<GachaHistoryEntry>>((ref) {
  return ref.watch(gachaHistoryRepositoryProvider).loadHistory();
});
