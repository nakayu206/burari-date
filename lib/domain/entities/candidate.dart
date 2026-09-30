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
    this.categoryName,
    this.budget,
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

  /// 外部APIが座標を返さない場合はnullになりうる。S-06の地図はnullの間、
  /// 到着駅の座標をフォールバックとして表示する。
  final double? latitude;
  final double? longitude;

  /// ジャンル名(ホットペッパーのジャンル、Foursquareのカテゴリ)。一覧・詳細の
  /// アイコンの出し分けに使う。取得できない場合はnull。
  final String? categoryName;

  /// 予算の目安(ホットペッパーの平均ディナー予算。飲食店のみ)。
  final String? budget;
}
