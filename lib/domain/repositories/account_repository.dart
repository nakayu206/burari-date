import '../entities/account_status.dart';

/// アカウントの登録・ログアウトに失敗した理由を、利用者向けの文言で持つ例外。
///
/// [toString]も文言だけを返し、「Exception:」などの内部用の表記が画面に出ない
/// ようにしている。
class AccountException implements Exception {
  const AccountException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 利用者が、ログインの途中で取りやめたことを表す例外。失敗ではないので、画面は、
/// エラーを出さない。
class AccountCancelledException extends AccountException {
  const AccountCancelledException() : super('キャンセルしました');
}

/// アカウントの状態の取得・登録・ログアウト(Issue #129・#130)。
abstract class AccountRepository {
  /// いまのアカウントの状態。
  Future<AccountStatus> loadStatus();

  /// [method]でアカウントを登録する。匿名のアカウントを、登録済みのアカウントに
  /// 変換し、履歴・お気に入りは引き継ぐ。取りやめたときは
  /// [AccountCancelledException]、失敗したときは[AccountException]を投げる。
  Future<AccountStatus> register(LoginMethod method);

  /// ログアウトする。ログアウト後の状態を返す。失敗したときは[AccountException]を
  /// 投げる。
  Future<AccountStatus> signOut();
}
