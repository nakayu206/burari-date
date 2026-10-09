import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/presentation/pages/settings/legal_texts.dart';

/// tool/build_site.dart の、HTMLへの置き換えと同じ(特殊な文字の置き換えと、改行)。
String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

String _read(String name) => File('site/$name').readAsStringSync();

void main() {
  void expectPageHas(String fileName, List<LegalSection> sections) {
    // 文面を直したのに、サイトを作り直していないと、ここで気づける。
    final html = _read(fileName).replaceAll('\r\n', '\n');
    for (final section in sections) {
      expect(
        html,
        contains('<h2>${_escape(section.heading)}</h2>'),
        reason:
            '$fileName に「${section.heading}」の見出しがない。'
            '`dart run tool/build_site.dart` で、サイトを作り直す',
      );
      final body = _escape(section.body).replaceAll('\n', '<br>\n');
      expect(
        html,
        contains(body),
        reason:
            '$fileName の「${section.heading}」の本文が、アプリの文面と違う。'
            '`dart run tool/build_site.dart` で、サイトを作り直す',
      );
    }
  }

  test('利用規約のページは、アプリの利用規約と同じ文面', () {
    expectPageHas('terms.html', termsSections);
  });

  test('プライバシーポリシーのページは、アプリのプライバシーポリシーと同じ文面', () {
    expectPageHas('privacy.html', privacySections);
  });

  test('アカウントの削除のページは、アプリの文面と同じ', () {
    expectPageHas('delete-account.html', accountDeletionSections);
  });

  test('特定商取引法に基づく表記のページは、アプリの文面と同じ', () {
    expectPageHas('tokushoho.html', commerceSections);
  });

  test('公開前のページは、検索に出さない(noindex)', () {
    // 規約の文面が確定し、公開する準備が整ったら、外す。
    for (final name in [
      'index.html',
      'terms.html',
      'privacy.html',
      'delete-account.html',
      'tokushoho.html',
    ]) {
      expect(
        _read(name),
        contains('name="robots" content="noindex"'),
        reason: name,
      );
    }
    final config = File('firebase.json').readAsStringSync();
    expect(config, contains('X-Robots-Tag'));
  });

  test('トップページに、規約・プライバシーポリシーへのリンクがある', () {
    final index = _read('index.html');
    expect(index, contains('href="terms.html"'));
    expect(index, contains('href="privacy.html"'));
  });

  test('各ページは、同じスタイルシートを読み込む', () {
    expect(File('site/style.css').existsSync(), isTrue);
    for (final name in ['index.html', 'terms.html', 'privacy.html']) {
      expect(_read(name), contains('href="style.css"'), reason: name);
    }
  });

  test('Search Consoleの確認用のファイルが、リダイレクトされずに、開ける設定', () {
    // cleanUrlsをtrueにすると、`.html`のURLが、別のアドレスにリダイレクトされ、
    // Search Consoleの所有権の確認(Play Consoleの組織のウェブサイトの確認に使う)が、
    // 外れることがある。確認用のファイルは、消さない。
    final config = File('firebase.json').readAsStringSync();
    expect(config, contains('"cleanUrls": false'));

    final verificationFiles = Directory('site')
        .listSync()
        .whereType<File>()
        .where((f) => RegExp(r'google[0-9a-f]+\.html$').hasMatch(f.path))
        .toList();
    expect(verificationFiles, isNotEmpty, reason: '確認用のファイルがない');
    for (final file in verificationFiles) {
      final name = file.uri.pathSegments.last;
      expect(file.readAsStringSync().trim(), 'google-site-verification: $name');
    }
  });

  test('サイトの文面に、アプリの内部の表記(Issue番号など)が混ざらない', () {
    for (final name in ['index.html', 'terms.html', 'privacy.html']) {
      expect(_read(name), isNot(contains('Issue #')), reason: name);
    }
  });
}
