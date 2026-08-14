import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../application/providers.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/goal_widgets.dart';
import 'auth/auth_scaffold.dart';

/// Five short steps, one commit at the end.
/// Everything collected here becomes the DEFAULT for the user's first goal, so
/// personalisation is visible on the very first dashboard rather than being a
/// setting they have to discover later.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _step = 0;
  bool _busy = false;

  // step 1
  final _name = TextEditingController();
  // Bytes, not a file path: image_picker's XFile reads bytes on every platform,
  // whereas dart:io File does not exist on web.
  Uint8List? _avatarBytes;
  String _avatarName = 'avatar.jpg';

  // step 2
  final _objective = TextEditingController();

  // step 3
  final _goalTitle = TextEditingController();
  final _goalWhy = TextEditingController();
  final _customCategory = TextEditingController();
  String _category = 'health';
  final String _priority = 'medium';
  DateTime _targetDate = DateTime.now().add(const Duration(days: 60));

  // step 4
  List<int> _days = [1, 3, 5];
  String _timeOfDay = 'evening';
  TimeOfDay _startTime = const TimeOfDay(hour: 19, minute: 0);
  int _duration = 30;

  // step 5
  String _progressStyle = 'percentage';
  int _weeklyTarget = 4;
  final _constraint = TextEditingController();

  static const _steps = 5;

  @override
  void initState() {
    super.initState();
    _name.text = ref.read(currentUserProvider)?.name ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    _name.dispose();
    _objective.dispose();
    _goalTitle.dispose();
    _goalWhy.dispose();
    _customCategory.dispose();
    _constraint.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
        0 => _name.text.trim().length >= 2,
        1 => _objective.text.trim().length >= 3,
        2 => _goalTitle.text.trim().length >= 2,
        3 => _days.isNotEmpty,
        _ => true,
      };

  void _next() {
    if (!_canContinue) return;
    if (_step == _steps - 1) {
      _finish();
      return;
    }
    setState(() => _step++);
    _controller.animateToPage(
      _step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _controller.animateToPage(
      _step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) {
      setState(() {
        _avatarBytes = bytes;
        _avatarName = file.name;
      });
    }
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    final repo = ref.read(appRepositoryProvider);
    try {
      String? avatarUrl;
      if (_avatarBytes != null) {
        try {
          avatarUrl = await repo.uploadAvatar(_avatarBytes!, _avatarName);
        } catch (_) {
          // A failed photo upload must not block onboarding.
        }
      }

      final startTime =
          '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';

      final user = await repo.completeOnboarding({
        'name': _name.text.trim(),
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        'mainObjective': _objective.text.trim(),
        'timezone': 'Asia/Kolkata',
        'preferences': {
          'preferredDays': _days,
          'preferredTimeOfDay': _timeOfDay,
          'preferredStartTime': startTime,
          'defaultSessionMinutes': _duration,
          'weeklyTargetActions': _weeklyTarget,
          'progressStyle': _progressStyle,
          'constraints': [
            if (_constraint.text.trim().isNotEmpty) _constraint.text.trim(),
          ],
        },
        'goals': [
          {
            'title': _goalTitle.text.trim(),
            if (_goalWhy.text.trim().isNotEmpty) 'why': _goalWhy.text.trim(),
            'category': _category,
            if (_category == 'custom' && _customCategory.text.trim().isNotEmpty)
              'customCategory': _customCategory.text.trim(),
            'priority': _priority,
            'targetDate': _targetDate.toIso8601String(),
            'routine': {
              'type': 'specific_days',
              'days': _days,
              'timesPerWeek': _days.length,
              'timeOfDay': _timeOfDay,
              'startTime': startTime,
              'durationMinutes': _duration,
            },
            'useTemplate': true,
          },
        ],
      });

      ref.read(authProvider.notifier).setUser(user);
      // The router redirects to /home once the stage flips to ready.
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.sm),
              child: Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      onPressed: _back,
                      icon: const Icon(Icons.arrow_back_rounded),
                      visualDensity: VisualDensity.compact,
                    )
                  else
                    const SizedBox(width: 40),
                  Expanded(
                    child: Row(
                      children: List.generate(
                        _steps,
                        (i) => Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i <= _step
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).dividerTheme.color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${_step + 1}/$_steps',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _stepAbout(),
                  _stepObjective(),
                  _stepGoal(),
                  _stepRoutine(),
                  _stepStyle(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.lg),
              child: FilledButton(
                onPressed: _canContinue && !_busy ? _next : null,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white),
                      )
                    : Text(_step == _steps - 1 ? 'Start my plan' : 'Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page({required String title, required String subtitle, required List<Widget> children}) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xl, Gap.page, Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: Gap.sm),
          Text(subtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: Gap.xxl),
          ...children,
        ],
      ),
    );
  }

  // ---- step 1 -------------------------------------------------------------

  Widget _stepAbout() => _page(
        title: 'First, the basics',
        subtitle: 'So the app can talk to you like a person.',
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    backgroundImage:
                        _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                    child: _avatarBytes == null
                        ? Icon(Icons.person_rounded,
                            size: 40, color: Theme.of(context).colorScheme.primary)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.sm),
          Center(
            child: Text('Add a photo (optional)',
                style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: Gap.xxl),
          AppField(
            label: 'Your name',
            controller: _name,
            hint: 'e.g. Sam',
            onSubmitted: _next,
          ),
        ],
      );

  // ---- step 2 -------------------------------------------------------------

  Widget _stepObjective() => _page(
        title: 'What are you working toward?',
        subtitle: 'One sentence. This is the thing everything else serves.',
        children: [
          AppField(
            label: 'Main objective',
            controller: _objective,
            hint: 'e.g. Build a healthier, sharper version of myself',
            maxLines: 3,
          ),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: const [
              'Get fit and stay consistent',
              'Learn a new skill properly',
              'Get my finances in order',
              'Grow in my career',
            ].map((s) {
              return ActionChip(
                label: Text(s),
                onPressed: () => setState(() => _objective.text = s),
              );
            }).toList(),
          ),
        ],
      );

  // ---- step 3 -------------------------------------------------------------

  Widget _stepGoal() {
    const categories = [
      ('health', 'Health', Icons.favorite_rounded),
      ('learning', 'Learning', Icons.school_rounded),
      ('career', 'Career', Icons.work_rounded),
      ('personal', 'Personal', Icons.self_improvement_rounded),
      ('finance', 'Finance', Icons.savings_rounded),
      ('relationships', 'People', Icons.people_rounded),
      ('productivity', 'Focus', Icons.bolt_rounded),
      ('custom', 'Custom', Icons.add_rounded),
    ];

    return _page(
      title: 'Your first goal',
      subtitle: 'We will break it into milestones and actions for you.',
      children: [
        AppField(
          label: 'Goal',
          controller: _goalTitle,
          hint: 'e.g. Exercise 4 times a week',
        ),
        AppField(
          label: 'Why it matters (optional)',
          controller: _goalWhy,
          hint: 'The reason you will come back to on a hard day',
          maxLines: 2,
        ),
        Text('Category', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: Gap.md),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: categories.map((c) {
            final selected = _category == c.$1;
            final color = AppColors.forCategory(c.$1);
            return GestureDetector(
              onTap: () => setState(() => _category = c.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
                decoration: BoxDecoration(
                  color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? color
                        : Theme.of(context).dividerTheme.color ?? AppColors.border,
                    width: selected ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(c.$3, size: 17, color: selected ? color : null),
                    const SizedBox(width: 7),
                    Text(
                      c.$2,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: selected ? color : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (_category == 'custom') ...[
          const SizedBox(height: Gap.lg),
          AppField(
            label: 'Name your category',
            controller: _customCategory,
            hint: 'e.g. Music',
          ),
        ],
        const SizedBox(height: Gap.xl),
        Text('Target date', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: Gap.md),
        AppCard(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _targetDate,
              firstDate: DateTime.now().add(const Duration(days: 7)),
              lastDate: DateTime.now().add(const Duration(days: 730)),
            );
            if (picked != null) setState(() => _targetDate = picked);
          },
          child: Row(
            children: [
              const Icon(Icons.event_rounded, size: 20),
              const SizedBox(width: Gap.md),
              Text(DateFormat('d MMMM yyyy').format(_targetDate)),
              const Spacer(),
              Text(
                '${_targetDate.difference(DateTime.now()).inDays} days',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- step 4 -------------------------------------------------------------

  Widget _stepRoutine() => _page(
        title: 'When do you work best?',
        subtitle: 'Your schedule shapes every action the app plans for you.',
        children: [
          Text('Days that suit you', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: Gap.md),
          DayPicker(selected: _days, onChanged: (d) => setState(() => _days = d)),
          const SizedBox(height: Gap.xxl),
          Text('Time of day', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              ('morning', 'Morning', '7 AM'),
              ('afternoon', 'Afternoon', '1 PM'),
              ('evening', 'Evening', '7 PM'),
              ('night', 'Night', '9 PM'),
            ].map((t) {
              final selected = _timeOfDay == t.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _timeOfDay = t.$1;
                      _startTime = switch (t.$1) {
                        'morning' => const TimeOfDay(hour: 7, minute: 0),
                        'afternoon' => const TimeOfDay(hour: 13, minute: 0),
                        'evening' => const TimeOfDay(hour: 19, minute: 0),
                        _ => const TimeOfDay(hour: 21, minute: 30),
                      };
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: Gap.md),
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).dividerTheme.color ?? AppColors.border,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            t.$2,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t.$3,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: selected
                                  ? Colors.white70
                                  : Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
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
                const Text('Start time'),
                const Spacer(),
                Text(
                  _startTime.format(context),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.xl),
          Text('Session length', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: Gap.sm),
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
                width: 62,
                child: Text('$_duration min',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ],
          ),
        ],
      );

  // ---- step 5 -------------------------------------------------------------

  Widget _stepStyle() => _page(
        title: 'How should progress feel?',
        subtitle: 'You can change any of this later in Settings.',
        children: [
          ...[
            ('percentage', 'Percentages', 'Show me exactly how far along I am'),
            ('streak', 'Consistency', 'Show me streaks and how steady I have been'),
            ('minimal', 'Keep it quiet', 'Just today\'s actions, minimal numbers'),
          ].map((s) {
            final selected = _progressStyle == s.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: AppCard(
                onTap: () => setState(() => _progressStyle = s.$1),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected ? Theme.of(context).colorScheme.primary : null,
                      size: 22,
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.$2, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(s.$3, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: Gap.lg),
          Text('Weekly target', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _weeklyTarget.toDouble(),
                  min: 1,
                  max: 14,
                  divisions: 13,
                  label: '$_weeklyTarget actions',
                  onChanged: (v) => setState(() => _weeklyTarget = v.round()),
                ),
              ),
              SizedBox(
                width: 62,
                child: Text('$_weeklyTarget/wk',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: Gap.xl),
          AppField(
            label: 'Anything we should work around? (optional)',
            controller: _constraint,
            hint: 'e.g. No sessions on Saturday mornings',
            maxLines: 2,
          ),
        ],
      );
}
