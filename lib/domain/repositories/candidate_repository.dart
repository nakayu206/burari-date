import '../entities/candidate.dart';
import '../entities/station.dart';

/// 到着駅周辺のグルメ/観光候補を取得する(仕様書 5章 AI連携仕様)。
///
/// バックエンド(Firebase Functions)経由で店舗/観光地API(ホットペッパー
/// グルメ/Foursquare)を検索し、その生データのみをAI(Claude API)に渡して
/// 要約・キャッチコピー生成させる(仕様書 5.2 処理フロー / 5.4 ハルシネー
/// ション対策)。
abstract interface class CandidateRepository {
  Future<List<Candidate>> getCandidates(
    Station arrival,
    CandidateCategory category,
  );
}
