import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// 端末ごとの識別子(Issue #165)。最初に1回だけ、ランダムに作って、端末に保存する。
///
/// 無料枠(累計10回)を、ログアウトで数え直されないようにするため(再インストールは、バックアップで復元されたときだけ防げる)、
/// 候補の取得のときに、サーバーへ送る。ログアウトすると、ユーザーIDは変わるが、この
/// 識別子は変わらない。個人を特定する情報は、含まない。
class DeviceId {
  DeviceId({Future<SharedPreferences> Function()? preferences, Random? random})
    : _preferences = preferences ?? SharedPreferences.getInstance,
      _random = random ?? Random.secure();

  /// アプリ全体で共有するインスタンス。
  static final instance = DeviceId();

  static const _key = 'device.id';

  final Future<SharedPreferences> Function() _preferences;
  final Random _random;

  /// 保存済みの識別子。まだなければ、作って保存してから返す。
  Future<String> get() async {
    final prefs = await _preferences();
    final saved = prefs.getString(_key);
    if (saved != null && saved.isNotEmpty) return saved;

    final id = _generate();
    await prefs.setString(_key, id);
    return id;
  }

  /// 英数字32文字(サーバーが受け付ける、16〜64文字の英数字)。
  String _generate() {
    const chars = '0123456789abcdef';
    return List.generate(
      32,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }
}
