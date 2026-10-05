import 'package:cloud_functions/cloud_functions.dart';

import '../../core/config/flavor.dart';
import '../../domain/entities/inquiry.dart';
import '../../domain/repositories/inquiry_repository.dart';
import '../datasources/cloud/anonymous_auth.dart';

/// テストで[FirebaseFunctions]の実通信を避けるための注入ポイント。
typedef InquiryCallable =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

/// バックエンド(Firebase Functions)の`sendInquiry`を呼び出し、運営者のメールに
/// お問い合わせを送る(Issue #119・#120)。
class InquiryRepositoryImpl implements InquiryRepository {
  InquiryRepositoryImpl({
    InquiryCallable? callable,
    Future<void> Function()? ensureSignedIn,
  }) : _callable = callable ?? _defaultCallable,
       // 注入した[callable](テスト)のときは、本物のFirebaseAuthには触れない。
       _ensureSignedIn =
           ensureSignedIn ??
           (callable == null ? _defaultEnsureSignedIn : _noSignIn);

  final InquiryCallable _callable;
  final Future<void> Function() _ensureSignedIn;

  static Future<Map<String, dynamic>> _defaultCallable(
    Map<String, dynamic> data,
  ) async {
    final callable = FirebaseFunctions.instance.httpsCallable('sendInquiry');
    final result = await callable.call<Map<String, dynamic>>(data);
    return result.data;
  }

  static Future<void> _defaultEnsureSignedIn() async {
    await AnonymousAuth.instance.ensureUid();
  }

  static Future<void> _noSignIn() async {}

  @override
  Future<void> send(Inquiry inquiry) async {
    // 起動時のログインに失敗していても、ここでやり直す。
    try {
      await _ensureSignedIn();
    } catch (_) {
      throw const InquiryException('サインインできませんでした。通信状況を確認して、もう一度お試しください');
    }

    try {
      await _callable({
        'category': inquiry.category.name,
        'message': inquiry.message.trim(),
        'replyTo': inquiry.replyTo.trim(),
        // 調査用に、メールに添える。
        'flavor': AppConfig.flavor.name,
      });
    } on FirebaseFunctionsException catch (e) {
      // 入力の誤りと、1日の上限は、バックエンドの案内をそのまま出す。それ以外
      // (通信の失敗など)は、内部の表記が出ないよう、決まった文言にする。
      if ((e.code == 'invalid-argument' || e.code == 'resource-exhausted') &&
          e.message != null) {
        throw InquiryException(e.message!);
      }
      throw const InquiryException('送信できませんでした。通信状況を確認して、もう一度お試しください');
    }
  }
}
