import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/candidate.dart';
import 'package:burari_date/presentation/widgets/pixel_icon.dart';
import 'package:burari_date/presentation/widgets/pixel_icon_data.dart';

void main() {
  group('絵のデータ', () {
    test('全種類に絵があり、12行×12文字で、定義済みの文字だけを使っている', () {
      for (final kind in PixelIconKind.values) {
        final rows = pixelIconPatterns[kind];
        expect(rows, isNotNull, reason: '$kind の絵がない');
        expect(rows!.length, pixelIconGrid, reason: '$kind の行数');
        for (var y = 0; y < rows.length; y++) {
          expect(rows[y].length, pixelIconGrid, reason: '$kind の行$y の文字数');
          for (final ch in rows[y].split('')) {
            expect(
              ch == '.' || pixelIconPalette.containsKey(ch),
              isTrue,
              reason: '$kind の行$y に、未定義の文字 "$ch"',
            );
          }
        }
      }
    });

    test('全種類が、何かを描いている(空の絵はない)', () {
      for (final kind in PixelIconKind.values) {
        final filled = pixelIconPatterns[kind]!.join().replaceAll('.', '');
        expect(filled, isNotEmpty, reason: '$kind が空');
      }
    });
  });

  group('pixelIconKindFor(グルメ)', () {
    PixelIconKind gourmet(String? name) =>
        pixelIconKindFor(CandidateCategory.gourmet, name);

    test('ジャンル名の一部から、対応するアイコンを選ぶ', () {
      expect(gourmet('中華'), PixelIconKind.ramen);
      expect(gourmet('ラーメン'), PixelIconKind.ramen);
      expect(gourmet('和食'), PixelIconKind.sushi);
      expect(gourmet('イタリアン・フレンチ'), PixelIconKind.pizza);
      expect(gourmet('洋食'), PixelIconKind.pizza);
      expect(gourmet('カフェ・スイーツ'), PixelIconKind.coffee);
      expect(gourmet('スイーツ'), PixelIconKind.cake);
      expect(gourmet('居酒屋'), PixelIconKind.beer);
      expect(gourmet('ダイニングバー・バル'), PixelIconKind.beer);
      expect(gourmet('焼肉・ホルモン'), PixelIconKind.meat);
    });

    test('追加したジャンルのアイコンを選ぶ', () {
      expect(gourmet('アジア・エスニック料理'), PixelIconKind.curry);
      expect(gourmet('カレー'), PixelIconKind.curry);
      expect(gourmet('カラオケ・パーティ'), PixelIconKind.mic);
    });

    test('「バー・カクテル」は「バー」を含むが、ジョッキではなくカクテルにする', () {
      expect(gourmet('バー・カクテル'), PixelIconKind.cocktail);
      // 「バー」だけのジャンルは、これまでどおりジョッキ。
      expect(gourmet('ダイニングバー・バル'), PixelIconKind.beer);
    });

    test('対応表にないジャンル・ジャンル名なしは、ナイフとフォークにする', () {
      expect(gourmet('各国料理'), PixelIconKind.dining);
      expect(gourmet('その他グルメ'), PixelIconKind.dining);
      expect(gourmet(null), PixelIconKind.dining);
      expect(gourmet(''), PixelIconKind.dining);
    });
  });

  group('pixelIconKindFor(観光)', () {
    PixelIconKind sightseeing(String? name) =>
        pixelIconKindFor(CandidateCategory.sightseeing, name);

    test('英語のカテゴリ名から選ぶ(大文字小文字を区別しない)', () {
      expect(sightseeing('Park'), PixelIconKind.tree);
      expect(sightseeing('Botanical Garden'), PixelIconKind.flower);
      expect(sightseeing('Art Museum'), PixelIconKind.museum);
      expect(sightseeing('Art Gallery'), PixelIconKind.museum);
      expect(sightseeing('Arcade'), PixelIconKind.ufoCatcher);
      expect(sightseeing('Aquarium'), PixelIconKind.fish);
      expect(sightseeing('Shinto Shrine'), PixelIconKind.torii);
      expect(sightseeing('Buddhist Temple'), PixelIconKind.torii);
      expect(sightseeing('Hot Spring'), PixelIconKind.onsen);
      expect(sightseeing('Theme Park'), PixelIconKind.ferrisWheel);
    });

    test('日本語のカテゴリ名から選ぶ', () {
      expect(sightseeing('公園'), PixelIconKind.tree);
      expect(sightseeing('庭園'), PixelIconKind.flower);
      expect(sightseeing('美術館'), PixelIconKind.museum);
      expect(sightseeing('博物館'), PixelIconKind.museum);
      expect(sightseeing('ゲームセンター'), PixelIconKind.ufoCatcher);
      expect(sightseeing('水族館'), PixelIconKind.fish);
      expect(sightseeing('神社'), PixelIconKind.torii);
      expect(sightseeing('温泉'), PixelIconKind.onsen);
      expect(sightseeing('遊園地'), PixelIconKind.ferrisWheel);
    });

    test('追加した観光カテゴリのアイコンを、英語・日本語の両方で選ぶ', () {
      expect(sightseeing('Movie Theater'), PixelIconKind.movie);
      expect(sightseeing('映画館'), PixelIconKind.movie);
      expect(sightseeing('Music Venue'), PixelIconKind.music);
      expect(sightseeing('ライブハウス'), PixelIconKind.music);
      expect(sightseeing('Zoo'), PixelIconKind.paw);
      expect(sightseeing('動物園'), PixelIconKind.paw);
      expect(sightseeing('Mountain'), PixelIconKind.mountain);
      expect(sightseeing('Hiking Trail'), PixelIconKind.mountain);
      expect(sightseeing('Castle'), PixelIconKind.castle);
      expect(sightseeing('Historic Site'), PixelIconKind.castle);
      expect(sightseeing('史跡'), PixelIconKind.castle);
      expect(sightseeing('Beach'), PixelIconKind.beach);
      expect(sightseeing('ビーチ'), PixelIconKind.beach);
      expect(sightseeing('Stadium'), PixelIconKind.ball);
      expect(sightseeing('Bowling Alley'), PixelIconKind.ball);
      expect(sightseeing('ボウリング場'), PixelIconKind.ball);
      expect(sightseeing('Karaoke Bar'), PixelIconKind.mic);
      expect(sightseeing('カラオケ'), PixelIconKind.mic);
    });

    test('「Amusement Park」は、「Park」より先に遊園地と判定する', () {
      expect(sightseeing('Amusement Park'), PixelIconKind.ferrisWheel);
    });

    test('「Martial Arts」のような、artを含むだけの語は美術館にしない', () {
      expect(sightseeing('Martial Arts Dojo'), isNot(PixelIconKind.museum));
    });

    test('対応表にない観光カテゴリ・カテゴリ名なしは、木にする', () {
      expect(sightseeing('Scenic Lookout'), PixelIconKind.tree);
      expect(sightseeing(null), PixelIconKind.tree);
    });
  });

  group('PixelIcon / GenreIcon', () {
    testWidgets('指定した大きさで描く', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(child: PixelIcon(PixelIconKind.ramen, size: 36)),
        ),
      );

      expect(tester.getSize(find.byType(PixelIcon)), const Size(36, 36));
    });

    testWidgets('GenreIconは、ジャンル名に合うアイコンを選ぶ', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GenreIcon(
            category: CandidateCategory.gourmet,
            categoryName: '中華',
          ),
        ),
      );

      final icon = tester.widget<PixelIcon>(find.byType(PixelIcon));
      expect(icon.kind, PixelIconKind.ramen);
    });
  });
}
