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
///
/// 取得のたびにAIを呼び出して無料枠を消費するため、成功した結果は、同じ
/// ガチャ結果・カテゴリの間は保持して再利用する(候補一覧を開き直しても取り
/// 直さない)。失敗は保持せず、画面の「再読み込み」で取り直せるようにする。
/// 保持するため、同じガチャ結果の間に好み設定を変えても反映されない
/// (もう一度ガチャを回せば反映される)。
final candidatesProvider = FutureProvider.autoDispose
    .family<
      List<Candidate>,
      ({GachaResult result, CandidateCategory category})
    >((ref, args) async {
      final link = ref.keepAlive();
      try {
        final repository = ref.watch(candidateRepositoryProvider);
        final preference = await _loadSavedPreference(ref);
        return await repository.getCandidates(
          args.result.arrivalStation,
          args.category,
          preference: preference,
        );
      } catch (_) {
        link.close();
        rethrow;
      }
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
