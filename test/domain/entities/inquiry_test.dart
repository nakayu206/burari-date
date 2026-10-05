import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/inquiry.dart';

void main() {
  group('Inquiry.isValidEmail', () {
    test('通常のメールアドレスは使える(前後の空白は無視する)', () {
      expect(Inquiry.isValidEmail('user@example.com'), isTrue);
      expect(Inquiry.isValidEmail(' user@example.co.jp '), isTrue);
    });

    test('明らかな間違いは使えない', () {
      for (final value in [
        '',
        'abc',
        'a@b',
        'a b@c.com',
        '@c.com',
        'a@.com ',
      ]) {
        expect(Inquiry.isValidEmail(value), isFalse, reason: value);
      }
    });

    test('長すぎるアドレスは使えない(バックエンドの上限254文字と合わせる)', () {
      final long = '${'a' * 250}@b.com';
      expect(Inquiry.isValidEmail(long), isFalse);
    });
  });

  test('種類の名前', () {
    expect(InquiryCategory.bug.label, '不具合');
    expect(InquiryCategory.request.label, '要望');
    expect(InquiryCategory.other.label, 'その他');
  });
}
