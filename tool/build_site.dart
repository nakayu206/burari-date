import 'dart:io';

import 'package:burari_date/presentation/pages/settings/legal_texts.dart';

/// 公式サイトの利用規約・プライバシーポリシーのページを、アプリの文面
/// (`lib/presentation/pages/settings/legal_texts.dart`)から作り、`site/` に書き出す
/// (Issue #139)。アプリとサイトで、文面がずれないようにするため、サイト側は、
/// 手で書き換えず、文面を直したら、このスクリプトを、再実行する。
///
/// 使い方: `dart run tool/build_site.dart`
void main() {
  _write('terms.html', '利用規約', termsSections);
  _write('privacy.html', 'プライバシーポリシー', privacySections);
  _write('delete-account.html', 'アカウントの削除', accountDeletionSections);
}

/// HTMLに埋め込めるよう、特殊な文字を置き換える。
String escapeHtml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/// 本文を、段落のHTMLにする。文面の中の改行は、<br>にする。
String bodyHtml(String body) =>
    '<p>${escapeHtml(body).replaceAll('\n', '<br>\n')}</p>';

/// 利用規約・プライバシーポリシーのページ全体のHTML。
String renderLegalPage(String title, List<LegalSection> sections) {
  final buffer = StringBuffer()
    ..writeln('<!doctype html>')
    ..writeln('<html lang="ja">')
    ..writeln('<head>')
    ..writeln('  <meta charset="utf-8">')
    ..writeln(
      '  <meta name="viewport" content="width=device-width, initial-scale=1">',
    )
    ..writeln('  <meta name="robots" content="noindex">')
    ..writeln('  <title>${escapeHtml(title)} | ぶらりデートガチャ</title>')
    ..writeln('  <link rel="stylesheet" href="style.css">')
    ..writeln('</head>')
    ..writeln('<body>')
    ..writeln('  <header>')
    ..writeln(
      '    <p class="title"><a href="index.html" style="color:inherit;text-decoration:none"><small>ぶらり</small>デートガチャ</a></p>',
    )
    ..writeln('    <nav>')
    ..writeln('      <a href="terms.html">利用規約</a>')
    ..writeln('      <a href="privacy.html">プライバシーポリシー</a>')
    ..writeln('      <a href="delete-account.html">アカウントの削除</a>')
    ..writeln('    </nav>')
    ..writeln('  </header>')
    ..writeln('  <main>')
    ..writeln('    <h1>${escapeHtml(title)}</h1>');
  for (final section in sections) {
    buffer
      ..writeln('    <h2>${escapeHtml(section.heading)}</h2>')
      ..writeln('    ${bodyHtml(section.body)}');
  }
  buffer
    ..writeln('    <p><a href="index.html">トップへ戻る</a></p>')
    ..writeln('  </main>')
    ..writeln('  <footer>')
    ..writeln('    <p>&copy; ぶらりデートガチャ</p>')
    ..writeln('  </footer>')
    ..writeln('</body>')
    ..writeln('</html>');
  return buffer.toString();
}

void _write(String fileName, String title, List<LegalSection> sections) {
  final file = File('site/$fileName')..createSync(recursive: true);
  file.writeAsStringSync(renderLegalPage(title, sections));
  stdout.writeln('$fileName: ${sections.length}項目');
}
