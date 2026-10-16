import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/app_update_repository_impl.dart';
import '../../domain/entities/app_update.dart';
import '../../domain/repositories/app_update_repository.dart';

final appUpdateRepositoryProvider = Provider<AppUpdateRepository>((ref) {
  return AppUpdateRepositoryImpl();
});

/// 起動時に案内する更新。Google Playに新しいバージョンがあり、まだ案内していないときだけ
/// 値が入る(それ以外はnull)。アプリを起動している間は、再確認しない。
///
/// 案内済みのビルド番号を読めなかったときは、案内しない(同じ更新を毎回案内してしまう
/// より、案内を出さない側に倒す)。
final updateToNotifyProvider = FutureProvider<AppUpdate?>((ref) async {
  final repository = ref.watch(appUpdateRepositoryProvider);
  final update = await repository.findAvailableUpdate();
  if (update == null) return null;
  try {
    final notified = await repository.loadNotifiedVersion();
    return update.isNewerThan(notified) ? update : null;
  } catch (_) {
    return null;
  }
});
