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

/// 登録しようとしたGoogleアカウントが、すでに別のアカウントとして、登録済みであること
/// を表す例外(Issue #136)。画面は、「ログイン」から入るよう、案内する。
class AccountAlreadyRegisteredException extends AccountException {
  const AccountAlreadyRegisteredException()
    : super('このGoogleアカウントは、すでに登録されています。「Googleでログイン」から、入ってください。');
}

/// アカウントの状態の取得・登録・ログイン・ログアウト(Issue #129・#130・#136)。
abstract class AccountRepository {
  /// いまのアカウントの状態。
  Future<AccountStatus> loadStatus();

  /// [method]でアカウントを登録する。匿名のアカウントを、登録済みのアカウントに
  /// 変換し、履歴・お気に入りは引き継ぐ。取りやめたときは
  /// [AccountCancelledException]、すでに登録済みの[method]のアカウントなら
  /// [AccountAlreadyRegisteredException]、失敗したときは[AccountException]を投げる。
  Future<AccountStatus> register(LoginMethod method);

  /// [method]のアカウントに、ログインする(Issue #136)。すでに登録済みのアカウントなら、
  /// そのアカウントに切り替わり、以前の履歴・お気に入り・購読が戻る。**いまのゲストの
  /// 履歴・お気に入りは、引き継がず、使えなくなる**(統合しない)。まだ登録されていない
  /// アカウントなら、そのアカウントが、新しく作られる。取りやめたときは
  /// [AccountCancelledException]、失敗したときは[AccountException]を投げる。
  Future<AccountStatus> signIn(LoginMethod method);

  /// ログアウトする。ログアウト後の状態を返す。失敗したときは[AccountException]を
  /// 投げる。
  Future<AccountStatus> signOut();

  /// いまのアカウントを削除する(Issue #191)。サーバーが、履歴・お気に入り・購読の情報などを
  /// 削除し、削除後は、ゲストの状態に戻る。**元に戻せない**。購読は、自動では解約されない
  /// (Google Playで、別に解約が必要)。失敗したときは[AccountException]を投げる。
  Future<AccountStatus> deleteAccount();
}
