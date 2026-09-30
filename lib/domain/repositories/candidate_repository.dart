import '../entities/ai_preference.dart';
import '../entities/candidate.dart';
import '../entities/station.dart';

/// 候補を取得できなかった理由を、利用者向けの文言で持つ例外。
///
/// バックエンドが返した案内(無料枠の上限など)や、到着駅の位置情報がない
/// といった理由を、そのまま画面に出せるようにする。[toString]も文言だけを
/// 返し、「Exception:」などの内部用の表記が画面に出ないようにしている。
class CandidateFetchException implements Exception {
  const CandidateFetchException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 到着駅周辺のグルメ/観光候補を取得する(仕様書 5章 AI連携仕様)。
///
/// バックエンド(Firebase Functions)経由で店舗/観光地API(ホットペッパー
/// グルメ/Foursquare)を検索し、その生データのみをAI(Claude API)に渡して
/// 要約・キャッチコピー生成させる(仕様書 5.2 処理フロー / 5.4 ハルシネー
/// ション対策)。
abstract interface class CandidateRepository {
  /// [preference]はユーザーが保存した好み設定(仕様書5.4)。指定があれば、
  /// AIが好みに合う候補を優先して選ぶ。nullなら従来どおりの提案になる。
  Future<List<Candidate>> getCandidates(
    Station arrival,
    CandidateCategory category, {
    AiPreference? preference,
  });
}
