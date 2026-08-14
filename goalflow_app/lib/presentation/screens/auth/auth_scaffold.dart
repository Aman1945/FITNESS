import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Shared chrome for every auth screen so they feel like one flow.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.content,
    this.footer,
  });

  final String title;
  final String subtitle;
  final List<Widget> content;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(leading: Navigator.canPop(context) ? const BackButton() : null),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
              // IntrinsicHeight gives the Column a finite height inside the
              // scroll view, which is what lets the footer push to the bottom.
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: Gap.sm),
                    Text(subtitle, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: Gap.xxl),
                    ...content,
                    if (footer != null) ...[const Spacer(), footer!],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text field with consistent label placement and inline validation.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
    this.maxLines = 1,
    this.autofillHints,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;
  final Widget? suffix;
  final int maxLines;
  final List<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 7),
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          onFieldSubmitted: (_) => onSubmitted?.call(),
          decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
        ),
        const SizedBox(height: Gap.lg),
      ],
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;
  final String? hint;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => AppField(
        label: widget.label,
        controller: widget.controller,
        hint: widget.hint,
        obscure: _hidden,
        validator: widget.validator,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        autofillHints: const [AutofillHints.password],
        suffix: IconButton(
          icon: Icon(
            _hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
          ),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      );
}

/// Shared validators so rules match the backend exactly.
class Validate {
  const Validate._();

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final ok = RegExp(r'^[\w.\-+]+@[\w\-]+\.[\w.\-]+$').hasMatch(v.trim());
    return ok ? null : 'Enter a valid email address';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[a-zA-Z]').hasMatch(v)) return 'Include a letter';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Include a number';
    return null;
  }

  static String? required(String? v, [String field = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? name(String? v) {
    if (v == null || v.trim().length < 2) return 'Enter your name';
    return null;
  }
}
