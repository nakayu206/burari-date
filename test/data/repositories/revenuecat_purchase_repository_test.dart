import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/data/datasources/cloud/purchases_gateway.dart';
import 'package:burari_date/data/repositories/revenuecat_purchase_repository.dart';
import 'package:burari_date/domain/entities/subscription.dart';
import 'package:burari_date/domain/repositories/purchase_repository.dart';

/// 実際のストアにつながず、呼ばれた順番を記録する偽のゲートウェイ。
class _FakeGateway implements PurchasesGateway {
  _FakeGateway(this.log, {this.isAvailable = true});

  final List<String> log;

  @override
  final bool isAvailable;

  String priceLabel = '月額￥300';
  EntitlementState state = const EntitlementState.inactive();
  PurchaseFailureKind? failure;

  void _maybeFail() {
    if (failure != null) throw PurchasesGatewayException(failure!);
  }

  @override
  Future<void> prepare(String uid) async {
    log.add('prepare:$uid');
    _maybeFail();
  }

  @override
  Future<String> loadPriceLabel() async {
    log.add('loadPriceLabel');
    _maybeFail();
    return priceLabel;
  }

  @override
  Future<EntitlementState> loadState() async {
    log.add('loadState');
    _maybeFail();
    return state;
  }

  @override
  Future<EntitlementState> refreshState() async {
    log.add('refreshState');
    _maybeFail();
    return state;
  }

  @override
  Future<EntitlementState> purchase() async {
    log.add('purchase');
    _maybeFail();
    return state = EntitlementState(
      isActive: true,
      expiresAt: DateTime(2026, 11, 5),
      willRenew: true,
    );
  }

  @override
  Future<EntitlementState> restore() async {
    log.add('restore');
    _maybeFail();
    return state;
  }
}

