import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../application/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/goal.dart';
import '../../widgets/common.dart';
import '../../widgets/goal_widgets.dart';
import '../auth/auth_scaffold.dart';

/// Create or edit a goal. Defaults come from the user's own preferences, so a
/// new goal is already shaped around how they work.
class CreateGoalScreen extends ConsumerStatefulWidget {
  const CreateGoalScreen({super.key, this.goalId});

  final String? goalId;
  bool get isEdit => goalId != null;

  @override
  ConsumerState<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends ConsumerState<CreateGoalScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _why = TextEditingController();
  final _customCategory = TextEditingController();

  String _category = 'personal';
  String _priority = 'medium';
  DateTime _targetDate = DateTime.now().add(const Duration(days: 60));
  Color _color = AppColors.goalPalette.first;

  String _routineType = 'specific_days';
  List<int> _days = [1, 3, 5];
  int _timesPerWeek = 3;
  TimeOfDay _startTime = const TimeOfDay(hour: 19, minute: 0);
  int _duration = 30;

  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(currentUserProvider)?.preferences;
    if (prefs != null && !widget.isEdit) {
      _days = [...prefs.preferredDays];
      _timesPerWeek = prefs.preferredDays.length;
      _duration = prefs.defaultSessionMinutes;
      final parts = prefs.preferredStartTime.split(':');
      _startTime = TimeOfDay(
        hour: int.tryParse(parts.first) ?? 19,
        minute: int.tryParse(parts.last) ?? 0,
      );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _why.dispose();
    _customCategory.dispose();
    super.dispose();
  }

