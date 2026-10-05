import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/entities/inquiry.dart';
import '../../../domain/repositories/inquiry_repository.dart';
import '../../providers/inquiry_providers.dart';
import '../../widgets/terms_and_privacy_body.dart';

/// お問い合わせ画面(設定の「お問い合わせ」。Issue #62・#120)。
///
/// 種類・本文・返信先のメールアドレスを入力して送ると、運営者のメールに届く。
/// 返信先は、匿名ログインのため、ほかに連絡する手段がなく、必須。
class ContactPage extends ConsumerStatefulWidget {
  const ContactPage({super.key});

  @override
  ConsumerState<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends ConsumerState<ContactPage> {
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();
  InquiryCategory _category = InquiryCategory.other;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // 入力のたびに、送信ボタンを押せるかどうかを更新する。
    _messageController.addListener(_onChanged);
    _emailController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool get _emailIsValid => Inquiry.isValidEmail(_emailController.text);

  bool get _canSend =>
      !_isSending && _messageController.text.trim().isNotEmpty && _emailIsValid;

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() => _isSending = true);
    final inquiry = Inquiry(
      category: _category,
      message: _messageController.text.trim(),
      replyTo: _emailController.text.trim(),
    );
    try {
      await ref.read(inquiryRepositoryProvider).send(inquiry);
    } on InquiryException catch (e) {
      // 失敗しても、入力は残す。
      if (!mounted) return;
      setState(() => _isSending = false);
      await _showDialog(title: '送信できませんでした', message: e.message);
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSending = false);
      await _showDialog(title: '送信できませんでした', message: '時間をおいて、もう一度お試しください。');
      return;
    }
    if (!mounted) return;
    // ダイアログの裏で、進行中の表示が回り続けないよう、送信中の状態を戻す。ダイアログは
    // 画面全体を覆うので、この間に、もう一度押されることはない。
    setState(() => _isSending = false);
    await _showDialog(
      title: '送信しました',
      message: 'お問い合わせありがとうございます。ご入力のメールアドレスに、ご連絡することがあります。',
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showDialog({required String title, required String message}) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showEmailError =
        _emailController.text.trim().isNotEmpty && !_emailIsValid;
    return Scaffold(
      appBar: AppBar(title: const Text('お問い合わせ')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          children: [
            const LegalBodyText('ご質問・ご要望・不具合のご連絡や、情報の削除のご依頼などは、こちらからお送りください。'),
            const SizedBox(height: AppSpacing.lg),
            const _FieldLabel('種類'),
            const SizedBox(height: 6),
            SegmentedButton<InquiryCategory>(
              expandedInsets: EdgeInsets.zero,
              showSelectedIcon: false,
              segments: [
                for (final category in InquiryCategory.values)
                  ButtonSegment(value: category, label: Text(category.label)),
              ],
              selected: {_category},
              onSelectionChanged: _isSending
                  ? null
                  : (selection) => setState(() => _category = selection.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _FieldLabel('内容'),
            const SizedBox(height: 6),
            TextField(
              controller: _messageController,
              enabled: !_isSending,
              minLines: 6,
              maxLines: 10,
              maxLength: Inquiry.maxMessageLength,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText: 'お問い合わせの内容を入力してください',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _FieldLabel('返信先のメールアドレス(必須)'),
            const SizedBox(height: 6),
            TextField(
              controller: _emailController,
              enabled: !_isSending,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'example@mail.com',
                helperText: 'ご返信のためだけに使います。',
                errorText: showEmailError ? 'メールアドレスの形式を確認してください' : null,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _canSend ? _send : null,
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('送信する'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: AppFontSizes.labelSmall,
      ),
    );
  }
}
