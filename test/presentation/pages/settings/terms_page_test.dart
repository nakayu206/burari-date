import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:burari_date/presentation/pages/settings/legal_texts.dart';
import 'package:burari_date/presentation/pages/settings/terms_page.dart';

void main() {
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('文面', () {
    String all(List<LegalSection> sections) =>
        sections.map((s) => '${s.heading}\n${s.body}').join('\n');

    test('規約には、過度な連続利用の制限(仕様書10.5)と、無料枠の上限を書く', () {
      final terms = all(termsSections);

      expect(terms, contains('過度な連続利用'));
      expect(terms, contains('累計10回'));
    });

    test('無料枠の回数は、バックエンドの上限(10回)と合わせる', () {
      // functions/src/fairUse.ts の LIFETIME_FREE_LIMIT と同じ値。変えるときは
      // 文面も更新する。
      expect(all(termsSections), contains('10回'));
    });

    test('プライバシーポリシーには、取得する情報・外部サービス・位置情報を書く', () {
      final privacy = all(privacySections);

      expect(privacy, contains('匿名'));
      expect(privacy, contains('Firestore'));
      expect(privacy, contains('位置情報は、取得しません'));
      for (final service in [
        'ホットペッパー',
        'Foursquare',
        'Anthropic',
        'HeartRails',
        'OpenStreetMap',
      ]) {
        expect(privacy, contains(service), reason: '$service の記載がない');
      }
    });

    test('全ての条・項目に、見出しと本文がある', () {
      for (final s in [...termsSections, ...privacySections]) {
        expect(s.heading.trim(), isNotEmpty);
        expect(s.body.trim(), isNotEmpty, reason: s.heading);
      }
    });
  });

  group('TermsPage', () {
    testWidgets('規約とプライバシーポリシーの本文を表示する', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: TermsPage()));

      expect(find.text('利用規約'), findsOneWidget);
      expect(find.text('プライバシーポリシー'), findsOneWidget);
      expect(find.text('第4条(利用回数の制限と有料の機能)'), findsOneWidget);
      expect(find.text('3. 外部のサービスへの送信'), findsOneWidget);
    });

    testWidgets('お問い合わせフォームのURLが空の間は「準備中」を表示し、ボタンを出さない', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(
        const MaterialApp(home: TermsPage(contactUrl: '')),
      );

      expect(find.text('お問い合わせ窓口は準備中です。'), findsOneWidget);
      expect(find.text('お問い合わせフォームを開く'), findsNothing);
    });

    testWidgets('URLがあれば、ボタンでフォームを外部のアプリで開く', (tester) async {
      useTallScreen(tester);
      Uri? opened;
      LaunchMode? openedMode;
      await tester.pumpWidget(
        MaterialApp(
          home: TermsPage(
            contactUrl: 'https://forms.example.com/contact',
            launchUrlOverride:
                (uri, {mode = LaunchMode.platformDefault}) async {
                  opened = uri;
                  openedMode = mode;
                  return true;
                },
          ),
        ),
      );

      expect(find.text('お問い合わせ窓口は準備中です。'), findsNothing);
      await tester.tap(find.text('お問い合わせフォームを開く'));
      await tester.pumpAndSettle();

      expect(opened, Uri.parse('https://forms.example.com/contact'));
      expect(openedMode, LaunchMode.externalApplication);
    });

    testWidgets('フォームを開けなかった場合は、ダイアログで知らせる', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: TermsPage(
            contactUrl: 'https://forms.example.com/contact',
            launchUrlOverride:
                (uri, {mode = LaunchMode.platformDefault}) async => false,
          ),
        ),
      );

      await tester.tap(find.text('お問い合わせフォームを開く'));
      await tester.pumpAndSettle();

      expect(find.text('お問い合わせフォームを開けませんでした'), findsOneWidget);
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      expect(find.text('お問い合わせフォームを開けませんでした'), findsNothing);
    });
  });
}
