import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/data/repositories/inquiry_repository_impl.dart';
import 'package:burari_date/domain/entities/inquiry.dart';
import 'package:burari_date/domain/repositories/inquiry_repository.dart';

void main() {
  const inquiry = Inquiry(
    category: InquiryCategory.request,
    message: '  夜景のスポットがほしい  ',
    replyTo: ' user@example.com ',
  );

  test('種類・本文・返信先・Flavorを、sendInquiryに渡す(前後の空白は除く)', () async {
    Map<String, dynamic>? sent;
    final repository = InquiryRepositoryImpl(
      callable: (data) async {
        sent = data;
        return {'ok': true};
      },
    );

    await repository.send(inquiry);

    expect(sent?['category'], 'request');
    expect(sent?['message'], '夜景のスポットがほしい');
    expect(sent?['replyTo'], 'user@example.com');
    expect(sent?['flavor'], isA<String>());
  });

  test('呼び出しの前にログインを確かめ、失敗したら、送らずにエラーにする', () async {
    var called = false;
    final repository = InquiryRepositoryImpl(
      callable: (data) async {
        called = true;
        return {};
      },
      ensureSignedIn: () async => throw Exception('network'),
    );

    await expectLater(
      repository.send(inquiry),
      throwsA(isA<InquiryException>()),
    );
    expect(called, isFalse);
  });

  test('入力の誤り・1日の上限は、バックエンドの案内をそのまま伝える', () async {
    for (final code in ['invalid-argument', 'resource-exhausted']) {
      final repository = InquiryRepositoryImpl(
        callable: (data) async =>
            throw FirebaseFunctionsException(message: '案内: $code', code: code),
      );

      await expectLater(
        repository.send(inquiry),
        throwsA(
          isA<InquiryException>().having(
            (e) => e.message,
            'message',
            '案内: $code',
          ),
        ),
        reason: code,
      );
    }
  });

  test('それ以外のエラーは、内部の表記を出さず、決まった文言にする', () async {
    final repository = InquiryRepositoryImpl(
      callable: (data) async => throw FirebaseFunctionsException(
        message: 'INTERNAL',
        code: 'internal',
      ),
    );

    await expectLater(
      repository.send(inquiry),
      throwsA(
        isA<InquiryException>().having(
          (e) => e.message,
          'message',
          isNot(contains('INTERNAL')),
        ),
      ),
    );
  });
}
