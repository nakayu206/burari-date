/// お問い合わせの種類。
enum InquiryCategory {
  bug('不具合'),
  request('要望'),
  other('その他');

  const InquiryCategory(this.label);

  /// 画面に出す名前。
  final String label;
}

/// アプリ内の問い合わせフォームで送る内容(Issue #120)。
class Inquiry {
  const Inquiry({
    required this.category,
    required this.message,
    required this.replyTo,
  });

  final InquiryCategory category;

  /// 本文。
  final String message;

  /// 返信先のメールアドレス。匿名ログインのため、ほかに連絡する手段がなく、必須。
  final String replyTo;

  /// 本文の最大文字数(バックエンドの上限と合わせる)。
  static const maxMessageLength = 1000;

  // 厳密な検証はせず、明らかな間違い(空白・@なし)だけを弾く(バックエンドと同じ)。
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// 返信先として、使えるメールアドレスか。
  static bool isValidEmail(String value) =>
      value.length <= 254 && _emailPattern.hasMatch(value.trim());
}
