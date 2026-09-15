import '../../domain/entities/candidate.dart';
import '../../domain/entities/station.dart';
import '../../domain/repositories/candidate_repository.dart';

/// AI連携(仕様書 5章)・外部の店舗/観光地検索APIが未接続のため、初期構築では
/// 固定パターンのプレースホルダー候補を返す。
class CandidateRepositoryImpl implements CandidateRepository {
  const CandidateRepositoryImpl();

  @override
  Future<List<Candidate>> getCandidates(
    Station arrival,
    CandidateCategory category,
  ) async {
    if (category == CandidateCategory.gourmet) {
      return [
        Candidate(
          id: '${arrival.id}_gourmet_1',
          category: category,
          name: 'candy diner 洋食屋',
          catchCopy: '昭和レトロな洋食屋さん',
          reason: '${arrival.name}から歩ける隠れた名店。オムライスが名物。',
          walkMinutes: 3,
        ),
        Candidate(
          id: '${arrival.id}_gourmet_2',
          category: category,
          name: '喫茶ノスタルジア',
          catchCopy: '静かに話せる隠れ家カフェ',
          reason: '落ち着いた雰囲気でゆっくり話したいデートに。',
          walkMinutes: 5,
        ),
        Candidate(
          id: '${arrival.id}_gourmet_3',
          category: category,
          name: '麺屋 三代目',
          catchCopy: '行列必至の醤油ラーメン',
          reason: '小腹が空いたら寄りたい人気店。',
          walkMinutes: 2,
        ),
      ];
    }
    return [
      Candidate(
        id: '${arrival.id}_sightseeing_1',
        category: category,
        name: '${arrival.name}中央公園',
        catchCopy: '散歩にぴったりの緑地',
        reason: 'ベンチも多く、のんびり歩くデートに向いている。',
        walkMinutes: 4,
      ),
      Candidate(
        id: '${arrival.id}_sightseeing_2',
        category: category,
        name: '${arrival.name}レトロ商店街',
        catchCopy: '昭和の面影が残る商店街',
        reason: '食べ歩きや写真スポットが点在。',
        walkMinutes: 6,
      ),
    ];
  }
}
