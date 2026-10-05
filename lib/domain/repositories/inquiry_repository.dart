import '../entities/inquiry.dart';

/// お問い合わせを送れなかった理由を、利用者向けの文言で持つ例外。
///
/// [toString]も文言だけを返し、「Exception:」などの内部用の表記が画面に出ない
/// ようにしている。
class InquiryException implements Exception {
  const InquiryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// お問い合わせを、運営者に送る(Issue #120)。
abstract class InquiryRepository {
  /// 送れなかったときは[InquiryException]を投げる。
  Future<void> send(Inquiry inquiry);
}
