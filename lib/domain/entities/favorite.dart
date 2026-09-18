import 'candidate.dart';

/// お気に入り保存した候補(仕様書 6.1 Favorite)。
///
/// [Candidate]は候補一覧の取得のたびに生成し直される(永続化されていない)
/// ため、保存時点のスナップショットとして必要な項目を複製して持つ。
class Favorite {
  const Favorite({
    required this.candidateId,
    required this.category,
    required this.name,
    required this.catchCopy,
    required this.reason,
    required this.walkMinutes,
    required this.savedAt,
    this.address,
    this.imageUrl,
    this.latitude,
    this.longitude,
  });

  factory Favorite.fromCandidate(Candidate candidate) {
    return Favorite(
      candidateId: candidate.id,
      category: candidate.category,
      name: candidate.name,
      catchCopy: candidate.catchCopy,
      reason: candidate.reason,
      walkMinutes: candidate.walkMinutes,
      savedAt: DateTime.now(),
      address: candidate.address,
      imageUrl: candidate.imageUrl,
      latitude: candidate.latitude,
      longitude: candidate.longitude,
    );
  }

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      candidateId: json['candidateId'] as String,
      category: CandidateCategory.values.byName(json['category'] as String),
      name: json['name'] as String,
      catchCopy: json['catchCopy'] as String,
      reason: json['reason'] as String,
      walkMinutes: json['walkMinutes'] as int,
      savedAt: DateTime.parse(json['savedAt'] as String),
      address: json['address'] as String?,
      imageUrl: json['imageUrl'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  /// 保存元の[Candidate.id]。お気に入りの一意なキーとしても使う
  /// (同じ候補を重複保存させない)。
  final String candidateId;
  final CandidateCategory category;
  final String name;
  final String catchCopy;
  final String reason;
  final int walkMinutes;
  final DateTime savedAt;
  final String? address;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toJson() {
    return {
      'candidateId': candidateId,
      'category': category.name,
      'name': name,
      'catchCopy': catchCopy,
      'reason': reason,
      'walkMinutes': walkMinutes,
      'savedAt': savedAt.toIso8601String(),
      'address': address,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
