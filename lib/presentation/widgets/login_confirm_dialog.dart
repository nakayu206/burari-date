import 'package:flutter/material.dart';

/// 「Googleでログイン」を押したときの、確認のダイアログ(Issue #152・#153)。
///
/// ログインすると、そのGoogleアカウントのアカウントに切り替わり、**いまのゲストの履歴・
/// お気に入りは、引き継がれず、使えなくなる**。登録済みのアカウントなら、以前の履歴・
/// お気に入り・購読が、戻る。うっかり、ゲストの内容を、失わないよう、先に確認する。
///
/// 「ログインする」を選んだときだけ、trueを返す(「やめる」や、画面の外を押したときは、
/// false)。アカウント画面と、プラン画面で、同じ文面を使う。
Future<bool> showLoginConfirmDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('ログインしますか?'),
      content: const Text(
        'Googleアカウントで、ログインします。\n'
        'いまのゲストの履歴とお気に入りは、引き継がれず、使えなくなります。\n'
        '登録済みのアカウントなら、以前の履歴・お気に入り・購読が、戻ります。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('やめる'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('ログインする'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
