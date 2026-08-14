import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/common.dart';
import 'auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authProvider.notifier)
          .login(_email.text.trim(), _password.text);
      // The router's redirect takes it from here.
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Pick up where you left off.',
      content: [
        Form(
          key: _form,
          child: Column(
            children: [
              AppField(
                label: 'Email',
                controller: _email,
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                validator: Validate.email,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
              ),
              PasswordField(
                label: 'Password',
                controller: _password,
                hint: 'Your password',
                validator: (v) => Validate.required(v, 'Password'),
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: Gap.md),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Text('Sign in'),
              ),
            ],
          ),
        ),
      ],
      footer: Padding(
        padding: const EdgeInsets.only(top: Gap.xxl),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('New here?', style: Theme.of(context).textTheme.bodyMedium),
            TextButton(
              onPressed: () => context.push('/register'),
              child: const Text('Create an account'),
            ),
          ],
        ),
      ),
    );
  }
}
