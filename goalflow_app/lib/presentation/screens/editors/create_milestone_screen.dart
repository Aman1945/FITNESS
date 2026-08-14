import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../application/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/common.dart';
import '../auth/auth_scaffold.dart';

class CreateMilestoneScreen extends ConsumerStatefulWidget {
  const CreateMilestoneScreen({super.key, required this.goalId});

  final String goalId;

  @override
  ConsumerState<CreateMilestoneScreen> createState() => _CreateMilestoneScreenState();
}

class _CreateMilestoneScreenState extends ConsumerState<CreateMilestoneScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  DateTime? _targetDate;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(goalRepositoryProvider).createMilestone(
            widget.goalId,
            title: _title.text.trim(),
            description: _description.text.trim(),
            targetDate: _targetDate,
          );
      ref.invalidate(goalDetailProvider(widget.goalId));
      invalidateProgressData(ref);
      if (!mounted) return;
      showSnack(context, 'Milestone added');
      context.pop();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('New milestone')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.xxl),
          children: [
            Text(
              'A milestone is a checkpoint on the way to your goal - something you can '
              'clearly say you have reached.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: Gap.xl),
            AppField(
              label: 'Milestone',
              controller: _title,
              hint: 'e.g. Build basic vocabulary',
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Give it a name' : null,
            ),
            AppField(
              label: 'Description (optional)',
              controller: _description,
              hint: 'What does reaching this look like?',
              maxLines: 3,
            ),
            Text('Target date (optional)', style: theme.textTheme.labelLarge),
            const SizedBox(height: Gap.md),
            AppCard(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 21)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 1095)),
                );
                if (picked != null) setState(() => _targetDate = picked);
              },
              child: Row(
                children: [
                  const Icon(Icons.event_rounded, size: 20),
                  const SizedBox(width: Gap.md),
                  Text(_targetDate == null
                      ? 'No date set'
                      : DateFormat('d MMMM yyyy').format(_targetDate!)),
                  const Spacer(),
                  if (_targetDate != null)
                    TextButton(
                      onPressed: () => setState(() => _targetDate = null),
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Gap.xxl),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Text('Add milestone'),
            ),
          ],
        ),
      ),
    );
  }
}
