import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firebase_account_repository.dart';
import '../../domain/entities/account_status.dart';
import '../../domain/repositories/account_repository.dart';
import 'favorite_providers.dart';
import 'gacha_history_providers.dart';
import 'purchase_providers.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return FirebaseAccountRepository();
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

  /// 登録済みのアカウントに、ログインする(Issue #136)。いまのゲストの内容は、使えなくなり、
  /// そのアカウントの内容に、切り替わる。
  Future<void> signIn(LoginMethod method) async {
    final status = await ref.read(accountRepositoryProvider).signIn(method);
    state = AsyncData(status);
    _resetAccountData();
  }

  Future<void> signOut() async {
    final status = await ref.read(accountRepositoryProvider).signOut();
    state = AsyncData(status);
    _resetAccountData();
  }

  /// ログイン・ログアウトで、アカウント(UID)が変わったとき、前のアカウントの内容が、
  /// 画面に残らないよう、UIDに紐づく情報を、取り直す。登録(紐づけ)では、UIDが変わらない
  /// ので、不要。
  void _resetAccountData() {
    ref.invalidate(favoritesProvider);
    ref.invalidate(isFavoriteProvider);
    ref.invalidate(gachaHistoryProvider);
    // 購読の状態は、RevenueCatのユーザー(UID)ごと。新しいアカウントの状態を、読み直す。
    ref.invalidate(subscriptionStatusProvider);
    ref.invalidate(purchaseOfferProvider);
  }
}

final accountStatusProvider =
    AsyncNotifierProvider<AccountNotifier, AccountStatus>(AccountNotifier.new);
