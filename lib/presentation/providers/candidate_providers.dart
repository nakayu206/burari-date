import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/candidate_repository_impl.dart';
import '../../domain/entities/ai_preference.dart';
import '../../domain/entities/candidate.dart';
import '../../domain/entities/gacha_result.dart';
import '../../domain/repositories/candidate_repository.dart';
import 'settings_providers.dart';

final candidateRepositoryProvider = Provider<CandidateRepository>((ref) {
  return CandidateRepositoryImpl();
});

/// S-05 候補一覧画面用。到着駅・カテゴリごとに候補を取得する。
final candidatesProvider = FutureProvider.autoDispose
    .family<
      List<Candidate>,
      ({GachaResult result, CandidateCategory category})
    >((ref, args) async {
      final repository = ref.watch(candidateRepositoryProvider);
      final preference = await _loadSavedPreference(ref);
      return repository.getCandidates(
        args.result.arrivalStation,
        args.category,
        preference: preference,
      );
    });

/// ユーザーが保存した好み設定を読む。読み込みに失敗しても候補の取得自体は
/// 止めず、好みなし(従来どおりの提案)で続行する。
Future<AiPreference?> _loadSavedPreference(Ref ref) async {
  try {
    return await ref.read(settingsRepositoryProvider).loadSavedAiPreference();
  } catch (_) {
    return null;
  }
}
