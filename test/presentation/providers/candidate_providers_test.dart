import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:burari_date/data/repositories/settings_repository_impl.dart';
import 'package:burari_date/domain/entities/ai_preference.dart';
import 'package:burari_date/domain/entities/candidate.dart';
import 'package:burari_date/domain/entities/favorite.dart';
import 'package:burari_date/domain/entities/gacha_result.dart';
import 'package:burari_date/domain/entities/sound_settings.dart';
import 'package:burari_date/domain/entities/railway_line.dart';
import 'package:burari_date/domain/entities/station.dart';
import 'package:burari_date/domain/repositories/candidate_repository.dart';
import 'package:burari_date/domain/repositories/favorite_repository.dart';
import 'package:burari_date/presentation/providers/favorite_providers.dart';
import 'package:burari_date/domain/repositories/settings_repository.dart';
import 'package:burari_date/presentation/providers/candidate_providers.dart';
import 'package:burari_date/presentation/providers/settings_providers.dart';

const _sampleCandidate = Candidate(
  id: 'c1',
  category: CandidateCategory.gourmet,
  name: 'テスト食堂',
  catchCopy: 'キャッチコピー',
  reason: 'おすすめ理由',
  walkMinutes: 3,
);

/// 渡された好み設定を記録するだけのリポジトリ。[response]を返す(既定は候補1件)。
class _RecordingCandidateRepository implements CandidateRepository {
  _RecordingCandidateRepository({this.response = const [_sampleCandidate]});

  final List<Candidate> response;
  AiPreference? receivedPreference;
  final receivedGachaIds = <String>[];
  int callCount = 0;

  @override
  Future<List<Candidate>> getCandidates(
    Station arrival,
    CandidateCategory category, {
    required String gachaId,
    AiPreference? preference,
  }) async {
    callCount++;
    receivedGachaIds.add(gachaId);
    receivedPreference = preference;
    return response;
  }

  @override
  Future<List<CandidateDescription>> describeCandidates(
    Station arrival,
    CandidateCategory category,
    List<Candidate> candidates, {
    required String gachaId,
    AiPreference? preference,
  }) async => [
    for (final c in candidates)
      CandidateDescription(id: c.id, catchCopy: 'AI${c.id}', reason: 'R'),
  ];
}

/// 保存したお気に入りを、メモリに持つだけのリポジトリ。[refreshDelay]だけ更新を遅らせる。
class _MemoryFavoriteRepository implements FavoriteRepository {
  _MemoryFavoriteRepository(this.items, {this.refreshDelay = Duration.zero});

  final List<Favorite> items;
  final Duration refreshDelay;

  @override
  Future<List<Favorite>> loadFavorites() async => List.of(items);

  @override
  Future<void> addFavorite(Favorite favorite) async {
    items
      ..removeWhere((f) => f.candidateId == favorite.candidateId)
      ..add(favorite);
  }

  /// 今も保存されていて、仮の説明のものだけを更新する(解除済みは作り直さない)。
  @override
  Future<bool> refreshDescription(
    String candidateId,
    CandidateDescription description,
  ) async {
    await Future<void>.delayed(refreshDelay);
    final index = items.indexWhere((f) => f.candidateId == candidateId);
    if (index < 0 || items[index].isAiGenerated) return false;
    final f = items[index];
    items[index] = Favorite(
      candidateId: f.candidateId,
      category: f.category,
      name: f.name,
      catchCopy: description.catchCopy,
      reason: description.reason,
      walkMinutes: f.walkMinutes,
      savedAt: f.savedAt,
      isAiGenerated: true,
    );
    return true;
  }

  @override
  Future<void> removeFavorite(String candidateId) async {
    items.removeWhere((f) => f.candidateId == candidateId);
  }

  @override
  Future<bool> isFavorite(String candidateId) async => false;
}

/// 空の紹介文しか返さないリポジトリ(一部の候補に紹介文が付かない場合)。
class _PartialDescriptionRepository extends _RecordingCandidateRepository {
  @override
  Future<List<CandidateDescription>> describeCandidates(
    Station arrival,
    CandidateCategory category,
    List<Candidate> candidates, {
    required String gachaId,
    AiPreference? preference,
  }) async => const [];
}

/// 最初の1回だけ失敗し、2回目からは成功するリポジトリ。
class _FailingOnceCandidateRepository implements CandidateRepository {
  int callCount = 0;

  @override
  Future<List<Candidate>> getCandidates(
    Station arrival,
    CandidateCategory category, {
    required String gachaId,
    AiPreference? preference,
  }) async {
    callCount++;
    if (callCount == 1) throw const CandidateFetchException('失敗');
    return const [];
  }

