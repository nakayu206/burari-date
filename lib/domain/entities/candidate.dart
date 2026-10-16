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
    this.isAiGenerated = true,
  });

  final String id;

  /// 紹介文がAIの生成か。紹介文が付く前の、実データだけの仮の表示はfalse。
  final bool isAiGenerated;
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

  /// AIの紹介文に差し替えた候補を返す。店舗情報(店名・住所など)は変えない。
  Candidate withDescription(CandidateDescription description) {
    return Candidate(
      id: id,
      category: category,
      name: name,
      catchCopy: description.catchCopy,
      reason: description.reason,
      walkMinutes: walkMinutes,
      address: address,
      imageUrl: imageUrl,
      latitude: latitude,
      longitude: longitude,
      categoryName: categoryName,
      budget: budget,
      isAiGenerated: true,
    );
  }
}

/// 一覧を先に出したあとで、後から付く、AIの紹介文(キャッチコピー・おすすめ理由)。
class CandidateDescription {
  const CandidateDescription({
    required this.id,
    required this.catchCopy,
    required this.reason,
  });

  /// 紹介文を付ける[Candidate.id]。
  final String id;
  final String catchCopy;
  final String reason;
}
