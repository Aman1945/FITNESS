import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/action_item.dart';
import '../widgets/common.dart';
import '../widgets/goal_widgets.dart';

/// The full list for today, grouped by time of day so the plan reads like a day
/// rather than a backlog.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.only(left: Gap.page, bottom: Gap.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormat('EEEE, d MMMM').format(DateTime.now()),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ),
      ),
      body: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Gap.page),
          child: LoadingList(count: 4, height: 68),
        ),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(todayProvider),
        ),
        data: (feed) {
          if (feed.actions.isEmpty && feed.carriedOver.isEmpty) {
            return EmptyState(
              icon: Icons.wb_sunny_outlined,
              title: 'Nothing planned today',
              message:
                  'Either you have earned a rest day, or your goals need an action for today.',
              actionLabel: 'Regenerate schedule',
              onAction: () async {
                await ref.read(appRepositoryProvider).regenerateSchedule();
                invalidateProgressData(ref);
              },
            );
          }

          final groups = _groupByTime(feed.actions);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(todayProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xxl),
              children: [
                _Summary(
                  completed: feed.completed,
                  planned: feed.planned,
                  minutes: feed.minutesPlanned,
                ),
                if (feed.carriedOver.isNotEmpty) ...[
                  const SizedBox(height: Gap.xl),
                  const SectionHeader('Missed yesterday'),
                  ...feed.carriedOver.map(
                    (o) => Padding(
                      padding: const EdgeInsets.only(bottom: Gap.sm),
                      child: ActionTile(
                        occurrence: o,
                        onComplete: () => _complete(context, ref, o),
                        onSkip: () => _showOptions(context, ref, o),
                      ),
                    ),
                  ),
                ],
                for (final entry in groups.entries) ...[
                  const SizedBox(height: Gap.lg),
                  SectionHeader(entry.key),
                  ...entry.value.map(
                    (o) => Padding(
                      padding: const EdgeInsets.only(bottom: Gap.sm),
                      child: ActionTile(
                        occurrence: o,
                        onComplete: () => _complete(context, ref, o),
                        onUndo: () => ref.read(occurrenceActionsProvider).undo(o.id),
                        onSkip: () => _showOptions(context, ref, o),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  static Map<String, List<Occurrence>> _groupByTime(List<Occurrence> items) {
    final groups = <String, List<Occurrence>>{};
    for (final o in items) {
      final h = o.scheduledAt.hour;
      final key = h < 12
          ? 'Morning'
          : h < 17
              ? 'Afternoon'
              : h < 21
                  ? 'Evening'
                  : 'Night';
      groups.putIfAbsent(key, () => []).add(o);
    }
    // Keep a natural chronological order regardless of insertion order.
    const order = ['Morning', 'Afternoon', 'Evening', 'Night'];
    return {
      for (final k in order)
        if (groups.containsKey(k)) k: groups[k]!,
    };
  }

  Future<void> _complete(BuildContext context, WidgetRef ref, Occurrence o) async {
    HapticFeedback.lightImpact();
    await ref.read(occurrenceActionsProvider).complete(o.id);
    if (context.mounted) showSnack(context, 'Done: ${o.title}');
  }

  void _showOptions(BuildContext context, WidgetRef ref, Occurrence o) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Gap.sm),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerTheme.color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: Gap.lg),
            ListTile(
              leading: const Icon(Icons.check_circle_outline_rounded),
              title: const Text('Mark complete'),
              onTap: () {
                Navigator.pop(sheetContext);
                _complete(context, ref, o);
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_repeat_rounded),
              title: const Text('Move to tomorrow'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await ref.read(occurrenceActionsProvider).reschedule(
                      o.id,
                      DateTime.now().add(const Duration(days: 1)),
                    );
                if (context.mounted) showSnack(context, 'Moved to tomorrow');
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline_rounded),
              title: const Text('Skip this one'),
              subtitle: const Text('A deliberate skip does not count against you'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await ref.read(occurrenceActionsProvider).skip(o.id);
                if (context.mounted) showSnack(context, 'Skipped');
              },
            ),
            const SizedBox(height: Gap.md),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.completed,
    required this.planned,
    required this.minutes,
  });

  final int completed;
  final int planned;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final ratio = planned == 0 ? 0.0 : completed / planned;
    return AppCard(
      padding: const EdgeInsets.all(Gap.xl),
      child: Row(
        children: [
          ProgressRing(value: ratio, size: 62),
          const SizedBox(width: Gap.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  completed == planned && planned > 0
                      ? 'All done today'
                      : '${planned - completed} left today',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '$completed of $planned completed · about $minutes min planned',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: Gap.md),
                AppProgressBar(
                  value: ratio,
                  color: ratio >= 1 ? AppColors.onTrack : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
