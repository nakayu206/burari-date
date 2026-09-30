import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/data/repositories/candidate_repository_impl.dart';
import 'package:burari_date/domain/entities/ai_preference.dart';
import 'package:burari_date/domain/entities/candidate.dart';
import 'package:burari_date/domain/entities/station.dart';
import 'package:burari_date/domain/repositories/candidate_repository.dart';

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
        gachaId: 'g1',
      );

      expect(result, hasLength(1));
      expect(result.single.id, 'shop1');
      expect(result.single.category, CandidateCategory.gourmet);
      expect(result.single.name, 'テスト洋食屋');
      expect(result.single.walkMinutes, 4);
      expect(result.single.address, '東京都新宿区');
      expect(result.single.latitude, 35.691);
    });

    group('上限のエラー', () {
      CandidateRepositoryImpl failingWith(
        String code, {
        Object? details,
        String message = '上限に達しました',
      }) {
        return CandidateRepositoryImpl(
          callable: (data) async => throw FirebaseFunctionsException(
            message: message,
            code: code,
            details: details,
          ),
        );
      }

      Future<Object> errorOf(CandidateRepositoryImpl repository) async {
        try {
          await repository.getCandidates(
            arrival,
            CandidateCategory.gourmet,
            gachaId: 'g1',
          );
        } catch (e) {
          return e;
        }
        fail('例外が投げられなかった');
      }

      test('無料枠の上限は、種類つきの専用の例外にする', () async {
        final error = await errorOf(
          failingWith(
            'resource-exhausted',
            details: {'limitType': 'free_tier'},
          ),
        );

        expect(error, isA<CandidateLimitException>());
        expect((error as CandidateLimitException).kind, LimitKind.freeTier);
        expect(error.message, '上限に達しました');
      });

      test('月の上限は、monthlyの種類にする', () async {
        final error = await errorOf(
          failingWith('resource-exhausted', details: {'limitType': 'monthly'}),
        );

        expect((error as CandidateLimitException).kind, LimitKind.monthly);
      });

      test('種類が取れない(古いバックエンドなど)場合は、無料枠の上限として扱う', () async {
        final noDetails = await errorOf(failingWith('resource-exhausted'));
        final unknownType = await errorOf(
          failingWith('resource-exhausted', details: {'limitType': 'x'}),
        );

        expect((noDetails as CandidateLimitException).kind, LimitKind.freeTier);
        expect(
          (unknownType as CandidateLimitException).kind,
          LimitKind.freeTier,
        );
      });

      test('上限以外のエラーは、上限の例外にしない(再読み込みで取り直せる)', () async {
        final error = await errorOf(failingWith('unavailable'));

        expect(error, isA<CandidateFetchException>());
        expect(error, isNot(isA<CandidateLimitException>()));
      });
    });

    test('ジャンル名と予算の目安があればCandidateに含め、なければnullにする', () async {
      final repository = CandidateRepositoryImpl(
        callable: (data) async => {
          'candidates': [
            {
              'id': 'shop1',
              'name': '中華飯店',
              'catchCopy': 'c',
              'reason': 'r',
              'walkMinutes': 4,
              'categoryName': '中華',
              'budget': '900円',
            },
            {
              'id': 'shop2',
              'name': '公園',
              'catchCopy': 'c',
              'reason': 'r',
              'walkMinutes': 2,
            },
          ],
        },
      );

      final result = await repository.getCandidates(
        arrival,
        CandidateCategory.gourmet,
        gachaId: 'g1',
      );

      expect(result[0].categoryName, '中華');
      expect(result[0].budget, '900円');
      expect(result[1].categoryName, isNull);
      expect(result[1].budget, isNull);
    });

    test('到着駅の緯度・経度・駅名・カテゴリをリクエストに渡す', () async {
      Map<String, dynamic>? capturedData;
      final repository = CandidateRepositoryImpl(
        callable: (data) async {
          capturedData = data;
          return {'candidates': <dynamic>[]};
        },
      );

      await repository.getCandidates(
        arrival,
        CandidateCategory.sightseeing,
        gachaId: 'g1',
      );

      expect(capturedData?['latitude'], 35.69);
      expect(capturedData?['longitude'], 139.70);
      expect(capturedData?['stationName'], '新宿駅');
      expect(capturedData?['category'], 'sightseeing');
    });

    test('ガチャを識別するgachaIdをリクエストに含める(無料枠を1ガチャ=1回と数えるため)', () async {
      Map<String, dynamic>? capturedData;
      final repository = CandidateRepositoryImpl(
        callable: (data) async {
          capturedData = data;
          return {'candidates': <dynamic>[]};
        },
      );

      await repository.getCandidates(
        arrival,
        CandidateCategory.gourmet,
        gachaId: 'gacha-123',
      );

      expect(capturedData?['gachaId'], 'gacha-123');
    });

    test('好み設定を渡すと、ジャンル・予算・雰囲気をリクエストに含める', () async {
      Map<String, dynamic>? capturedData;
      final repository = CandidateRepositoryImpl(
        callable: (data) async {
          capturedData = data;
          return {'candidates': <dynamic>[]};
        },
      );

      await repository.getCandidates(
        arrival,
        CandidateCategory.gourmet,
        gachaId: 'g1',
        preference: const AiPreference(
          genres: {'和食', 'カフェ'},
          budget: '高め',
          mood: 'レトロ',
        ),
      );

      final preference = capturedData?['preference'] as Map<String, dynamic>;
      expect(preference['genres'], unorderedEquals(['和食', 'カフェ']));
      expect(preference['budget'], '高め');
      expect(preference['mood'], 'レトロ');
    });

    test('好み設定がない場合はpreferenceのキー自体を送らない(従来どおりの提案)', () async {
      Map<String, dynamic>? capturedData;
      final repository = CandidateRepositoryImpl(
        callable: (data) async {
          capturedData = data;
          return {'candidates': <dynamic>[]};
        },
      );

      await repository.getCandidates(
        arrival,
        CandidateCategory.gourmet,
        gachaId: 'g1',
      );

      expect(capturedData, isNotNull);
      expect(capturedData!.containsKey('preference'), isFalse);
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
        repository.getCandidates(
          noLocationStation,
          CandidateCategory.gourmet,
          gachaId: 'g1',
        ),
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
        repository.getCandidates(
          arrival,
          CandidateCategory.gourmet,
          gachaId: 'g1',
        ),
        throwsA(
          isA<CandidateFetchException>()
              .having((e) => e.message, 'message', '今月の利用上限に達しました。来月またご利用ください')
              // 画面に出る文字列に、「Exception:」などの内部の表記が付かない。
              .having(
                (e) => e.toString(),
                'toString',
                '今月の利用上限に達しました。来月またご利用ください',
              ),
        ),
      );
    });
  });
}
