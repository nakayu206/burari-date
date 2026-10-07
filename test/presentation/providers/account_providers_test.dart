import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/account_status.dart';
import 'package:burari_date/domain/entities/favorite.dart';
import 'package:burari_date/domain/entities/gacha_history_entry.dart';
import 'package:burari_date/domain/repositories/account_repository.dart';
import 'package:burari_date/domain/repositories/favorite_repository.dart';
import 'package:burari_date/domain/repositories/gacha_history_repository.dart';
import 'package:burari_date/presentation/providers/account_providers.dart';
import 'package:burari_date/presentation/providers/auth_providers.dart';
import 'package:burari_date/presentation/providers/favorite_providers.dart';
import 'package:burari_date/presentation/providers/gacha_history_providers.dart';

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
  Future<AccountStatus> signIn(LoginMethod method) async =>
      status = AccountStatus.registered(method: method);

  @override
  Future<AccountStatus> signOut() async => status = const AccountStatus.guest();
}

/// 読み込まれた回数を、数えるだけの、偽のお気に入り・履歴のリポジトリ。
class _CountingFavoriteRepository implements FavoriteRepository {
  int loadCount = 0;

  @override
  Future<List<Favorite>> loadFavorites() async {
    loadCount++;
    return const [];
  }

  @override
  Future<bool> isFavorite(String candidateId) async => false;

  @override
  Future<void> addFavorite(Favorite favorite) async {}

  @override
  Future<void> removeFavorite(String candidateId) async {}
}

class _CountingHistoryRepository implements GachaHistoryRepository {
  int loadCount = 0;

  @override
  Future<List<GachaHistoryEntry>> loadHistory() async {
    loadCount++;
    return const [];
  }

  @override
  Future<void> addEntry(GachaHistoryEntry entry) async {}
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

  group('アカウントが変わったとき、前のアカウントの内容を残さない(Issue #136)', () {
    late _CountingFavoriteRepository favorites;
    late _CountingHistoryRepository history;

    ProviderContainer makeContainerWithData(_FakeAccountRepository account) {
      favorites = _CountingFavoriteRepository();
      history = _CountingHistoryRepository();
      final container = ProviderContainer(
        overrides: [
          accountRepositoryProvider.overrideWithValue(account),
          favoriteRepositoryProvider.overrideWithValue(favorites),
          gachaHistoryRepositoryProvider.overrideWithValue(history),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    /// お気に入り・履歴を、一度、読み込んで、保持させる(画面を開いた状態)。
    Future<void> loadOnce(ProviderContainer container) async {
      container.listen(favoritesProvider, (_, _) {});
      container.listen(gachaHistoryProvider, (_, _) {});
      await container.read(favoritesProvider.future);
      await container.read(gachaHistoryProvider.future);
      expect((favorites.loadCount, history.loadCount), (1, 1));
    }

    test('ログアウトすると、お気に入り・履歴を、取り直す', () async {
      final account = _FakeAccountRepository()
        ..status = const AccountStatus.registered(method: LoginMethod.google);
      final container = makeContainerWithData(account);
      await loadOnce(container);

      await container.read(accountStatusProvider.notifier).signOut();
      await container.read(favoritesProvider.future);
      await container.read(gachaHistoryProvider.future);

      expect((favorites.loadCount, history.loadCount), (2, 2));
    });

    test('ログインすると、お気に入り・履歴を、取り直し、登録済みの状態になる', () async {
      final container = makeContainerWithData(_FakeAccountRepository());
      await loadOnce(container);

      await container
          .read(accountStatusProvider.notifier)
          .signIn(LoginMethod.google);
      await container.read(favoritesProvider.future);
      await container.read(gachaHistoryProvider.future);

      expect((favorites.loadCount, history.loadCount), (2, 2));
      expect(container.read(hasAccountProvider), isTrue);
    });

    test('登録(紐づけ)では、UIDが変わらないので、取り直さない', () async {
      final container = makeContainerWithData(_FakeAccountRepository());
      await loadOnce(container);

      await container
          .read(accountStatusProvider.notifier)
          .register(LoginMethod.google);
      await container.read(favoritesProvider.future);
      await container.read(gachaHistoryProvider.future);

      expect((favorites.loadCount, history.loadCount), (1, 1));
    });

    test('ログインに失敗したときは、状態を変えず、取り直さない', () async {
      final account = _FailingSignInRepository();
      final container = makeContainerWithData(account);
      await loadOnce(container);

      await expectLater(
        container
            .read(accountStatusProvider.notifier)
            .signIn(LoginMethod.google),
        throwsA(isA<AccountException>()),
      );
      await container.read(favoritesProvider.future);

      expect(favorites.loadCount, 1);
      expect(container.read(hasAccountProvider), isFalse);
    });
  });
}

/// ログインだけ、失敗するリポジトリ。
class _FailingSignInRepository extends _FakeAccountRepository {
  @override
  Future<AccountStatus> signIn(LoginMethod method) async =>
      throw const AccountException('通信できませんでした。');
}