  void _hydrate(Goal g) {
    if (_loaded) return;
    _loaded = true;
    _title.text = g.title;
    _description.text = g.description ?? '';
    _why.text = g.why ?? '';
    _customCategory.text = g.customCategory ?? '';
    _category = g.category;
    _priority = g.priority;
    _targetDate = g.targetDate;
    _routineType = g.routine.type;
    _days = [...g.routine.days];
    _timesPerWeek = g.routine.timesPerWeek;
    _duration = g.routine.durationMinutes;
    final parts = g.routine.startTime.split(':');
    _startTime = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 19,
      minute: int.tryParse(parts.last) ?? 0,
    );
  }

  String get _startTimeString =>
      '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _busy) return;
    if (_routineType == 'specific_days' && _days.isEmpty) {
      showSnack(context, 'Pick at least one day', error: true);
      return;
    }

    setState(() => _busy = true);
    final repo = ref.read(goalRepositoryProvider);
    final routine = Routine(
      type: _routineType,
      days: _days,
      timesPerWeek: _routineType == 'weekly_count' ? _timesPerWeek : _days.length,
      timeOfDay: _startTime.hour < 12
          ? 'morning'
          : _startTime.hour < 17
              ? 'afternoon'
              : _startTime.hour < 21
                  ? 'evening'
                  : 'night',
      startTime: _startTimeString,
      durationMinutes: _duration,
    );

    try {
      if (widget.isEdit) {
        await repo.update(widget.goalId!, {
          'title': _title.text.trim(),
          'description': _description.text.trim(),
          'why': _why.text.trim(),
          'category': _category,
          if (_category == 'custom') 'customCategory': _customCategory.text.trim(),
          'priority': _priority,
          'targetDate': _targetDate.toIso8601String(),
          'routine': routine.toJson(),
        });
        ref.invalidate(goalDetailProvider(widget.goalId!));
      } else {
        await repo.create(
          title: _title.text.trim(),
          category: _category,
          priority: _priority,
          targetDate: _targetDate,
          routine: routine,
          description: _description.text.trim(),
          why: _why.text.trim(),
          customCategory: _customCategory.text.trim(),
          color: '#${_color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
        );
      }
      invalidateProgressData(ref);
      if (!mounted) return;
      showSnack(context, widget.isEdit ? 'Goal updated' : 'Goal created');
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
    if (widget.isEdit && !_loaded) {
      final async = ref.watch(goalDetailProvider(widget.goalId!));
      return async.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: ErrorView(message: e.toString())),
        data: (d) {
          _hydrate(d.goal);
          return _buildForm(context);
        },
      );
    }
    return _buildForm(context);
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Edit goal' : 'New goal')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.xxl),
          children: [
            AppField(
              label: 'What do you want to achieve?',
              controller: _title,
              hint: 'e.g. Run a 10K',
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Give your goal a name'
                  : null,
            ),
            AppField(
              label: 'Why does it matter? (optional)',
              controller: _why,
              hint: 'The reason you will come back to on a hard day',
              maxLines: 2,
            ),
            AppField(
              label: 'Description (optional)',
              controller: _description,
              hint: 'Any detail worth remembering',
              maxLines: 3,
            ),

            Text('Category', style: theme.textTheme.labelLarge),
            const SizedBox(height: Gap.md),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: const [
                'health',
                'learning',
                'career',
                'personal',
                'finance',
                'relationships',
                'productivity',
                'custom',
              ].map((c) {
                final selected = _category == c;
                final color = AppColors.forCategory(c);
                return ChoiceChip(
                  label: Text('${c[0].toUpperCase()}${c.substring(1)}'),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: color.withValues(alpha: 0.16),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? color : null,
                  ),
                  onSelected: (_) => setState(() => _category = c),
                );
              }).toList(),
            ),
            if (_category == 'custom') ...[
              const SizedBox(height: Gap.lg),
              AppField(
                label: 'Category name',
                controller: _customCategory,
                hint: 'e.g. Music',
              ),
            ],
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

            if (!widget.isEdit) ...[
              Text('Colour', style: theme.textTheme.labelLarge),
              const SizedBox(height: Gap.md),
              Row(
                children: AppColors.goalPalette.map((c) {
                  final selected = _color == c;
                  return Padding(
                    padding: const EdgeInsets.only(right: Gap.md),
                    child: GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(color: theme.colorScheme.onSurface, width: 2.4)
                              : null,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: Gap.xl),
            ],

            Text('Target date', style: theme.textTheme.labelLarge),
            const SizedBox(height: Gap.md),
            AppCard(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _targetDate,
                  firstDate: DateTime.now().add(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 1095)),
                );
                if (picked != null) setState(() => _targetDate = picked);
              },
              child: Row(
                children: [
                  const Icon(Icons.event_rounded, size: 20),
                  const SizedBox(width: Gap.md),
                  Text(DateFormat('d MMMM yyyy').format(_targetDate)),
                  const Spacer(),
                  Text('${_targetDate.difference(DateTime.now()).inDays} days',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: Gap.xxl),

            Text('Routine', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('How often will you work on this?',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: Gap.lg),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'daily', label: Text('Daily')),
                ButtonSegment(value: 'specific_days', label: Text('Days')),
                ButtonSegment(value: 'weekly_count', label: Text('Weekly')),
              ],
              selected: {_routineType},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _routineType = s.first),
            ),
            const SizedBox(height: Gap.xl),

            if (_routineType == 'specific_days')
              DayPicker(selected: _days, onChanged: (d) => setState(() => _days = d))
            else if (_routineType == 'weekly_count')
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _timesPerWeek.toDouble(),
                      min: 1,
                      max: 7,
                      divisions: 6,
                      label: '$_timesPerWeek per week',
                      onChanged: (v) => setState(() => _timesPerWeek = v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 66,
                    child: Text('$_timesPerWeek /wk',
                        style: theme.textTheme.titleMedium),
                  ),
                ],
              ),

            const SizedBox(height: Gap.xl),
            AppCard(
              onTap: () async {
                final picked =
                    await showTimePicker(context: context, initialTime: _startTime);
                if (picked != null) setState(() => _startTime = picked);
              },
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 20),
                  const SizedBox(width: Gap.md),
                  const Text('Preferred time'),
                  const Spacer(),
                  Text(_startTime.format(context), style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            const SizedBox(height: Gap.lg),
            Text('Session length', style: theme.textTheme.labelLarge),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _duration.toDouble(),
                    min: 10,
                    max: 120,
                    divisions: 11,
                    label: '$_duration min',
                    onChanged: (v) => setState(() => _duration = v.round()),
                  ),
                ),
                SizedBox(
                  width: 66,
                  child: Text('$_duration min', style: theme.textTheme.titleMedium),
                ),
              ],
            ),

            const SizedBox(height: Gap.xxl),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(widget.isEdit ? 'Save changes' : 'Create goal'),
            ),
          ],
        ),
      ),
    );
  }
}
