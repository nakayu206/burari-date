import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_update.dart';
import '../providers/app_update_providers.dart';
import 'update_available_dialog.dart';

/// 起動後、Google Playに新しいバージョンがあり、まだ案内していないときに、案内の
/// ダイアログを出す(Issue #224)。[child]は、更新の確認を待たずに、そのまま出す。
///
/// 同じ更新(ビルド番号)の案内は1回だけ。案内したビルド番号を、ダイアログを出す前に
/// 保存するため、途中でアプリを閉じても、同じ更新を繰り返さない。次の更新が出たときは、
/// また案内する。更新を促すだけで、利用は止めない。
class UpdatePromptGate extends ConsumerStatefulWidget {
  const UpdatePromptGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdatePromptGate> createState() => _UpdatePromptGateState();
}

class _UpdatePromptGateState extends ConsumerState<UpdatePromptGate> {
  bool _isPrompted = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(updateToNotifyProvider, (_, next) {
      final update = next.asData?.value;
      if (update == null || _isPrompted) return;
      _isPrompted = true;
      _prompt(update);
    }, fireImmediately: true);
  }

  Future<void> _prompt(AppUpdate update) async {
    final repository = ref.read(appUpdateRepositoryProvider);
    try {
      await repository.saveNotifiedVersion(update.versionCode);
    } catch (_) {
      // 保存できなくても、案内は出す(次の起動で、同じ更新をまた案内するだけ)。
    }
    if (!mounted) return;
    final shouldUpdate = await showUpdateAvailableDialog(context);
    if (!shouldUpdate) return;
    try {
      await repository.openStorePage(update);
    } catch (_) {
      // 商品ページを開けなかったときは、何もしない。利用者は、Playから更新できる。
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
