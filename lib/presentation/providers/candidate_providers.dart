import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/candidate_repository_impl.dart';
import '../../domain/entities/ai_preference.dart';
import '../../domain/entities/candidate.dart';
import '../../domain/entities/gacha_result.dart';
import '../../domain/repositories/candidate_repository.dart';
import 'favorite_providers.dart';
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
        final candidates = await repository.getCandidates(
          args.result.arrivalStation,
          args.category,
          gachaId: gachaIdOf(args.result),
          preference: preference,
        );
        // 0件のときは、利用枠も消費していない(取り直せる)。保持すると、開き直しても、
        // 空のままになるため、保持しない。
        if (candidates.isEmpty) link.close();
        return candidates;
      } catch (_) {
        link.close();
        rethrow;
      }
    });

/// 一覧を先に出したあとで、後から付ける、AIの紹介文(候補のidごと)。
///
/// 店舗情報の取得([candidatesProvider])を待ってから生成する。失敗は保持せず、
/// 画面の「紹介文を取得し直す」で取り直せるようにする(利用枠は、店舗情報の取得で
/// 数え済みのため、取り直しても増えない)。
final candidateDescriptionsProvider = FutureProvider.autoDispose
    .family<
      Map<String, CandidateDescription>,
      ({GachaResult result, CandidateCategory category})
    >((ref, args) async {
      final link = ref.keepAlive();
      try {
        final candidates = await ref.watch(candidatesProvider(args).future);
        if (candidates.isEmpty) return const {};
        final repository = ref.watch(candidateRepositoryProvider);
        final preference = await _loadSavedPreference(ref);
        final descriptions = await repository.describeCandidates(
          args.result.arrivalStation,
          args.category,
          candidates,
          gachaId: gachaIdOf(args.result),
          preference: preference,
        );
        final byId = {for (final d in descriptions) d.id: d};
        // 一部だけ届いた結果は、成功にしない(画面が、取り直しを出せるようにする)。
        if (candidates.any((c) => !byId.containsKey(c.id))) {
          throw const CandidateFetchException('AIの紹介文を取得できませんでした');
        }
        // 保存済みのお気に入りの更新は、紹介文の表示を待たせないよう、別に進める。
        unawaited(_refreshSavedFavorites(ref, byId));
        return byId;
      } catch (_) {
        link.close();
        rethrow;
      }
    });

/// 紹介文が付く前に保存したお気に入りを、届いた紹介文に更新する。今も保存されている
/// ものだけを更新する(解除したものは作り直さない。判定は、データ側のトランザクション)。
/// 失敗しても、紹介文の表示には影響しない(保存した内容が、仮の説明のままになるだけ)。
Future<void> _refreshSavedFavorites(
  Ref ref,
  Map<String, CandidateDescription> descriptions,
) async {
  try {
    final repository = ref.read(favoriteRepositoryProvider);
    final results = await Future.wait([
      for (final entry in descriptions.entries)
        repository
            .refreshDescription(entry.key, entry.value)
            .catchError((Object _) => false),
    ]);
    if (results.contains(true)) ref.invalidate(favoritesProvider);
  } catch (_) {}
}

/// 1回のガチャを識別するID。実行時刻(マイクロ秒)なので、同じガチャ結果の
/// グルメ・観光は同じID、もう一度ガチャを回すと別のIDになる。
String gachaIdOf(GachaResult result) =>
    result.executedAt.microsecondsSinceEpoch.toString();

/// ユーザーが保存した好み設定を読む。読み込みに失敗しても候補の取得自体は
/// 止めず、好みなし(従来どおりの提案)で続行する。
Future<AiPreference?> _loadSavedPreference(Ref ref) async {
  try {
    return await ref.read(settingsRepositoryProvider).loadSavedAiPreference();
  } catch (_) {
    return null;
  }
}
