import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/consent_repository.dart';

/// 端末ローカル(SharedPreferences)に、同意した規約の版を保存する。
class ConsentRepositoryImpl implements ConsentRepository {
  static const _kAcceptedVersion = 'consent.terms.version';

  @override
  Future<int?> loadAcceptedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kAcceptedVersion);
  }

  @override
  Future<void> saveAcceptedVersion(int version) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setInt(_kAcceptedVersion, version);
    // 保存できていないのに「同意済み」と扱うと、次の起動でまた求めることになる。
    // 失敗は、呼び出し元(画面)に伝える。
    if (!saved) throw StateError('同意を保存できませんでした');
  }
}
