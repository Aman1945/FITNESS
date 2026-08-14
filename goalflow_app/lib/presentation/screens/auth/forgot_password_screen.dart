import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/common.dart';
import 'auth_scaffold.dart';

/// Two steps in one screen: request a reset email (Resend), then paste the token
/// and choose a new password.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _password = TextEditingController();

  bool _sent = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (Validate.email(_email.text) != null) {
      showSnack(context, 'Enter a valid email address', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).forgotPassword(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(_token.text.trim(), _password.text);
      if (!mounted) return;
      showSnack(context, 'Password updated. Sign in with your new password.');
      context.go('/login');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: _sent ? 'Set a new password' : 'Reset your password',
      subtitle: _sent
          ? 'Paste the code from the email we just sent, then pick a new password.'
          : 'We will email you a secure link and code.',
      content: [
        if (!_sent) ...[
          AppField(
            label: 'Email',
            controller: _email,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: Validate.email,
            onSubmitted: _request,
          ),
          FilledButton(
            onPressed: _busy ? null : _request,
            child: const Text('Send reset email'),
          ),
        ] else
          Form(
            key: _form,
            child: Column(
              children: [
                AppField(
                  label: 'Reset code',
                  controller: _token,
                  hint: 'Paste the code from the email',
                  validator: (v) => Validate.required(v, 'Reset code'),
                  maxLines: 2,
                ),
                PasswordField(
                  label: 'New password',
                  controller: _password,
                  hint: 'At least 8 characters',
                  validator: Validate.password,
                  onSubmitted: _reset,
                ),
                const SizedBox(height: Gap.sm),
                FilledButton(
                  onPressed: _busy ? null : _reset,
                  child: const Text('Update password'),
                ),
                TextButton(
                  onPressed: () => setState(() => _sent = false),
                  child: const Text('Use a different email'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
