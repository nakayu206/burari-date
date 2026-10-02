import 'package:firebase_auth/firebase_auth.dart';

/// 匿名ログインしているUIDを返す。まだログインしていなければ、その場でログインする。
///
/// 起動時のログインが圏外などで失敗しても、通信が戻ったあとに、候補の取得・
/// 履歴・お気に入りの操作から、ログインをやり直せるようにする(Issue #105)。
class AnonymousAuth {
  AnonymousAuth({
    String? Function()? currentUid,
    Future<String> Function()? signIn,
  }) : _currentUid = currentUid ?? _defaultCurrentUid,
       _signIn = signIn ?? _defaultSignIn;

  /// アプリ全体で共有するインスタンス(本物の[FirebaseAuth]を使う)。
  static final instance = AnonymousAuth();

  final String? Function() _currentUid;
  final Future<String> Function() _signIn;

  /// ログイン中の呼び出しが重なっても、ログインは1回だけにするための保持。
  Future<String>? _pending;

  static String? _defaultCurrentUid() => FirebaseAuth.instance.currentUser?.uid;

  static Future<String> _defaultSignIn() async {
    final credential = await FirebaseAuth.instance.signInAnonymously();
    final uid = credential.user?.uid;
    if (uid == null) throw Exception('サインインが完了していません');
    return uid;
  }

  /// ログイン済みならそのUID、まだなら匿名ログインしてそのUIDを返す。失敗したら
  /// 例外を投げる(失敗は保持しないので、次の呼び出しで、またやり直す)。
  Future<String> ensureUid() {
    final uid = _currentUid();
    if (uid != null) return Future.value(uid);
    return _pending ??= _signIn().whenComplete(() => _pending = null);
  }
}