  @override
  Future<List<CandidateDescription>> describeCandidates(
    Station arrival,
    CandidateCategory category,
    List<Candidate> candidates, {
    required String gachaId,
    AiPreference? preference,
  }) async => [
    for (final c in candidates)
      CandidateDescription(id: c.id, catchCopy: 'AI${c.id}', reason: 'R'),
  ];
}

/// 好み設定の読み込みだけ失敗するリポジトリ。
class _FailingLoadSettingsRepository implements SettingsRepository {
  @override
  Future<AiPreference?> loadSavedAiPreference() =>
      Future.error(Exception('load failed'));

  @override
  Future<AiPreference> loadAiPreference() async => const AiPreference();

  @override
  Future<SoundSettings> loadSoundSettings() async => const SoundSettings();

  @override
  Future<void> saveAiPreference(AiPreference preference) async {}

  @override
  Future<void> saveSoundSettings(SoundSettings settings) async {}
}

void main() {
  const arrival = Station(
    id: 'JR山手線-新宿',
    name: '新宿駅',
    lineId: 'JR山手線',
    orderIndex: 0,
    latitude: 35.69,
    longitude: 139.70,
  );
  final result = GachaResult(
    departureStation: arrival,
    line: const RailwayLine(id: 'JR山手線', name: 'JR山手線', stations: [arrival]),
    minStops: 1,
    maxStops: 1,
    direction: GachaDirection.random,
    arrivalStation: arrival,
    stopsCount: 1,
    executedAt: DateTime(2026, 9, 30),
  );
  final args = (result: result, category: CandidateCategory.gourmet);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('好み設定を保存していなければ、好みなし(null)で候補を取得する', () async {
    final repository = _RecordingCandidateRepository();
    final container = ProviderContainer(
      overrides: [candidateRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(candidatesProvider(args).future);

    expect(repository.callCount, 1);
    expect(repository.receivedPreference, isNull);
  });

  test('保存済みの好み設定を候補の取得に渡す', () async {
    await SettingsRepositoryImpl().saveAiPreference(
      const AiPreference(genres: {'中華'}, budget: '安め', mood: '賑やか'),
    );
    final repository = _RecordingCandidateRepository();
    final container = ProviderContainer(
      overrides: [candidateRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(candidatesProvider(args).future);

    expect(
      repository.receivedPreference,
      const AiPreference(genres: {'中華'}, budget: '安め', mood: '賑やか'),
    );
  });

  test('画面を離れて開き直しても、同じガチャ結果の候補は取り直さない', () async {
    final repository = _RecordingCandidateRepository();
    final container = ProviderContainer(
      overrides: [candidateRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    // 画面を開いて取得し、閉じる(購読を外す)。
    final subscription = container.listen(candidatesProvider(args), (_, _) {});
    await container.read(candidatesProvider(args).future);
    subscription.close();
    await Future<void>.delayed(Duration.zero);

    // もう一度開く。
    final reopened = container.listen(candidatesProvider(args), (_, _) {});
    await container.read(candidatesProvider(args).future);
    reopened.close();

    expect(repository.callCount, 1);
  });

  test('候補が0件のときは、結果を保持せず、開き直したときに取り直す', () async {
    final repository = _RecordingCandidateRepository(response: const []);
    final container = ProviderContainer(
      overrides: [candidateRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final first = container.listen(candidatesProvider(args), (_, _) {});
    expect(await container.read(candidatesProvider(args).future), isEmpty);
    first.close();
    await Future<void>.delayed(Duration.zero);

    final second = container.listen(candidatesProvider(args), (_, _) {});
    await container.read(candidatesProvider(args).future);
    second.close();

    expect(repository.callCount, 2);
  });

  test('同じガチャ結果のグルメ・観光は同じgachaId、別のガチャは別のgachaIdを渡す', () async {
    final repository = _RecordingCandidateRepository();
    final container = ProviderContainer(
      overrides: [candidateRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(candidatesProvider(args).future);
    await container.read(
      candidatesProvider((
        result: result,
        category: CandidateCategory.sightseeing,
      )).future,
    );
    final sameGachaIds = List.of(repository.receivedGachaIds);

    final nextGacha = GachaResult(
      departureStation: arrival,
      line: result.line,
      minStops: 1,
      maxStops: 1,
      direction: GachaDirection.random,
      arrivalStation: arrival,
      stopsCount: 1,
      executedAt: DateTime(2026, 9, 30, 0, 0, 1),
    );
    await container.read(
      candidatesProvider((
        result: nextGacha,
        category: CandidateCategory.gourmet,
      )).future,
    );

    expect(sameGachaIds[0], sameGachaIds[1]);
    expect(repository.receivedGachaIds[2], isNot(sameGachaIds[0]));
  });

  test('カテゴリが違えば別に取得する', () async {
    final repository = _RecordingCandidateRepository();
    final container = ProviderContainer(
      overrides: [candidateRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(candidatesProvider(args).future);
    await container.read(
      candidatesProvider((
        result: result,
        category: CandidateCategory.sightseeing,
      )).future,
    );

    expect(repository.callCount, 2);
  });

  test('取得に失敗した結果は保持せず、開き直したときに取り直す', () async {
    final repository = _FailingOnceCandidateRepository();
    final container = ProviderContainer(
      overrides: [candidateRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final first = container.listen(candidatesProvider(args), (_, _) {});
    await expectLater(
      container.read(candidatesProvider(args).future),
      throwsException,
    );
    first.close();
    await Future<void>.delayed(Duration.zero);

    final second = container.listen(candidatesProvider(args), (_, _) {});
    await container.read(candidatesProvider(args).future);
    second.close();

    expect(repository.callCount, 2);
  });

  test('好み設定の読み込みに失敗しても、好みなしで候補の取得を続ける', () async {
    final repository = _RecordingCandidateRepository();
    final container = ProviderContainer(
      overrides: [
        candidateRepositoryProvider.overrideWithValue(repository),
        settingsRepositoryProvider.overrideWithValue(
          _FailingLoadSettingsRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(candidatesProvider(args).future);

    expect(repository.callCount, 1);
    expect(repository.receivedPreference, isNull);
  });

  test('紹介文は、店舗情報を取得したあとに、候補のidごとに付く', () async {
    final repository = _RecordingCandidateRepository();
    final container = ProviderContainer(
      overrides: [candidateRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final descriptions = await container.read(
      candidateDescriptionsProvider(args).future,
    );

    expect(descriptions.keys, ['c1']);
    expect(descriptions['c1']!.catchCopy, 'AIc1');
    // 店舗情報は、紹介文のために取り直さない。
    expect(repository.callCount, 1);
  });

  test('店舗情報が0件のときは、紹介文を取得しない', () async {
    final repository = _RecordingCandidateRepository(response: const []);
    final container = ProviderContainer(
      overrides: [candidateRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final descriptions = await container.read(
      candidateDescriptionsProvider(args).future,
    );

    expect(descriptions, isEmpty);
  });

  test('紹介文が届いたら、付く前に保存したお気に入りも、紹介文に更新する(保存日時は変えない)', () async {
    final saved = DateTime(2026, 1, 1);
    final favorites = _MemoryFavoriteRepository([
      Favorite(
        candidateId: 'c1',
        category: CandidateCategory.gourmet,
        name: 'テスト食堂',
        catchCopy: '仮',
        reason: '仮',
        walkMinutes: 3,
        savedAt: saved,
        isAiGenerated: false,
      ),
    ]);
    final container = ProviderContainer(
      overrides: [
        candidateRepositoryProvider.overrideWithValue(
          _RecordingCandidateRepository(),
        ),
        favoriteRepositoryProvider.overrideWithValue(favorites),
      ],
    );
    addTearDown(container.dispose);

    await container.read(candidateDescriptionsProvider(args).future);
    await Future<void>.delayed(Duration.zero);

    final updated = favorites.items.single;
    expect(updated.catchCopy, 'AIc1');
    expect(updated.isAiGenerated, isTrue);
    expect(updated.savedAt, saved);
  });

  test('紹介文が一部の候補に足りないときは、成功にせず失敗にする(取り直せる)', () async {
    final container = ProviderContainer(
      overrides: [
        candidateRepositoryProvider.overrideWithValue(
          _PartialDescriptionRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(candidateDescriptionsProvider(args).future),
      throwsA(isA<CandidateFetchException>()),
    );
  });

  test('お気に入りの更新が遅くても、紹介文は先に返る', () async {
    final favorites = _MemoryFavoriteRepository(
      const [],
      refreshDelay: const Duration(seconds: 30),
    );
    final container = ProviderContainer(
      overrides: [
        candidateRepositoryProvider.overrideWithValue(
          _RecordingCandidateRepository(),
        ),
        favoriteRepositoryProvider.overrideWithValue(favorites),
      ],
    );
    addTearDown(container.dispose);

    // 更新(30秒)を待たずに、紹介文が返る。
    final descriptions = await container
        .read(candidateDescriptionsProvider(args).future)
        .timeout(const Duration(seconds: 5));

    expect(descriptions['c1']!.catchCopy, 'AIc1');
  });

  test('解除済みのお気に入りは、紹介文の更新で作り直さない', () async {
    final favorites = _MemoryFavoriteRepository(const []);

    final updated = await favorites.refreshDescription(
      'c1',
      const CandidateDescription(id: 'c1', catchCopy: 'x', reason: 'y'),
    );

    expect(updated, isFalse);
    expect(favorites.items, isEmpty);
  });
}
