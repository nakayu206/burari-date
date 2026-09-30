import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// アカウントを登録済みか(匿名認証のままではないか)。
///
/// 起動時に匿名認証で入るため、ログインしていることと、アカウントがあることは
/// 別。上限に達したときの案内(アカウント登録から始めるか、課金だけか)の分岐に使う。
/// Firebaseを初期化していない環境(テストや、未対応のプラットフォーム)では、
/// アカウントなしとして扱う。
final hasAccountProvider = Provider<bool>((ref) {
  try {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && !user.isAnonymous;
  } catch (_) {
    return false;
  }
});
