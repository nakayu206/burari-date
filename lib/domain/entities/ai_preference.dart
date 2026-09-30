/// AI提案の好み設定(仕様書5.4)。端末ローカルに保存し、後続のIssueで
/// プロンプトへ反映する。
class AiPreference {
  const AiPreference({
    this.genres = const {'和食', '洋食', 'カフェ'},
    this.budget = '普通',
    this.mood = 'おしゃれ',
  });

  /// 好きなジャンル(複数選択可)。
  final Set<String> genres;

  /// 予算感。
  final String budget;

  /// 雰囲気。
  final String mood;

  AiPreference copyWith({Set<String>? genres, String? budget, String? mood}) {
    return AiPreference(
      genres: genres ?? this.genres,
      budget: budget ?? this.budget,
      mood: mood ?? this.mood,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AiPreference &&
      other.genres.length == genres.length &&
      other.genres.containsAll(genres) &&
      other.budget == budget &&
      other.mood == mood;

  @override
  int get hashCode =>
      Object.hash(Object.hashAllUnordered(genres), budget, mood);
}
