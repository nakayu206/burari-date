import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/account_status.dart';
import 'package:burari_date/domain/repositories/account_repository.dart';
import 'package:burari_date/presentation/providers/account_providers.dart';
import 'package:burari_date/presentation/providers/auth_providers.dart';

class _FakeAccountRepository implements AccountRepository {
  AccountStatus status = const AccountStatus.guest();
  bool failLoad = false;

  @override
  Future<AccountStatus> loadStatus() async {
    if (failLoad) throw StateError('load failed');
    return status;
  }

  @override
  Future<AccountStatus> register(LoginMethod method) async =>
      status = AccountStatus.registered(method: method);

  @override
  Future<AccountStatus> signOut() async => status = const AccountStatus.guest();
}

void main() {
  ProviderContainer makeContainer(_FakeAccountRepository repository) {
    final container = ProviderContainer(
      overrides: [accountRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('ゲストのときは、アカウントなし', () async {
    final container = makeContainer(_FakeAccountRepository());
    await container.read(accountStatusProvider.future);

    expect(container.read(hasAccountProvider), isFalse);
  });

  test('登録済みなら、アカウントあり', () async {
    final repository = _FakeAccountRepository()
      ..status = const AccountStatus.registered(method: LoginMethod.google);
    final container = makeContainer(repository);
    await container.read(accountStatusProvider.future);

    expect(container.read(hasAccountProvider), isTrue);
  });

  test('登録・ログアウトに追従する', () async {
    final container = makeContainer(_FakeAccountRepository());
    await container.read(accountStatusProvider.future);
    // 変化を受け取るため、購読しておく。
    final subscription = container.listen(hasAccountProvider, (_, _) {});
    addTearDown(subscription.close);

    await container
        .read(accountStatusProvider.notifier)
        .register(LoginMethod.google);
    expect(container.read(hasAccountProvider), isTrue);

    await container.read(accountStatusProvider.notifier).signOut();
    expect(container.read(hasAccountProvider), isFalse);
  });

  test('状態を取得できないときは、アカウントなしとして扱う', () async {
    final repository = _FakeAccountRepository()..failLoad = true;
    final container = makeContainer(repository);
    await container
        .read(accountStatusProvider.future)
        .then((_) {}, onError: (_) {});

    expect(container.read(hasAccountProvider), isFalse);
  });
}
