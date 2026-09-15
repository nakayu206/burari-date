import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/candidate_repository_impl.dart';
import '../../domain/entities/candidate.dart';
import '../../domain/entities/gacha_result.dart';
import '../../domain/repositories/candidate_repository.dart';

final candidateRepositoryProvider = Provider<CandidateRepository>((ref) {
  return const CandidateRepositoryImpl();
});

/// S-05 候補一覧画面用。到着駅・カテゴリごとに候補を取得する。
final candidatesProvider = FutureProvider.autoDispose
    .family<
      List<Candidate>,
      ({GachaResult result, CandidateCategory category})
    >((ref, args) {
      final repository = ref.watch(candidateRepositoryProvider);
      return repository.getCandidates(
        args.result.arrivalStation,
        args.category,
      );
    });
