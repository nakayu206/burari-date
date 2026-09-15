import '../entities/candidate.dart';
import '../entities/station.dart';

/// 到着駅周辺のグルメ/観光候補を取得する(仕様書 5章 AI連携仕様)。
///
/// 実装は初期構築ではプレースホルダー候補を返すが、将来的には到着駅の緯度経度で
/// 店舗/観光地API(ホットペッパーグルメ/Google Places等)を検索し、その生データ
/// のみをAI(Claude API)に渡して要約・キャッチコピー生成させる想定
/// (仕様書 5.2 処理フロー / 5.4 ハルシネーション対策)。
abstract interface class CandidateRepository {
  Future<List<Candidate>> getCandidates(
    Station arrival,
    CandidateCategory category,
  );
}
