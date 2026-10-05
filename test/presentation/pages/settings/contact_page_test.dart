import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/domain/entities/inquiry.dart';
import 'package:burari_date/domain/repositories/inquiry_repository.dart';
import 'package:burari_date/presentation/pages/settings/contact_page.dart';
import 'package:burari_date/presentation/providers/inquiry_providers.dart';

/// 送った内容を記録するだけの偽のリポジトリ。[gate]を設定すると、送信の完了を、
/// それが完了するまで遅らせる。[error]を設定すると、その例外で失敗する。
class _FakeInquiryRepository implements InquiryRepository {
  final sent = <Inquiry>[];
  Completer<void>? gate;
  Object? error;

  @override
  Future<void> send(Inquiry inquiry) async {
    sent.add(inquiry);
    await gate?.future;
    if (error != null) throw error!;
  }
}

void main() {
  void useLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpPage(
    WidgetTester tester,
    _FakeInquiryRepository repository,
  ) async {
    useLargeScreen(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [inquiryRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: ContactPage()),
      ),
    );
  }

  Finder messageField() => find.byType(TextField).first;
  Finder emailField() => find.byType(TextField).last;
  // 送信中は、ボタンの文字が進行中の表示に替わるため、種類で探す。
  Finder sendButton() => find.byType(ElevatedButton);

  Future<void> fillIn(
    WidgetTester tester, {
    String message = '地図が表示されません',
    String email = 'user@example.com',
  }) async {
    await tester.enterText(messageField(), message);
    await tester.enterText(emailField(), email);
    await tester.pump();
  }

  bool isSendEnabled(WidgetTester tester) =>
      tester.widget<ElevatedButton>(sendButton()).onPressed != null;

  testWidgets('種類・内容・返信先の入力欄と、送信ボタンを表示する', (tester) async {
    await pumpPage(tester, _FakeInquiryRepository());

    expect(find.text('不具合'), findsOneWidget);
    expect(find.text('要望'), findsOneWidget);
    expect(find.text('その他'), findsOneWidget);
    expect(find.text('返信先のメールアドレス(必須)'), findsOneWidget);
    expect(sendButton(), findsOneWidget);
  });

  testWidgets('本文と返信先が入るまで、送信ボタンは押せない', (tester) async {
    await pumpPage(tester, _FakeInquiryRepository());
    expect(isSendEnabled(tester), isFalse);

    await tester.enterText(messageField(), '地図が表示されません');
    await tester.pump();
    expect(isSendEnabled(tester), isFalse, reason: '返信先がない');

    await tester.enterText(emailField(), 'user@example.com');
    await tester.pump();
    expect(isSendEnabled(tester), isTrue);
  });

  testWidgets('本文が空白だけでは、送信できない', (tester) async {
    await pumpPage(tester, _FakeInquiryRepository());

    await fillIn(tester, message: '   ');

    expect(isSendEnabled(tester), isFalse);
  });

  testWidgets('返信先の形式が不正なら、メッセージを出し、送信できない', (tester) async {
    await pumpPage(tester, _FakeInquiryRepository());

    await fillIn(tester, email: 'user@');

    expect(find.text('メールアドレスの形式を確認してください'), findsOneWidget);
    expect(isSendEnabled(tester), isFalse);
  });

  testWidgets('送信すると、選んだ種類・内容・返信先を送り、完了を知らせて閉じる', (tester) async {
    final repository = _FakeInquiryRepository();
    await pumpPage(tester, repository);
    await tester.tap(find.text('不具合'));
    await tester.pump();
    await fillIn(
      tester,
      message: '  地図が表示されません  ',
      email: ' user@example.com ',
    );

    await tester.tap(sendButton());
    await tester.pumpAndSettle();

    expect(repository.sent, hasLength(1));
    expect(repository.sent.single.category, InquiryCategory.bug);
    expect(repository.sent.single.message, '地図が表示されません');
    expect(repository.sent.single.replyTo, 'user@example.com');
    expect(find.text('送信しました'), findsOneWidget);

    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();
    expect(find.byType(ContactPage), findsNothing);
  });

  testWidgets('送信中は、二重に押せない', (tester) async {
    final repository = _FakeInquiryRepository()..gate = Completer<void>();
    await pumpPage(tester, repository);
    await fillIn(tester);

    await tester.tap(sendButton());
    await tester.pump();

    expect(isSendEnabled(tester), isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(repository.sent, hasLength(1));
  });

  testWidgets('送信に失敗したら、ダイアログで知らせ、入力は残す', (tester) async {
    final repository = _FakeInquiryRepository()
      ..error = const InquiryException('お問い合わせは、1日5回までです。');
    await pumpPage(tester, repository);
    await fillIn(tester);

    await tester.tap(sendButton());
    await tester.pumpAndSettle();

    expect(find.text('送信できませんでした'), findsOneWidget);
    expect(find.text('お問い合わせは、1日5回までです。'), findsOneWidget);

    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    // 画面は閉じず、入力も残り、もう一度送れる。
    expect(find.byType(ContactPage), findsOneWidget);
    expect(find.text('地図が表示されません'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);
    expect(isSendEnabled(tester), isTrue);
  });

  testWidgets('想定外のエラーでも、内部の表記を出さず、決まった文言で知らせる', (tester) async {
    final repository = _FakeInquiryRepository()..error = StateError('boom');
    await pumpPage(tester, repository);
    await fillIn(tester);

    await tester.tap(sendButton());
    await tester.pumpAndSettle();

    expect(find.text('時間をおいて、もう一度お試しください。'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('外部のフォームのURLや、準備中の表示は出さない', (tester) async {
    await pumpPage(tester, _FakeInquiryRepository());

    expect(find.text('お問い合わせ窓口は準備中です。'), findsNothing);
    expect(find.text('お問い合わせフォームを開く'), findsNothing);
  });
}
