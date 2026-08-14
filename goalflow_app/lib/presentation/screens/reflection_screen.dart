import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/progress.dart';
import '../widgets/common.dart';
import '../widgets/goal_widgets.dart';

/// The week, summarised, plus three optional prompts.
/// Writing is never required -- the stats alone are the point, the reflection is
/// a bonus for the user who wants it.
class ReflectionScreen extends ConsumerStatefulWidget {
  const ReflectionScreen({super.key});

  @override
  ConsumerState<ReflectionScreen> createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends ConsumerState<ReflectionScreen> {
  final _wentWell = TextEditingController();
  final _difficult = TextEditingController();
  final _improve = TextEditingController();
  bool _busy = false;
  bool _hydrated = false;

  @override
  void dispose() {
    _wentWell.dispose();
    _difficult.dispose();
    _improve.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(appRepositoryProvider).saveReflection(
            wentWell: _wentWell.text.trim(),
            wasDifficult: _difficult.text.trim(),
            improveNext: _improve.text.trim(),
          );
      ref.invalidate(weeklyReviewProvider);
      if (mounted) showSnack(context, 'Reflection saved');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(weeklyReviewProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('This week')),
      body: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Gap.page),
          child: Column(children: [SkeletonBox(height: 180), SizedBox(height: Gap.lg), LoadingList()]),
        ),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(weeklyReviewProvider),
        ),
        data: (w) {
          if (!_hydrated) {
            _hydrated = true;
            _wentWell.text = w.wentWell ?? '';
            _difficult.text = w.wasDifficult ?? '';
            _improve.text = w.improveNext ?? '';
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xxl),
            children: [
              Text(w.label, style: theme.textTheme.bodyMedium),
              const SizedBox(height: Gap.lg),

              AppCard(
                padding: const EdgeInsets.all(Gap.xl),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ProgressRing(value: w.completionRate / 100, size: 68),
                        const SizedBox(width: Gap.xl),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _headline(w),
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${w.completed} of ${w.planned} planned actions · '
                                '${(w.minutesInvested / 60).floor()}h ${w.minutesInvested % 60}m',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StatTile(
                            value: '${w.completed}',
                            label: 'Completed',
                            color: AppColors.onTrack),
                        StatTile(
                            value: '${w.missed}',
                            label: 'Missed',
                            color: w.missed > 0 ? AppColors.behind : null),
                        StatTile(value: '${w.goalsWorkedOn}', label: 'Goals worked on'),
                      ],
                    ),
                  ],
                ),
              ),

              if (w.strongest != null || w.needsAttention != null) ...[
                const SizedBox(height: Gap.lg),
                Row(
                  children: [
                    if (w.strongest != null)
                      Expanded(
                        child: _Highlight(
                          icon: Icons.trending_up_rounded,
                          color: AppColors.onTrack,
                          label: 'Strongest',
                          value: w.strongest!,
                        ),
                      ),
                    if (w.strongest != null && w.needsAttention != null)
                      const SizedBox(width: Gap.md),
                    if (w.needsAttention != null)
                      Expanded(
                        child: _Highlight(
                          icon: Icons.trending_down_rounded,
                          color: AppColors.needsAttention,
                          label: 'Needs attention',
                          value: w.needsAttention!,
                        ),
                      ),
                  ],
                ),
              ],

              if (w.perGoal.isNotEmpty) ...[
                const SizedBox(height: Gap.xl),
                const SectionHeader('By goal'),
                AppCard(
                  child: Column(
                    children: w.perGoal.map((g) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(g.title,
                                      style: theme.textTheme.bodyLarge,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Text('${g.completed}/${g.planned}',
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                            const SizedBox(height: 7),
                            AppProgressBar(
                              value: g.percent / 100,
                              height: 6,
                              color: g.percent >= 70
                                  ? AppColors.onTrack
                                  : g.percent >= 40
                                      ? AppColors.needsAttention
                                      : AppColors.behind,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              if (w.upcomingPriorities.isNotEmpty) ...[
                const SizedBox(height: Gap.xl),
                const SectionHeader('Coming up next week'),
                ...w.upcomingPriorities.take(4).map(
                      (o) => Padding(
                        padding: const EdgeInsets.only(bottom: Gap.sm),
                        child: ActionTile(occurrence: o, showTime: false),
                      ),
                    ),
              ],

              const SizedBox(height: Gap.xxl),
              Text('Reflect (optional)', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Two minutes here is what makes next week different.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: Gap.lg),
              _Prompt(
                label: 'What went well?',
                controller: _wentWell,
                hint: 'The thing you would repeat',
              ),
              _Prompt(
                label: 'What made things difficult?',
                controller: _difficult,
                hint: 'Be honest, not harsh',
              ),
              _Prompt(
                label: 'What would you like to improve?',
                controller: _improve,
                hint: 'One small change is enough',
              ),
              const SizedBox(height: Gap.sm),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(w.submitted ? 'Update reflection' : 'Save reflection'),
              ),
              if (w.submitted) ...[
                const SizedBox(height: Gap.md),
                Center(
                  child: Text('Saved for ${DateFormat('d MMM').format(DateTime.now())}',
                      style: theme.textTheme.bodySmall),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _headline(WeeklyReview w) {
    if (w.planned == 0) return 'A quiet week';
    if (w.completionRate >= 85) return 'A strong week';
    if (w.completionRate >= 60) return 'A solid week';
    if (w.completionRate >= 35) return 'A mixed week';
    return 'A tough week';
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(value,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.label, required this.controller, required this.hint});

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 7),
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(hintText: hint),
            ),
          ],
        ),
      );
}
