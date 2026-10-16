import 'package:cloud_functions/cloud_functions.dart';

import '../datasources/cloud/anonymous_auth.dart';
import '../datasources/local/device_id.dart';
import '../../domain/entities/ai_preference.dart';
import '../../domain/entities/candidate.dart';
import '../../domain/entities/station.dart';
import '../../domain/repositories/candidate_repository.dart';

/// テストで[FirebaseFunctions]の実通信を避けるための注入ポイント。
typedef CandidatesCallable =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

/// 紹介文の取得(`describeCandidates`)の注入ポイント。
typedef DescribeCallable = CandidatesCallable;

/// バックエンド(Firebase Functions)の`getCandidates`を呼び出し、外部API
/// (ホットペッパー/Foursquare)の実データをAIが要約した候補を取得する
/// (Issue #3, #4)。
class CandidateRepositoryImpl implements CandidateRepository {
  CandidateRepositoryImpl({
    CandidatesCallable? callable,
    DescribeCallable? describeCallable,
    Future<void> Function()? ensureSignedIn,
    Future<String?> Function()? deviceId,
  }) : _callable = callable ?? _defaultCallable,
       _describeCallable =
           describeCallable ??
           (callable == null ? _defaultDescribeCallable : _noDescriptions),
       // 注入した[callable](テスト)のときは、端末の保存領域には触れない。
       _deviceId =
           deviceId ?? (callable == null ? _defaultDeviceId : _noDeviceId),
       // 注入した[callable](テスト)のときは、本物のFirebaseAuthには触れない。
       _ensureSignedIn =
           ensureSignedIn ??
           (callable == null ? _defaultEnsureSignedIn : _noSignIn);

  final CandidatesCallable _callable;
  final DescribeCallable _describeCallable;

  /// 呼び出しの前に、ログインをやり直せるようにするための注入ポイント(Issue #105)。
  final Future<void> Function() _ensureSignedIn;

  static Future<void> _defaultEnsureSignedIn() async {
    await AnonymousAuth.instance.ensureUid();
  }

  static Future<void> _noSignIn() async {}

  /// 無料枠を、端末ごとにも数えるための、端末の識別子(Issue #165)。
  final Future<String?> Function() _deviceId;

  /// 取れなかったとき(保存領域の失敗など)は、送らない。サーバーは、ユーザーだけで数える。
  static Future<String?> _defaultDeviceId() async {
    try {
      return await DeviceId.instance.get();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _noDeviceId() async => null;

  /// 候補の取得を待つ時間。バックエンドの`getCandidates`の待ち時間(120秒。
  /// `functions/src/candidates.ts`の`timeoutSeconds`)より、少し長くする。短いと、
  /// アプリが先に失敗と見なし、サーバー側は成功して利用枠を消費したのに、画面は失敗に
  /// なり、取り直しで、また消費してしまう(Issue #181)。
  static const callTimeout = Duration(seconds: 130);

  static Future<Map<String, dynamic>> _defaultCallable(
    Map<String, dynamic> data,
  ) => _call('getCandidates', data);

  static Future<Map<String, dynamic>> _defaultDescribeCallable(
    Map<String, dynamic> data,
  ) => _call('describeCandidates', data);

  static Future<Map<String, dynamic>> _noDescriptions(
    Map<String, dynamic> data,
  ) async => {'descriptions': []};

  static Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      name,
      options: HttpsCallableOptions(timeout: callTimeout),
    );
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

    // 起動時のログインに失敗していても、ここでやり直す。
    try {
      await _ensureSignedIn();
    } catch (_) {
      throw const CandidateFetchException(
        'サインインできませんでした。通信状況を確認して、もう一度お試しください',
      );
    }

    final deviceId = await _deviceId();

    Map<String, dynamic> data;
    try {
      data = await _callable({
        'latitude': latitude,
        'longitude': longitude,
        'stationName': arrival.name,
        'category': _categoryName(category),
        // AIの紹介文は待たず、店舗情報だけを先に受け取る(紹介文は後から取得する)。
        'phase': 'places',
        // 同じガチャのグルメ・観光を、無料枠で1回と数えるためのID。
        'gachaId': gachaId,
        // ログアウトで無料枠が数え直されないよう、端末ごとにも数える(再インストールは、バックアップの復元しだい)。
        'deviceId': ?deviceId,
        // 未設定のときはキー自体を送らず、バックエンドは従来どおりの提案にする。
        if (preference != null)
          'preference': {
            'genres': preference.genres.toList(),
            'budget': preference.budget,
            'mood': preference.mood,
          },
      });
    } on FirebaseFunctionsException catch (e) {
      final message = e.message ?? '候補の取得に失敗しました';
      // 利用上限は、種類つきの専用の例外にして、画面が案内を分けられるようにする。
      if (e.code == 'resource-exhausted') {
        throw CandidateLimitException(message, kind: _limitKindOf(e.details));
      }
      // バックエンドのエラーメッセージをそのまま表示する。
      throw CandidateFetchException(message);
    }

    final rawCandidates = data['candidates'] as List<dynamic>? ?? [];
    return rawCandidates
        .map((json) => _toCandidate(json as Map<String, dynamic>, category))
        .toList();
  }

  static String _categoryName(CandidateCategory category) =>
      category == CandidateCategory.gourmet ? 'gourmet' : 'sightseeing';

  @override
  Future<List<CandidateDescription>> describeCandidates(
    Station arrival,
    CandidateCategory category,
    List<Candidate> candidates, {
    required String gachaId,
    AiPreference? preference,
  }) async {
    if (candidates.isEmpty) return const [];
    try {
      await _ensureSignedIn();
    } catch (_) {
      throw const CandidateFetchException(
        'サインインできませんでした。通信状況を確認して、もう一度お試しください',
      );
    }

    Map<String, dynamic> data;
    try {
      data = await _describeCallable({
        'category': _categoryName(category),
        'gachaId': gachaId,
        // 紹介文の対象(場所・駅名)は、サーバーが先の取得で残した値を使う(送らない)。
        if (preference != null)
          'preference': {
            'genres': preference.genres.toList(),
            'budget': preference.budget,
            'mood': preference.mood,
          },
      });
    } on FirebaseFunctionsException catch (e) {
      throw CandidateFetchException(e.message ?? '紹介文の取得に失敗しました');
    }

    final raw = data['descriptions'] as List<dynamic>? ?? [];
    return [
      for (final item in raw.cast<Map<String, dynamic>>())
        CandidateDescription(
          id: item['id'] as String,
          catchCopy: item['catchCopy'] as String,
          reason: item['reason'] as String,
        ),
    ];
  }

  /// エラーの`details`から上限の種類を読む。種類が取れない(古いバックエンド
  /// など)場合は、無料枠の上限として扱う。
  static LimitKind _limitKindOf(Object? details) {
    final type = details is Map ? details['limitType'] : null;
    return type == 'monthly' ? LimitKind.monthly : LimitKind.freeTier;
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
      categoryName: json['categoryName'] as String?,
      budget: json['budget'] as String?,
      isAiGenerated: json['isAiGenerated'] as bool? ?? true,
    );
  }
}