void main() {
  late List<String> log;
  late _FakeGateway gateway;
  Object? uidError;
  String uid = 'uid-1';

  RevenueCatPurchaseRepository newRepository([PurchasesGateway? g]) =>
      RevenueCatPurchaseRepository(
        gateway: g ?? gateway,
        currentUid: () async {
          if (uidError != null) throw uidError!;
          return uid;
        },
      );

  setUp(() {
    log = [];
    gateway = _FakeGateway(log);
    uidError = null;
    uid = 'uid-1';
  });

  group('課金の設定が済んでいない間(公開APIキーが空など)', () {
    late _FakeGateway unavailable;
    setUp(() => unavailable = _FakeGateway(log, isAvailable: false));

    test('価格は既定の表示、状態は購読していない。SDKには触れない', () async {
      final repository = newRepository(unavailable);

      expect(
        (await repository.loadOffer()).priceLabel,
        RevenueCatPurchaseRepository.defaultPriceLabel,
      );
      expect(
        await repository.loadStatus(),
        const SubscriptionStatus.inactive(),
      );
      expect(await repository.restore(), const SubscriptionStatus.inactive());
      expect(log, isEmpty);
    });

    test('購入は、設定が済んでいないと案内する', () async {
      await expectLater(
        newRepository(unavailable).purchase(),
        throwsA(
          isA<PurchaseException>().having(
            (e) => e.message,
            'message',
            contains('課金の設定が、まだ済んでいません'),
          ),
        ),
      );
      expect(log, isEmpty);
    });
  });

  group('案内・状態', () {
    test('ユーザーをFirebaseのUIDにそろえてから、価格を読む', () async {
      final offer = await newRepository().loadOffer();

      expect(offer.priceLabel, '月額￥300');
      expect(log, ['prepare:uid-1', 'loadPriceLabel']);
    });

    test('購読していなければ、購読していない状態', () async {
      expect(
        await newRepository().loadStatus(),
        const SubscriptionStatus.inactive(),
      );
      expect(log, ['prepare:uid-1', 'loadState']);
    });

    test('購読中で、自動更新なら、次回の更新日を渡す', () async {
      gateway.state = EntitlementState(
        isActive: true,
        expiresAt: DateTime(2026, 11, 5),
        willRenew: true,
      );

      final status = await newRepository().loadStatus();

      expect(
        status,
        SubscriptionStatus.active(renewsOn: DateTime(2026, 11, 5)),
      );
    });

    test('購読中でも、解約済みなら、更新日ではなく、終わる日を渡す(更新と表示しない)', () async {
      gateway.state = EntitlementState(
        isActive: true,
        expiresAt: DateTime(2026, 11, 5),
        willRenew: false,
      );

      final status = await newRepository().loadStatus();

      expect(status.isActive, isTrue);
      expect(status.renewsOn, isNull);
      expect(status.endsOn, DateTime(2026, 11, 5));
    });

    test('UIDが変わったら(ログアウトなど)、次の操作で、新しいUIDにそろえる', () async {
      final repository = newRepository();
      await repository.loadStatus();
      uid = 'uid-2';
      await repository.loadStatus();

      expect(log.where((e) => e.startsWith('prepare:')).toList(), [
        'prepare:uid-1',
        'prepare:uid-2',
      ]);
    });

    test('サインインできなかったら、SDKに触れず、利用者向けのエラーにする', () async {
      uidError = Exception('network');

      await expectLater(
        newRepository().loadStatus(),
        throwsA(isA<PurchaseException>()),
      );
      expect(log, isEmpty);
    });
  });

  group('最新への取り直し', () {
    test('キャッシュを使わない取り直しで、解約後の状態(終わる日)を返す', () async {
      gateway.state = EntitlementState(
        isActive: true,
        expiresAt: DateTime(2026, 11, 5),
        willRenew: false,
      );

      final status = await newRepository().refreshStatus();

      expect(status, SubscriptionStatus.active(endsOn: DateTime(2026, 11, 5)));
      expect(log, ['prepare:uid-1', 'refreshState']);
      expect(log, isNot(contains('loadState')));
    });

    test('課金の設定が済んでいない間は、SDKに触れず、購読していない状態', () async {
      final unavailable = _FakeGateway(log, isAvailable: false);

      expect(
        await newRepository(unavailable).refreshStatus(),
        const SubscriptionStatus.inactive(),
      );
      expect(log, isEmpty);
    });

    test('失敗したときは、利用者向けの文言の例外にする', () async {
      gateway.failure = PurchaseFailureKind.network;

      await expectLater(
        newRepository().refreshStatus(),
        throwsA(isA<PurchaseException>()),
      );
    });
  });

  group('購入・復元', () {
    test('購入すると、購読中の状態を返す', () async {
      final status = await newRepository().purchase();

      expect(
        status,
        SubscriptionStatus.active(renewsOn: DateTime(2026, 11, 5)),
      );
      expect(log, ['prepare:uid-1', 'purchase']);
    });

    test('復元すると、復元後の状態を返す', () async {
      gateway.state = const EntitlementState(isActive: true, willRenew: true);

      final status = await newRepository().restore();

      expect(status.isActive, isTrue);
      expect(log, ['prepare:uid-1', 'restore']);
    });

    test('取りやめたときは、取りやめの例外にする', () async {
      gateway.failure = PurchaseFailureKind.cancelled;

      await expectLater(
        newRepository().purchase(),
        throwsA(isA<PurchaseCancelledException>()),
      );
    });

    test('失敗の種類ごとに、利用者向けの文言にする(内部の表記は出さない)', () async {
      const expectations = {
        PurchaseFailureKind.network: '通信',
        PurchaseFailureKind.notAllowed: '購入できません',
        PurchaseFailureKind.store: 'ストア',
        PurchaseFailureKind.alreadyPurchased: '購入を復元する',
        PurchaseFailureKind.planNotFound: 'プランが見つかりません',
        PurchaseFailureKind.other: 'もう一度お試しください',
      };
      for (final entry in expectations.entries) {
        gateway.failure = entry.key;
        await expectLater(
          newRepository().purchase(),
          throwsA(
            isA<PurchaseException>()
                .having((e) => e.message, 'message', contains(entry.value))
                .having(
                  (e) => e.message,
                  'no internals',
                  isNot(contains('PurchasesGateway')),
                ),
          ),
          reason: '${entry.key}',
        );
      }
    });

    test('想定外のエラーでも、決まった文言にする', () async {
      final repository = RevenueCatPurchaseRepository(
        gateway: _ThrowingGateway(),
        currentUid: () async => 'uid-1',
      );

      await expectLater(
        repository.purchase(),
        throwsA(
          isA<PurchaseException>().having(
            (e) => e.message,
            'message',
            isNot(contains('boom')),
          ),
        ),
      );
    });
  });
}

/// 想定外のエラーを投げるゲートウェイ。
class _ThrowingGateway implements PurchasesGateway {
  @override
  bool get isAvailable => true;

  @override
  Future<void> prepare(String uid) async => throw StateError('boom');

  @override
  Future<String> loadPriceLabel() async => throw StateError('boom');

  @override
  Future<EntitlementState> loadState() async => throw StateError('boom');

  @override
  Future<EntitlementState> refreshState() async => throw StateError('boom');

  @override
  Future<EntitlementState> purchase() async => throw StateError('boom');

  @override
  Future<EntitlementState> restore() async => throw StateError('boom');
}
