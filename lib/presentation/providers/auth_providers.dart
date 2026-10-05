import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_providers.dart';

/// アカウントを登録済みか(匿名認証のままではないか)。
///
/// 起動時に匿名認証で入るため、ログインしていることと、アカウントがあることは
/// 別。上限に達したときの案内(アカウント登録から始めるか、課金だけか)の分岐に使う。
/// 登録・ログアウトに追従する(Issue #130)。状態を取得できない間や、取得できなかった
/// ときは、アカウントなしとして扱う(Firebaseを初期化していない環境のテストなども
/// 含む)。
final hasAccountProvider = Provider<bool>((ref) {
  return ref
      .watch(accountStatusProvider)
      .maybeWhen(data: (status) => status.isRegistered, orElse: () => false);
});
