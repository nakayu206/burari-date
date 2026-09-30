import 'package:flutter/material.dart';

/// 設定の保存に失敗したことを知らせるダイアログ。変更前の値に戻っている
/// ことも伝える(docs/コード規約.md: 保存・通信のエラーはダイアログで表示)。
Future<void> showSettingsSaveErrorDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('設定を保存できませんでした'),
      content: const Text('変更は反映されていません。もう一度お試しください。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    ),
  );
}
