import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../application/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/goal.dart';
import '../widgets/common.dart';
import '../widgets/goal_widgets.dart';

/// The hierarchy Goal -> Milestone -> Action is made literal here: each
/// milestone is a collapsible group with its actions nested inside it.
class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(goalDetailProvider(goalId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal'),
        actions: [
          async.maybeWhen(
            data: (detail) => PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) => _handleMenu(context, ref, v, detail.goal),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit goal')),
                PopupMenuItem(
                  value: detail.goal.status == 'paused' ? 'resume' : 'pause',
                  child: Text(detail.goal.status == 'paused'
                      ? 'Resume goal'
                      : 'Pause goal'),
                ),
                const PopupMenuItem(value: 'complete', child: Text('Mark complete')),
                const PopupMenuItem(value: 'archive', child: Text('Archive')),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Gap.page),
          child: LoadingList(count: 4, height: 100),
        ),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(goalDetailProvider(goalId)),
        ),
        data: (detail) => _Body(detail: detail),
      ),
      floatingActionButton: async.maybeWhen(
        data: (_) => FloatingActionButton.extended(
          onPressed: () => _showAddSheet(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add'),
        ),
        orElse: () => null,
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Gap.lg),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('New milestone'),
              subtitle: const Text('A checkpoint on the way to the goal'),
              onTap: () {
                Navigator.pop(sheet);
                context.push('/goals/$goalId/milestones/new');
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline_rounded),
              title: const Text('New action'),
              subtitle: const Text('Something you actually do, on a schedule'),
              onTap: () {
                Navigator.pop(sheet);
                context.push('/goals/$goalId/actions/new');
              },
            ),
            const SizedBox(height: Gap.md),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMenu(
      BuildContext context, WidgetRef ref, String value, Goal goal) async {
    final repo = ref.read(goalRepositoryProvider);
    try {
      switch (value) {
        case 'edit':
          context.push('/goals/${goal.id}/edit');
          return;
        case 'pause':
          await repo.setLifecycle(goal.id, 'pause');
        case 'resume':
          await repo.setLifecycle(goal.id, 'resume');
        case 'complete':
          await repo.setLifecycle(goal.id, 'complete');
        case 'archive':
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Archive this goal?'),
              content: const Text(
                'Your history is kept. The goal stops appearing in your plan.',
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Archive')),
              ],
            ),
          );
          if (confirmed != true) return;
          await repo.archive(goal.id);
          if (context.mounted) context.pop();
      }
      ref.invalidate(goalDetailProvider(goal.id));
      invalidateProgressData(ref);
      if (context.mounted) showSnack(context, 'Goal updated');
    } catch (e) {
      if (context.mounted) showSnack(context, e.toString(), error: true);
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});

  final GoalDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final goal = detail.goal;
    final ev = detail.evaluation;
    final color = goalColor(goal);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(goalDetailProvider(goal.id)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, 96),
        children: [
          Text(goal.title, style: theme.textTheme.headlineMedium),
          if (goal.why != null && goal.why!.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            Text('"${goal.why}"',
                style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: Gap.lg),

          // Status is always paired with its reason -- a chip alone explains nothing.
          AppCard(
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(
              children: [
                Row(
                  children: [
                    ProgressRing(value: ev.progressPercent / 100, size: 72, color: color),
                    const SizedBox(width: Gap.xl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusChip(goal.status == 'paused'
                              ? 'paused'
                              : ev.status),
                          const SizedBox(height: Gap.sm),
                          Text(ev.reason, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StatTile(value: '${ev.completed}', label: 'Completed'),
                    StatTile(
                        value: '${ev.missed}',
                        label: 'Missed',
                        color: ev.missed > 0 ? AppColors.behind : null),
                    StatTile(value: '${ev.daysRemaining}', label: 'Days left'),
                    StatTile(
                        value: '${(ev.adherence * 100).round()}%', label: 'Adherence'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: Gap.lg),
          AppCard(
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.repeat_rounded,
                  label: 'Routine',
                  value: goal.routine.summary,
                ),
                const Divider(height: Gap.xl),
                _InfoRow(
                  icon: Icons.event_rounded,
                  label: 'Target date',
                  value: DateFormat('d MMM yyyy').format(goal.targetDate),
                ),
                const Divider(height: Gap.xl),
                _InfoRow(
                  icon: Icons.category_outlined,
                  label: 'Category',
                  value:
                      '${goal.displayCategory[0].toUpperCase()}${goal.displayCategory.substring(1)} · ${goal.priority} priority',
                ),
              ],
            ),
          ),

          if (goal.description != null && goal.description!.isNotEmpty) ...[
            const SizedBox(height: Gap.xl),
            const SectionHeader('About this goal'),
            Text(goal.description!, style: theme.textTheme.bodyLarge),
          ],

          const SizedBox(height: Gap.xl),
          SectionHeader(
            'Milestones',
            action: 'Add',
            onAction: () => context.push('/goals/${goal.id}/milestones/new'),
          ),
          if (detail.milestones.isEmpty)
            AppCard(
              onTap: () => context.push('/goals/${goal.id}/milestones/new'),
              child: Row(
                children: [
                  Icon(Icons.add_rounded, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Text(
                      'Break this goal into checkpoints',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            )
          else
            ...detail.milestones.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: Gap.md),
                  child: _MilestoneGroup(milestone: m, goalId: goal.id, color: color),
                )),

          if (detail.standaloneActions.isNotEmpty) ...[
            const SizedBox(height: Gap.lg),
            const SectionHeader('Other actions'),
            ...detail.standaloneActions.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Gap.lg, vertical: Gap.md),
                  child: Row(
                    children: [
                      Expanded(child: Text(a.title, style: theme.textTheme.bodyLarge)),
                      Text('${a.estimatedMinutes}m', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
          ],

          if (detail.history.isNotEmpty) ...[
            const SizedBox(height: Gap.xl),
            const SectionHeader('Recent history'),
            AppCard(
              child: Column(
                children: detail.history.take(8).map((o) {
                  final icon = o.isCompleted
                      ? Icons.check_circle_rounded
                      : o.isSkipped
                          ? Icons.remove_circle_outline_rounded
                          : Icons.cancel_outlined;
                  final c = o.isCompleted
                      ? AppColors.onTrack
                      : o.isSkipped
                          ? AppColors.muted
                          : AppColors.behind;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(icon, size: 17, color: c),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Text(o.title,
                              style: theme.textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text(DateFormat('d MMM').format(o.scheduledDate),
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 19, color: Theme.of(context).textTheme.bodySmall?.color),
          const SizedBox(width: Gap.md),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}

class _MilestoneGroup extends ConsumerWidget {
  const _MilestoneGroup({
    required this.milestone,
    required this.goalId,
    required this.color,
  });

  final Milestone milestone;
  final String goalId;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.sm, Gap.md),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: Gap.sm, right: Gap.sm),
          initiallyExpanded: !milestone.isCompleted,
          title: Row(
            children: [
              Icon(
                milestone.isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: milestone.isCompleted ? AppColors.onTrack : color,
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(milestone.title, style: theme.textTheme.titleMedium),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(left: 32, top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppProgressBar(
                  value: milestone.progressPercent / 100,
                  color: color,
                  height: 5,
                ),
                const SizedBox(height: 6),
                Text(
                  '${milestone.progressPercent}% · ${milestone.actions.length} action${milestone.actions.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          children: [
            ...milestone.actions.map(
              (a) => Padding(
                padding: const EdgeInsets.only(left: 32, bottom: Gap.sm),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Text(a.title, style: theme.textTheme.bodyLarge),
                    ),
                    Text('${a.estimatedMinutes}m', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => context
                        .push('/goals/$goalId/actions/new?milestone=${milestone.id}'),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add action'),
                  ),
                  if (!milestone.isCompleted)
                    TextButton(
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        await ref
                            .read(goalRepositoryProvider)
                            .completeMilestone(milestone.id);
                        ref.invalidate(goalDetailProvider(goalId));
                        invalidateProgressData(ref);
                        if (context.mounted) {
                          showSnack(context, 'Milestone reached');
                        }
                      },
                      child: const Text('Mark reached'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
