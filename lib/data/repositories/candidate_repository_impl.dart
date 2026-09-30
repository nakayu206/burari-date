import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/entities/ai_preference.dart';
import '../../domain/entities/candidate.dart';
import '../../domain/entities/station.dart';
import '../../domain/repositories/candidate_repository.dart';

/// テストで[FirebaseFunctions]の実通信を避けるための注入ポイント。
typedef CandidatesCallable =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

/// バックエンド(Firebase Functions)の`getCandidates`を呼び出し、外部API
/// (ホットペッパー/Foursquare)の実データをAIが要約した候補を取得する
/// (Issue #3, #4)。
class CandidateRepositoryImpl implements CandidateRepository {
  CandidateRepositoryImpl({CandidatesCallable? callable})
    : _callable = callable ?? _defaultCallable;

  final CandidatesCallable _callable;

  static Future<Map<String, dynamic>> _defaultCallable(
    Map<String, dynamic> data,
  ) async {
    final callable = FirebaseFunctions.instance.httpsCallable('getCandidates');
    final result = await callable.call<Map<String, dynamic>>(data);
    return result.data;
  }

  @override
  Future<List<Candidate>> getCandidates(
    Station arrival,
    CandidateCategory category, {
    required String gachaId,
    AiPreference? preference,
  }) async {
    final latitude = arrival.latitude;
    final longitude = arrival.longitude;
    if (latitude == null || longitude == null) {
      throw const CandidateFetchException('到着駅の位置情報が取得できませんでした');
    }

    Map<String, dynamic> data;
    try {
      data = await _callable({
        'latitude': latitude,
        'longitude': longitude,
        'stationName': arrival.name,
        'category': category == CandidateCategory.gourmet
            ? 'gourmet'
            : 'sightseeing',
        // 同じガチャのグルメ・観光を、無料枠で1回と数えるためのID。
        'gachaId': gachaId,
        // 未設定のときはキー自体を送らず、バックエンドは従来どおりの提案にする。
        if (preference != null)
          'preference': {
            'genres': preference.genres.toList(),
            'budget': preference.budget,
            'mood': preference.mood,
          },
      });
    } on FirebaseFunctionsException catch (e) {
      // バックエンドのエラーメッセージ(利用上限案内など)をそのまま表示する。
      throw CandidateFetchException(e.message ?? '候補の取得に失敗しました');
    }

    final rawCandidates = data['candidates'] as List<dynamic>? ?? [];
    return rawCandidates
        .map((json) => _toCandidate(json as Map<String, dynamic>, category))
        .toList();
  }

  Candidate _toCandidate(
    Map<String, dynamic> json,
    CandidateCategory category,
  ) {
    return Candidate(
      id: json['id'] as String,
      category: category,
      name: json['name'] as String,
      catchCopy: json['catchCopy'] as String,
      reason: json['reason'] as String,
      walkMinutes: json['walkMinutes'] as int,
      address: json['address'] as String?,
      imageUrl: json['imageUrl'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}
