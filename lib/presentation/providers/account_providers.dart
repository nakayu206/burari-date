import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/placeholder_account_repository.dart';
import '../../domain/entities/account_status.dart';
import '../../domain/repositories/account_repository.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return const PlaceholderAccountRepository();
});

/// アカウントの状態(ゲスト/登録済み)。登録・ログアウトに追従する。
///
/// 登録・ログアウトに失敗したときは、状態を変えず、例外を呼び出し元(画面)へ
/// 伝える(画面でダイアログを出す)。
class AccountNotifier extends AsyncNotifier<AccountStatus> {
  @override
  Future<AccountStatus> build() {
    return ref.read(accountRepositoryProvider).loadStatus();
  }

  Future<void> register(LoginMethod method) async {
    final status = await ref.read(accountRepositoryProvider).register(method);
    state = AsyncData(status);
  }

  Future<void> signOut() async {
    final status = await ref.read(accountRepositoryProvider).signOut();
    state = AsyncData(status);
  }
}

final accountStatusProvider =
    AsyncNotifierProvider<AccountNotifier, AccountStatus>(AccountNotifier.new);
