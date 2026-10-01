import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../providers/consent_providers.dart';
import '../../widgets/terms_and_privacy_body.dart';

/// 初回起動時(と、規約の版が上がったとき)の、利用規約・プライバシーポリシーへの
/// 同意画面(Issue #97)。「同意して始める」を押すと同意を保存し、ホーム画面に進む。
///
/// 同意しなければ先に進めないため、「同意しない」ボタンは置かない。本文を読まずに
/// 同意することを防ぐため、最後までスクロールするまで、ボタンは押せない(本文が短く
/// てスクロールが要らない場合は、最初から押せる)。
class ConsentPage extends ConsumerStatefulWidget {
  const ConsentPage({super.key});

  @override
  ConsumerState<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends ConsumerState<ConsentPage> {
  /// 末尾から、この距離(論理px)以内まで来たら、最後まで読んだものとして扱う。
  static const _bottomThreshold = 24.0;

  /// 最後までスクロールしたか。一度trueになったら、上に戻ってもtrueのまま。
  bool _hasReachedBottom = false;

  /// 保存中は、ボタンを押せなくする(連打で、二重に保存しないため)。
  bool _isSaving = false;

  /// スクロール位置が末尾に届いたかを調べる。本文が画面に収まる(スクロール
  /// 不要)ときも、届いたものとして扱う。
  void _checkReachedBottom(ScrollMetrics metrics) {
    if (_hasReachedBottom) return;
    if (metrics.extentAfter <= _bottomThreshold) {
      setState(() => _hasReachedBottom = true);
    }
  }

  Future<void> _accept() async {
    if (_isSaving || !_hasReachedBottom) return;
    setState(() => _isSaving = true);
    try {
      // 保存に成功すると、起動時の分岐(ConsentGate)が、ホーム画面に切り替える。
      await ref.read(consentProvider.notifier).accept();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('同意を保存できませんでした'),
          content: const Text('もう一度お試しください。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAccept = _hasReachedBottom && !_isSaving;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              // スクロールしたとき(ScrollNotification)と、画面や本文の大きさが
              // 決まったとき(ScrollMetricsNotification。スクロールが要らない
              // 場合も含む)の、両方で調べる。
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  _checkReachedBottom(n.metrics);
                  return false;
                },
                child: NotificationListener<ScrollMetricsNotification>(
                  onNotification: (n) {
                    _checkReachedBottom(n.metrics);
                    return false;
                  },
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.lg,
                    ),
                    children: [
                      const Text(
                        'ぶらりデートガチャへ、ようこそ',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: AppFontSizes.titleMedium,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'ご利用の前に、利用規約とプライバシーポリシーをご確認ください。'
                        '最後まで読むと、同意して始められます。',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppFontSizes.bodyMedium,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x2l),
                      ...TermsAndPrivacyBody.children(),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_hasReachedBottom) ...[
                    const Text(
                      '最後までスクロールすると、同意できます',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppFontSizes.caption,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  ElevatedButton(
                    onPressed: canAccept ? _accept : null,
                    child: const Text('同意して始める'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
