import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:burari_date/presentation/pages/settings/contact_page.dart';

void main() {
  testWidgets('お問い合わせフォームのURLが空の間は「準備中」を表示し、ボタンを出さない', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ContactPage(contactUrl: '')),
    );

    expect(find.text('お問い合わせ窓口は準備中です。'), findsOneWidget);
    expect(find.text('お問い合わせフォームを開く'), findsNothing);
  });

  testWidgets('URLがあれば、ボタンでフォームを外部のアプリで開く', (tester) async {
    Uri? opened;
    LaunchMode? openedMode;
    await tester.pumpWidget(
      MaterialApp(
        home: ContactPage(
          contactUrl: 'https://forms.example.com/contact',
          launchUrlOverride: (uri, {mode = LaunchMode.platformDefault}) async {
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
    await tester.pumpWidget(
      MaterialApp(
        home: ContactPage(
          contactUrl: 'https://forms.example.com/contact',
          launchUrlOverride: (uri, {mode = LaunchMode.platformDefault}) async =>
              false,
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

  testWidgets('フォームを開く処理が例外を投げても、ダイアログで知らせる', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ContactPage(
          contactUrl: 'https://forms.example.com/contact',
          launchUrlOverride: (uri, {mode = LaunchMode.platformDefault}) async =>
              throw Exception('no handler'),
        ),
      ),
    );

    await tester.tap(find.text('お問い合わせフォームを開く'));
    await tester.pumpAndSettle();

    expect(find.text('お問い合わせフォームを開けませんでした'), findsOneWidget);
  });
}
