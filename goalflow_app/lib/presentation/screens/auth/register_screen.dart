import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/common.dart';
import 'auth_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).register(
            _name.text.trim(),
            _email.text.trim(),
            _password.text,
          );
      if (mounted) context.push('/verify-email');
    } on ApiException catch (e) {
      if (!mounted) return;
      // Surface field-level messages from the backend on the right inputs.
      showSnack(context, e.fieldErrors?.values.first ?? e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Two minutes now, and the app works around your week.',
      content: [
        Form(
          key: _form,
          child: Column(
            children: [
              AppField(
                label: 'Name',
                controller: _name,
                hint: 'What should we call you?',
                validator: Validate.name,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
              ),
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
                hint: 'At least 8 characters',
                validator: Validate.password,
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
              ),
              const SizedBox(height: Gap.sm),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Text('Create account'),
              ),
              const SizedBox(height: Gap.md),
              Text(
                'We will email you a 6-digit code to confirm it is you.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
      footer: Padding(
        padding: const EdgeInsets.only(top: Gap.xl),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Already have an account?',
                style: Theme.of(context).textTheme.bodyMedium),
            TextButton(onPressed: () => context.pop(), child: const Text('Sign in')),
          ],
        ),
      ),
    );
  }
}
