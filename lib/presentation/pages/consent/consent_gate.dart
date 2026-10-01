import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/consent_providers.dart';
import 'consent_page.dart';

/// 起動時の分岐(Issue #97)。現在の規約の版に同意済みなら[child](ホーム画面)を
/// 出し、未同意なら同意画面を出す。
///
/// 判定を待つ間は、アプリの背景色の空の画面を出す(ホームが一瞬見えてから同意画面に
/// 切り替わる、ということが起きないようにする)。判定を読み込めなかった場合は、
/// 未同意として同意画面を出す(同意を求める側に倒す)。
class ConsentGate extends ConsumerWidget {
  const ConsentGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(consentProvider);
    return consent.when(
      loading: () => const Scaffold(body: SizedBox.shrink()),
      error: (_, _) => const ConsentPage(),
      data: (isAccepted) => isAccepted ? child : const ConsentPage(),
    );
  }
}
