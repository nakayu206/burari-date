import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/terms_version.dart';
import '../../data/datasources/cloud/anonymous_auth.dart';
import '../../data/repositories/consent_repository_impl.dart';
import '../../domain/repositories/consent_repository.dart';

final consentRepositoryProvider = Provider<ConsentRepository>((ref) {
  return ConsentRepositoryImpl();
});

/// 同意したあとに行う匿名ログイン(Issue #117)。テストでは、本物のFirebaseに
/// 触れないよう差し替える。
final signInAfterConsentProvider = Provider<Future<Object?> Function()>((ref) {
  return AnonymousAuth.instance.ensureUid;
});

/// 現在の規約の版に同意済みか。保存した版が現在の版と同じなら同意済み。まだ同意して
/// いない、または、規約が更新されて版が上がった(古い版にしか同意していない)場合は、
/// 未同意(false)。
class ConsentNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final accepted = await ref
        .read(consentRepositoryProvider)
        .loadAcceptedVersion();
    return accepted == kTermsVersion;
  }

  /// 現在の規約の版に同意したことを保存する。保存に失敗したときは、同意済みに
  /// せず、例外を呼び出し元へ伝える(画面でダイアログを出す)。
  Future<void> accept() async {
    await ref
        .read(consentRepositoryProvider)
        .saveAcceptedVersion(kTermsVersion);
    state = const AsyncData(true);
    // 同意してから、匿名ログインする。失敗しても同意は取り消さない(候補の取得や
    // 履歴の保存の前に、ログインをやり直す。AnonymousAuth)。
    // 画面の切り替えを待たせないよう、結果は待たない。
    unawaited(
      Future(
        ref.read(signInAfterConsentProvider),
      ).then<void>((_) {}).catchError((_) {}),
    );
  }
}

final consentProvider = AsyncNotifierProvider<ConsentNotifier, bool>(
  ConsentNotifier.new,
);
