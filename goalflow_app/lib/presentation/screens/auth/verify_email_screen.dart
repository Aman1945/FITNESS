import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/common.dart';
import 'auth_scaffold.dart';

/// Verification is optional to continue -- the user can start onboarding right
/// away and confirm later, so signup never dead-ends on an email that is slow
/// to arrive.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.trim().length != 6 || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).verifyEmail(_code.text.trim());
      if (!mounted) return;
      showSnack(context, 'Email verified');
      context.go('/onboarding');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final email = ref.read(authProvider).pendingEmail ??
        ref.read(authProvider).user?.email ??
        '';
    try {
      await ref.read(authRepositoryProvider).resendCode(email);
      if (mounted) showSnack(context, 'A new code is on its way');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authProvider).pendingEmail ??
        ref.watch(authProvider).user?.email ??
        'your email';

    return AuthScaffold(
      title: 'Check your inbox',
      subtitle: 'We sent a 6-digit code to $email.',
      content: [
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: 14,
          ),
          decoration: const InputDecoration(counterText: '', hintText: '------'),
          onChanged: (v) {
            if (v.length == 6) _verify();
          },
        ),
        const SizedBox(height: Gap.xl),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                )
              : const Text('Verify'),
        ),
        const SizedBox(height: Gap.md),
        TextButton(onPressed: _resend, child: const Text('Send a new code')),
      ],
      footer: Padding(
        padding: const EdgeInsets.only(top: Gap.lg),
        child: TextButton(
          onPressed: () => context.go('/onboarding'),
          child: const Text('Skip for now'),
        ),
      ),
    );
  }
}
