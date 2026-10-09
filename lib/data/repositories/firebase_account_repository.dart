import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/entities/account_status.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/cloud/account_auth.dart';
import '../datasources/cloud/anonymous_auth.dart';

/// 匿名アカウントを登録アカウントに変換する(登録)・登録済みのアカウントに入る(ログイン)、
/// 本物の[AccountRepository](Issue #130・#136)。
///
/// 登録は、いまの匿名アカウントにGoogleの認証情報を紐づける。ユーザーIDが
/// 変わらないので、履歴・お気に入り・無料枠の回数は、そのまま引き継がれる。
/// ログアウトすると、新しい匿名アカウントで、ゲストとして使い続ける。
class FirebaseAccountRepository implements AccountRepository {
  FirebaseAccountRepository({
    AccountAuth? auth,
    Future<void> Function()? ensureSignedIn,
    Future<void> Function()? deleteOnServer,
  }) : _auth = auth ?? FirebaseAccountAuth(),
       _ensureSignedIn = ensureSignedIn ?? _defaultEnsureSignedIn,
       _deleteOnServer = deleteOnServer ?? _defaultDeleteOnServer;

  final AccountAuth _auth;
  final Future<void> Function() _ensureSignedIn;

  /// サーバーで、アカウントのデータを削除する呼び出し(テストで差し替える)。
  final Future<void> Function() _deleteOnServer;

  static Future<void> _defaultDeleteOnServer() async {
    await FirebaseFunctions.instance
        .httpsCallable('deleteAccount')
        .call<void>();
  }

  static Future<void> _defaultEnsureSignedIn() async {
    await AnonymousAuth.instance.ensureUid();
  }

  @override
  Future<AccountStatus> loadStatus() async => _auth.currentStatus();

  @override
  Future<AccountStatus> register(LoginMethod method) async {
    try {
      // 起動時のログインに失敗していても、ここでやり直してから、紐づける。
      await _ensureSignedIn();
      switch (method) {
        case LoginMethod.google:
          await _auth.linkWithGoogle();
      }
    } catch (e) {
      throw accountExceptionFrom(e);
    }
    return _auth.currentStatus();
  }

  @override
  Future<AccountStatus> signIn(LoginMethod method) async {
    try {
      switch (method) {
        case LoginMethod.google:
          await _auth.signInWithGoogle();
      }
    } catch (e) {
      throw accountExceptionFrom(e);
    }
    // ログインで、別のアカウントに切り替わった。次の操作の前に、ログインが、切れて
    // いないことを確かめる(通常は、すでに、ログイン済み)。
    try {
      await _ensureSignedIn();
    } catch (_) {}
    return _auth.currentStatus();
  }

  @override
  Future<AccountStatus> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw accountExceptionFrom(e);
    }
    // ログアウトしたあとも、ゲストとして使い続けられるよう、匿名でログインし直す。
    // 失敗しても、ログアウトは済んでおり、次の操作の前に、ログインをやり直す。
    try {
      await _ensureSignedIn();
    } catch (_) {}
    return const AccountStatus.guest();
  }

  @override
  Future<AccountStatus> deleteAccount() async {
    try {
      await _deleteOnServer();
    } catch (_) {
      // 失敗したときは、サーバーのデータは、残っている(やり直せる)。内部の表記は出さない。
      throw const AccountException(
        'アカウントを削除できませんでした。通信を確かめて、時間をおいて、もう一度お試しください。',
      );
    }
    // サーバーは、ログインのユーザーも削除した。端末のログインの状態も、消す。すでに
    // 無効になっているため、失敗しても、問題ない。
    try {
      await _auth.signOut();
    } catch (_) {}
    // 削除したあとも、ゲストとして使い続けられるよう、匿名でログインし直す。
    try {
      await _ensureSignedIn();
    } catch (_) {}
    return const AccountStatus.guest();
  }
}
