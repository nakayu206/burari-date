/// AIが生成する候補カテゴリ(仕様書 6.2 Candidate)
enum CandidateCategory { gourmet, sightseeing }

/// AIが要約・生成したグルメ/観光候補(仕様書 5.3 AIへの入出力)
class Candidate {
  const Candidate({
    required this.id,
    required this.category,
    required this.name,
    required this.catchCopy,
    required this.reason,
    required this.walkMinutes,
    this.address,
    this.imageUrl,
    this.latitude,
    this.longitude,
  });

  final String id;
  final CandidateCategory category;
  final String name;

  /// AI生成キャッチコピー
  final String catchCopy;

  /// AI生成おすすめ理由
  final String reason;
  final int walkMinutes;
  final String? address;
  final String? imageUrl;

  /// 店舗/観光地検索API接続(Issue #3)までは未設定。S-06の地図はnullの間、
  /// 到着駅の座標をフォールバックとして表示する。
  final double? latitude;
  final double? longitude;
}
