import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/google_sign_in.dart';
import '../../../domain/entities/account_status.dart';
import '../../../domain/repositories/account_repository.dart';

/// アカウントの登録・ログアウトに使う認証の操作(Issue #130)。
///
/// 本物([FirebaseAccountAuth])は、FirebaseとGoogleの認証を使う。テストでは偽物に
/// 差し替え、実際のログインを行わずに、流れと、失敗の扱いを確かめる。
abstract class AccountAuth {
  /// いまのアカウントの状態。
  AccountStatus currentStatus();

  /// Googleでログインし、いまの(匿名の)アカウントに紐づけて、登録済みにする。
  Future<void> linkWithGoogle();

  /// Googleでログインし、そのGoogleアカウントのアカウントに切り替える(Issue #136)。
  /// いまの(匿名の)アカウントは、使われなくなる。
  Future<void> signInWithGoogle();

  /// ログアウトする。
  Future<void> signOut();
}

/// 認証の失敗を、利用者向けの文言の例外にする。内部の表記(エラーコードなど)は、
/// 画面に出さない。
AccountException accountExceptionFrom(Object error) {
  if (error is AccountException) return error;

  if (error is GoogleSignInException) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return const AccountCancelledException();
      case GoogleSignInExceptionCode.interrupted:
      case GoogleSignInExceptionCode.uiUnavailable:
        return const AccountException('Googleのログイン画面を開けませんでした。もう一度お試しください。');
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return const AccountException('Googleでのログインの設定に問題があります。');
      default:
        return const AccountException(
          'Googleでログインできませんでした。時間をおいて、もう一度お試しください。',
        );
    }
  }

  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'credential-already-in-use':
      case 'email-already-in-use':
      case 'account-exists-with-different-credential':
        // 別の端末などで、すでに登録されているGoogleアカウント。登録(紐づけ)では
        // 切り替えず、「ログイン」から入るよう、案内する(Issue #136)。
        return const AccountAlreadyRegisteredException();
      case 'provider-already-linked':
        return const AccountException('すでにGoogleで登録済みです。');
      case 'network-request-failed':
        return const AccountException('通信できませんでした。通信状況を確認して、もう一度お試しください。');
      case 'user-disabled':
        return const AccountException('このアカウントは、利用できません。');
    }
  }

  return const AccountException('時間をおいて、もう一度お試しください。');
}

/// FirebaseとGoogleの認証を使う、本物の[AccountAuth]。
///
/// 匿名のアカウントに、Googleの認証情報を紐づけて(linkWithCredential)登録する。
/// ユーザーID(UID)が変わらないため、履歴・お気に入り・無料枠の回数は、そのまま
/// 引き継がれる。
class FirebaseAccountAuth implements AccountAuth {
  FirebaseAccountAuth({this.serverClientId = kGoogleServerClientId});

  /// Googleログインの「ウェブ クライアントID」。
  final String serverClientId;

  bool _isInitialized = false;

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
    _isInitialized = true;
  }

  @override
  AccountStatus currentStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return const AccountStatus.guest();
    for (final info in user.providerData) {
      if (info.providerId == 'google.com') {
        return AccountStatus.registered(
          method: LoginMethod.google,
          email: info.email ?? user.email,
        );
      }
    }
    // 対応しているログイン方法で登録されていないものは、ゲストとして扱う。
    return const AccountStatus.guest();
  }

  @override
  Future<void> linkWithGoogle() async {
    if (serverClientId.isEmpty) {
      throw const AccountException('Googleでのログインの設定が、まだ済んでいません。');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AccountException('サインインできていません。通信状況を確認して、もう一度お試しください。');
    }
    await _ensureInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AccountException('Googleのログイン情報を取得できませんでした。');
    }
    await user.linkWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
    // 紐づけの結果(プロバイダの情報)を、いまのユーザーに反映する。
    await user.reload();
  }

  @override
  Future<void> signInWithGoogle() async {
    if (serverClientId.isEmpty) {
      throw const AccountException('Googleでのログインの設定が、まだ済んでいません。');
    }
    await _ensureInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AccountException('Googleのログイン情報を取得できませんでした。');
    }
    // いまのゲストではなく、そのGoogleアカウントのアカウントに、切り替わる。
    await FirebaseAuth.instance.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  @override
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    try {
      await _ensureInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Google側のログアウトに失敗しても、Firebaseからは、ログアウト済み。
    }
  }
}
