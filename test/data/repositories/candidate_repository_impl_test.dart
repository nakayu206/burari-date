import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/data/repositories/candidate_repository_impl.dart';
import 'package:burari_date/domain/entities/candidate.dart';
import 'package:burari_date/domain/entities/station.dart';

void main() {
  group('CandidateRepositoryImpl', () {
    const arrival = Station(
      id: 'JR山手線-新宿',
      name: '新宿駅',
      lineId: 'JR山手線',
      orderIndex: 0,
      latitude: 35.69,
      longitude: 139.70,
    );

    test('バックエンドのレスポンスをCandidateに変換する', () async {
      final repository = CandidateRepositoryImpl(
        callable: (data) async => {
          'candidates': [
            {
              'id': 'shop1',
              'name': 'テスト洋食屋',
              'catchCopy': 'キャッチコピー',
              'reason': 'おすすめ理由',
              'walkMinutes': 4,
              'address': '東京都新宿区',
              'imageUrl': 'https://example.com/a.png',
              'latitude': 35.691,
              'longitude': 139.701,
            },
          ],
        },
      );

      final result = await repository.getCandidates(
        arrival,
        CandidateCategory.gourmet,
      );

      expect(result, hasLength(1));
      expect(result.single.id, 'shop1');
      expect(result.single.category, CandidateCategory.gourmet);
      expect(result.single.name, 'テスト洋食屋');
      expect(result.single.walkMinutes, 4);
      expect(result.single.address, '東京都新宿区');
      expect(result.single.latitude, 35.691);
    });

    test('到着駅の緯度・経度・駅名・カテゴリをリクエストに渡す', () async {
      Map<String, dynamic>? capturedData;
      final repository = CandidateRepositoryImpl(
        callable: (data) async {
          capturedData = data;
          return {'candidates': <dynamic>[]};
        },
      );

      await repository.getCandidates(arrival, CandidateCategory.sightseeing);

      expect(capturedData?['latitude'], 35.69);
      expect(capturedData?['longitude'], 139.70);
      expect(capturedData?['stationName'], '新宿駅');
      expect(capturedData?['category'], 'sightseeing');
    });

    test('到着駅に座標が無い場合はバックエンドを呼ばず例外を投げる', () async {
      const noLocationStation = Station(
        id: 'x-y',
        name: 'y駅',
        lineId: 'x',
        orderIndex: 0,
      );
      var called = false;
      final repository = CandidateRepositoryImpl(
        callable: (data) async {
          called = true;
          return {'candidates': <dynamic>[]};
        },
      );

      await expectLater(
        repository.getCandidates(noLocationStation, CandidateCategory.gourmet),
        throwsException,
      );
      expect(called, isFalse);
    });

    test('バックエンドが利用上限エラーを返した場合はそのメッセージを伝える', () async {
      final repository = CandidateRepositoryImpl(
        callable: (data) async {
          throw FirebaseFunctionsException(
            message: '今月の利用上限に達しました。来月またご利用ください',
            code: 'resource-exhausted',
          );
        },
      );

      await expectLater(
        repository.getCandidates(arrival, CandidateCategory.gourmet),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('今月の利用上限に達しました'),
          ),
        ),
      );
    });
  });
}
