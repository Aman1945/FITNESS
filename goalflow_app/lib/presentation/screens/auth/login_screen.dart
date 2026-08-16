import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/common.dart';
import 'auth_scaffold.dart';

/// The first screen most people see, so it carries the brand rather than being
/// a bare form. Everything below the fold is still one tap away; nothing is
/// hidden behind decoration.
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
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).login(_email.text.trim(), _password.text);
      // The router's redirect takes it from here.
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _useDemoAccount() {
    _email.text = 'demo@goalflow.app';
    _password.text = 'Demo1234';
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            // Keeps the submit button reachable once the keyboard is up.
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xxl, Gap.page, Gap.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ---------- brand ----------
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: BrandBadge(size: 68),
                      ),
                      const SizedBox(height: Gap.xl),
                      Text('Welcome back', style: theme.textTheme.displaySmall),
                      const SizedBox(height: Gap.sm),
                      Text(
                        'Pick up where you left off.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: Gap.xxl),

                      // ---------- form ----------
                      Form(
                        key: _form,
                        child: AutofillGroup(
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
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: Gap.sm, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Forgot password?'),
                                ),
                              ),
                              const SizedBox(height: Gap.xl),
                              FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: _busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Sign in'),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: Gap.xl),
                      // One tap into a populated account. Reviewers and first-time
                      // users should not have to type credentials to see the app.
                      _DemoTile(onTap: _busy ? null : _useDemoAccount),

                      const Spacer(),
                      const SizedBox(height: Gap.xl),

                      // ---------- footer ----------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('New here?', style: theme.textTheme.bodyMedium),
                          TextButton(
                            onPressed: () => context.push('/register'),
                            child: const Text('Create an account'),
                          ),
                        ],
                      ),
                      Center(
                        child: Text(
                          'Your goals, your pace.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: isDark ? 0.5 : 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  const _DemoTile({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Material(
      color: accent.withValues(alpha: theme.brightness == Brightness.dark ? 0.16 : 0.07),
      borderRadius: BorderRadius.circular(Gap.radiusSm + 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Gap.radiusSm + 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
          child: Row(
            children: [
              Icon(Icons.play_circle_outline_rounded, size: 20, color: accent),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Try the demo account',
                      style: theme.textTheme.titleMedium?.copyWith(color: accent),
                    ),
                    Text(
                      'Three goals with three weeks of history',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, size: 18, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
