import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../application/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/goal_widgets.dart';
import '../auth/auth_scaffold.dart';

/// Creating an action defines a RULE. The backend immediately materialises the
/// next week of dated instances, so the new action appears on Today straight
/// away instead of after the nightly job.
class CreateActionScreen extends ConsumerStatefulWidget {
  const CreateActionScreen({super.key, required this.goalId, this.milestoneId});

  final String goalId;
  final String? milestoneId;

  @override
  ConsumerState<CreateActionScreen> createState() => _CreateActionScreenState();
}

class _CreateActionScreenState extends ConsumerState<CreateActionScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _targetCount = TextEditingController();
  final _unit = TextEditingController();

  String? _milestoneId;
  String _recurrenceType = 'specific_days';
  List<int> _days = [1, 3, 5];
  int _minutes = 30;
  String _priority = 'medium';
  String _difficulty = 'medium';
  TimeOfDay? _time;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 3));
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _milestoneId = widget.milestoneId;
    final prefs = ref.read(currentUserProvider)?.preferences;
    if (prefs != null) {
      _days = [...prefs.preferredDays];
      _minutes = prefs.defaultSessionMinutes;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _targetCount.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _busy) return;
    if (_recurrenceType == 'specific_days' && _days.isEmpty) {
      showSnack(context, 'Pick at least one day', error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(goalRepositoryProvider).createAction(
            goalId: widget.goalId,
            milestoneId: _milestoneId,
            title: _title.text.trim(),
            description: _description.text.trim(),
            estimatedMinutes: _minutes,
            priority: _priority,
            difficulty: _difficulty,
            recurrenceType: _recurrenceType,
            days: _recurrenceType == 'specific_days' ? _days : const [],
            preferredTime: _time == null
                ? null
                : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}',
            dueDate: _recurrenceType == 'once' ? _dueDate : null,
            targetCount: int.tryParse(_targetCount.text.trim()),
            unit: _unit.text.trim(),
          );
      ref.invalidate(goalDetailProvider(widget.goalId));
      invalidateProgressData(ref);
      if (!mounted) return;
      showSnack(context, 'Action added to your schedule');
      context.pop();
    } on ApiException catch (e) {
      if (mounted) {
        showSnack(context, e.fieldErrors?.values.first ?? e.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = ref.watch(goalDetailProvider(widget.goalId));

    return Scaffold(
      appBar: AppBar(title: const Text('New action')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.xxl),
          children: [
            AppField(
              label: 'What will you do?',
              controller: _title,
              hint: 'e.g. Learn 20 new words',
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Name the action' : null,
            ),
            AppField(
              label: 'Notes (optional)',
              controller: _description,
              hint: 'Anything that helps you start faster',
              maxLines: 2,
            ),

            detail.maybeWhen(
              data: (d) => d.milestones.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Milestone (optional)',
                            style: theme.textTheme.labelLarge),
                        const SizedBox(height: Gap.md),
                        Wrap(
                          spacing: Gap.sm,
                          runSpacing: Gap.sm,
                          children: [
                            ChoiceChip(
                              label: const Text('None'),
                              selected: _milestoneId == null,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => _milestoneId = null),
                            ),
                            ...d.milestones.map(
                              (m) => ChoiceChip(
                                label: Text(m.title),
                                selected: _milestoneId == m.id,
                                showCheckmark: false,
                                onSelected: (_) => setState(() => _milestoneId = m.id),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Gap.xl),
                      ],
                    ),
              orElse: () => const SizedBox.shrink(),
            ),

            Text('How often?', style: theme.textTheme.labelLarge),
            const SizedBox(height: Gap.md),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'daily', label: Text('Daily')),
                ButtonSegment(value: 'specific_days', label: Text('Days')),
                ButtonSegment(value: 'once', label: Text('Once')),
              ],
              selected: {_recurrenceType},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _recurrenceType = s.first),
            ),
            const SizedBox(height: Gap.xl),

            if (_recurrenceType == 'specific_days')
              DayPicker(selected: _days, onChanged: (d) => setState(() => _days = d))
            else if (_recurrenceType == 'once')
              AppCard(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _dueDate = picked);
                },
                child: Row(
                  children: [
                    const Icon(Icons.event_rounded, size: 20),
                    const SizedBox(width: Gap.md),
                    const Text('Due date'),
                    const Spacer(),
                    Text(DateFormat('d MMM yyyy').format(_dueDate),
                        style: theme.textTheme.titleMedium),
                  ],
                ),
              ),

            const SizedBox(height: Gap.xl),
            AppCard(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _time ?? const TimeOfDay(hour: 19, minute: 0),
                );
                if (picked != null) setState(() => _time = picked);
              },
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 20),
                  const SizedBox(width: Gap.md),
                  const Text('Time'),
                  const Spacer(),
                  Text(
                    _time?.format(context) ?? "Use the goal's routine",
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Gap.xl),
            Text('How long?', style: theme.textTheme.labelLarge),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _minutes.toDouble(),
                    min: 5,
                    max: 120,
                    divisions: 23,
                    label: '$_minutes min',
                    onChanged: (v) => setState(() => _minutes = v.round()),
                  ),
                ),
                SizedBox(
                  width: 66,
                  child: Text('$_minutes min', style: theme.textTheme.titleMedium),
                ),
              ],
            ),

            const SizedBox(height: Gap.lg),
            Text('Difficulty', style: theme.textTheme.labelLarge),
            const SizedBox(height: Gap.md),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'easy', label: Text('Easy')),
                ButtonSegment(value: 'medium', label: Text('Medium')),
                ButtonSegment(value: 'hard', label: Text('Hard')),
              ],
              selected: {_difficulty},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _difficulty = s.first),
            ),

            const SizedBox(height: Gap.xl),
            Text('Priority', style: theme.textTheme.labelLarge),
            const SizedBox(height: Gap.md),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'low', label: Text('Low')),
                ButtonSegment(value: 'medium', label: Text('Medium')),
                ButtonSegment(value: 'high', label: Text('High')),
              ],
              selected: {_priority},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _priority = s.first),
            ),

            const SizedBox(height: Gap.xl),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppField(
                    label: 'Target (optional)',
                    controller: _targetCount,
                    hint: '20',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  flex: 2,
                  child: AppField(
                    label: 'Unit',
                    controller: _unit,
                    hint: 'e.g. words, pages, km',
                  ),
                ),
              ],
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
                  : const Text('Add action'),
            ),
          ],
        ),
      ),
    );
  }
}
