import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
        'Resend',
      ]) {
        expect(privacy, contains(service), reason: '$service の記載がない');
      }
    });

    test('プライバシーポリシーには、アカウント・購読・端末の識別子・削除を、書く', () {
      final privacy = all(privacySections);

      expect(privacy, contains('Googleアカウント'));
      expect(privacy, contains('RevenueCat'));
      expect(privacy, contains('Google Play'));
      expect(privacy, contains('端末の識別子'));
      expect(privacy, contains('アカウントを削除'));
      // アカウント・課金は、まだ提供していない、という古い記載が残っていない。
      expect(privacy, isNot(contains('提供する場合は、取得する情報が増えます')));
    });

    test('アカウントの削除の案内には、手順・削除されるもの・残るもの・解約を書く', () {
      final deletion = all(accountDeletionSections);

      expect(deletion, contains('「アカウントを削除」を押す'));
      expect(deletion, contains('履歴'));
      expect(deletion, contains('残ります'));
      expect(deletion, contains('Google Play'));
      // Google Playの条件: アプリ・デベロッパーの名前と、保持期間を書く。
      expect(deletion, contains('ぶらりデートガチャ'));
      expect(deletion, contains('CenterRiverStudio'));
      expect(deletion, contains('期間を定めずに'));
      expect(deletion, contains('1か月'));
    });

    test('プライバシーポリシーには、お問い合わせで、メールアドレスを取得することを書く', () {
      final privacy = all(privacySections);

      expect(privacy, contains('返信先のメールアドレス'));
      expect(privacy, contains('返信先のメールアドレスは、このためだけに使います'));
      expect(privacy, contains('対応が終わってから1か月を目安に削除します'));
      // メールアドレスは取得しない、という古い記載が残っていない。
      expect(privacy, isNot(contains('現時点では取得しません')));
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

      expect(find.text('利用規約'), findsWidgets);
      expect(find.text('プライバシーポリシー'), findsOneWidget);
      expect(find.text('第4条(利用回数の制限と有料の機能)'), findsOneWidget);
      expect(find.text('3. 外部のサービスへの送信'), findsOneWidget);
    });

    testWidgets('お問い合わせは、別の画面に分けたので、この画面には出さない', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: TermsPage()));

      expect(find.text('お問い合わせ窓口は準備中です。'), findsNothing);
      expect(find.text('お問い合わせフォームを開く'), findsNothing);
    });
  });
}
