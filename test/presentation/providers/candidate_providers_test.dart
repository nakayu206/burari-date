import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:burari_date/data/repositories/settings_repository_impl.dart';
import 'package:burari_date/domain/entities/ai_preference.dart';
import 'package:burari_date/domain/entities/candidate.dart';
import 'package:burari_date/domain/entities/gacha_result.dart';
import 'package:burari_date/domain/entities/notification_settings.dart';
import 'package:burari_date/domain/entities/railway_line.dart';
import 'package:burari_date/domain/entities/station.dart';
import 'package:burari_date/domain/repositories/candidate_repository.dart';
import 'package:burari_date/domain/repositories/settings_repository.dart';
import 'package:burari_date/presentation/providers/candidate_providers.dart';
import 'package:burari_date/presentation/providers/settings_providers.dart';

/// 渡された好み設定を記録するだけのリポジトリ。
class _RecordingCandidateRepository implements CandidateRepository {
  AiPreference? receivedPreference;
  int callCount = 0;

  @override
  Future<List<Candidate>> getCandidates(
    Station arrival,
    CandidateCategory category, {
    AiPreference? preference,
  }) async {
    callCount++;
    receivedPreference = preference;
    return const [];
  }
}

/// 好み設定の読み込みだけ失敗するリポジトリ。
class _FailingLoadSettingsRepository implements SettingsRepository {
  @override
  Future<AiPreference?> loadSavedAiPreference() =>
      Future.error(Exception('load failed'));

  @override
  Future<AiPreference> loadAiPreference() async => const AiPreference();

  @override
  Future<NotificationSettings> loadNotificationSettings() async =>
      const NotificationSettings();

  @override
  Future<void> saveAiPreference(AiPreference preference) async {}

  @override
  Future<void> saveNotificationSettings(NotificationSettings settings) async {}
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
}
