import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/entities/account_status.dart';
import '../../../domain/repositories/account_repository.dart';
import '../../providers/account_providers.dart';

/// アカウント画面(Issue #129)。
///
/// ゲスト(匿名のまま)のときは、登録の案内とログイン方法のボタンを出す。登録すると、
/// いまの履歴・お気に入りを引き継げる。登録済みのときは、ログイン方法と、ログアウトの
/// ボタンを出す。登録・ログアウトの処理は[AccountRepository]に任せる。
class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  /// 登録・ログアウトの処理中は、ボタンを押せなくする。
  bool _isBusy = false;

  Future<void> _register(LoginMethod method) async {
    await _run(
      errorTitle: 'アカウントを登録できませんでした',
      action: () => ref.read(accountStatusProvider.notifier).register(method),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウトしますか?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('やめる'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      errorTitle: 'ログアウトできませんでした',
      action: () => ref.read(accountStatusProvider.notifier).signOut(),
    );
  }

  Future<void> _run({
    required String errorTitle,
    required Future<void> Function() action,
  }) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    String? errorMessage;
    try {
      await action();
    } on AccountCancelledException {
      // 利用者が取りやめただけなので、何も出さない。
    } on AccountException catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = '時間をおいて、もう一度お試しください。';
    }
    if (!mounted) return;
    // ダイアログの裏で、進行中の表示が回り続けないよう、処理中の状態を先に戻す。
    // ダイアログは画面全体を覆うので、この間に、もう一度押されることはない。
    setState(() => _isBusy = false);
    if (errorMessage != null) await _showError(errorTitle, errorMessage);
  }

  Future<void> _showError(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(accountStatusProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('アカウント')),
      body: SafeArea(
        child: status.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              _LoadError(onRetry: () => ref.invalidate(accountStatusProvider)),
          data: (account) => ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              _Header(account: account),
              const SizedBox(height: AppSpacing.x2l),
              if (account.isRegistered)
                _RegisteredBody(isBusy: _isBusy, onSignOut: _signOut)
              else
                _GuestBody(isBusy: _isBusy, onRegister: _register),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.account});

  final AccountStatus account;

  @override
  Widget build(BuildContext context) {
    final method = account.method;
    return Row(
      children: [
        const CircleAvatar(
          radius: AppSizes.iconLg,
          backgroundColor: AppColors.primaryLight,
          child: Icon(
            Icons.person_outline_rounded,
            color: AppColors.textSecondary,
            size: AppSizes.iconLg,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.isRegistered ? 'アカウント登録済み' : 'ゲスト利用中',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppFontSizes.bodyLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                account.isRegistered
                    ? 'ログイン方法: ${method?.label ?? ''}'
                    : 'アカウントは、まだ登録していません',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFontSizes.labelSmall,
                ),
              ),
              if (account.email != null)
                Text(
                  account.email!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFontSizes.labelSmall,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ゲストのときの、登録の案内とボタン。
class _GuestBody extends StatelessWidget {
  const _GuestBody({required this.isBusy, required this.onRegister});

  final bool isBusy;
  final void Function(LoginMethod method) onRegister;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BodyText(
          'アカウントを登録すると、いまの履歴とお気に入りを、そのまま引き継げます。\n'
          '無料で使える回数を使い切ったあとは、アカウントの登録と課金が必要です。',
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final method in LoginMethod.values)
          ElevatedButton(
            onPressed: isBusy ? null : () => onRegister(method),
            child: isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('${method.label}で登録する'),
          ),
      ],
    );
  }
}

/// 登録済みのときの、ログアウトのボタン。
class _RegisteredBody extends StatelessWidget {
  const _RegisteredBody({required this.isBusy, required this.onSignOut});

  final bool isBusy;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BodyText('履歴とお気に入りは、このアカウントに保存されています。'),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton(
          onPressed: isBusy ? null : onSignOut,
          child: const Text('ログアウト'),
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BodyText('アカウントの状態を取得できませんでした。'),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('もう一度読み込む')),
          ],
        ),
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  const _BodyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: AppFontSizes.bodyMedium,
        height: 1.6,
      ),
    );
  }
}
