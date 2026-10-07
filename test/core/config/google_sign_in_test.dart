import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/core/config/google_sign_in.dart';

void main() {
  test('ウェブ クライアントIDは、設定済みで、Googleのクライアントの形(…apps.googleusercontent.com)', () {
    // 空だと、Googleでの登録が「設定が、まだ済んでいません」となり、使えない(Issue #149)。
    expect(kGoogleServerClientId, isNotEmpty);
    expect(kGoogleServerClientId, endsWith('.apps.googleusercontent.com'));
  });

  test('FirebaseのプロジェクトID番号(burari-date: 889357641434)で始まる', () {
    // 別のプロジェクトのIDを、入れてしまうことを防ぐ。
    expect(kGoogleServerClientId, startsWith('889357641434-'));
  });
}
