import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/terms_version.dart';
import '../../data/repositories/consent_repository_impl.dart';
import '../../domain/repositories/consent_repository.dart';

final consentRepositoryProvider = Provider<ConsentRepository>((ref) {
  return ConsentRepositoryImpl();
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
  }
}

final consentProvider = AsyncNotifierProvider<ConsentNotifier, bool>(
  ConsentNotifier.new,
);
