import '../../domain/entities/account_status.dart';
import '../../domain/repositories/account_repository.dart';

/// アカウント登録の処理ができるまでの、仮の実装(Issue #129)。常にゲストとして
/// 扱い、登録は「まだ使えない」と返す。実際の登録(匿名アカウントの変換)は
/// Issue #130で作り、この実装は、そのとき、置き換える。
class PlaceholderAccountRepository implements AccountRepository {
  const PlaceholderAccountRepository();

  @override
  Future<AccountStatus> loadStatus() async => const AccountStatus.guest();

  @override
  Future<AccountStatus> register(LoginMethod method) async {
    throw const AccountException('アカウント登録は、まだ使えません。もうしばらくお待ちください。');
  }

  @override
  Future<AccountStatus> signOut() async => const AccountStatus.guest();
}
