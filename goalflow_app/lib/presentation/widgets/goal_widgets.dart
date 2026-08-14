import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/action_item.dart';
import '../../data/models/dashboard.dart';
import '../../data/models/goal.dart';
import 'common.dart';

/// Parses a stored hex colour, falling back to the category colour.
///
/// Never throws: a malformed, empty or legacy colour value must not be able to
/// crash a screen, so anything unparseable silently uses the category default.
Color? _parseHex(String? hex) {
  if (hex == null) return null;
  var value = hex.trim().replaceFirst('#', '');
  if (value.isEmpty) return null;

  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return null;

  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
}

Color goalColor(Goal g) =>
    _parseHex(g.color) ?? AppColors.forCategory(g.category);

Color occurrenceColor(Occurrence o) =>
    _parseHex(o.goalColor) ?? AppColors.forCategory(o.goalCategory ?? 'personal');

/// Goal card: ring + status + the reason sentence. Used on Home and Goals.
class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal, this.onTap, this.showReason = true});

  final Goal goal;
  final VoidCallback? onTap;
  final bool showReason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = goalColor(goal);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProgressRing(
                value: goal.progressPercent / 100,
                size: 54,
                stroke: 6,
                color: color,
              ),
              const SizedBox(width: Gap.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _Tag(goal.displayCategory, color),
                        const SizedBox(width: Gap.sm),
                        Flexible(
                          child: Text(
                            goal.status == 'paused'
                                ? 'Paused'
                                : '${goal.daysRemaining} days left',
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StatusChip(
                goal.status == 'paused' ? 'paused' : goal.computedStatus,
                compact: true,
              ),
            ],
          ),
          if (showReason && goal.statusReason.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            Text(
              goal.statusReason,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label[0].toUpperCase() + label.substring(1),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      );
}

/// A single dated action the user can tick off.
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.occurrence,
    this.onComplete,
    this.onSkip,
    this.onUndo,
    this.onTap,
    this.showTime = true,
  });

  final Occurrence occurrence;
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;
  final VoidCallback? onUndo;
  final VoidCallback? onTap;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final o = occurrence;
    final color = occurrenceColor(o);
    final done = o.isCompleted;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Row(
        children: [
          _CheckCircle(
            done: done,
            missed: o.isMissed,
            skipped: o.isSkipped,
            color: color,
            onTap: done || o.isSkipped ? onUndo : onComplete,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done || o.isSkipped
                        ? theme.textTheme.bodyMedium?.color
                        : theme.textTheme.bodyLarge?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (o.goalTitle != null) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          o.goalTitle!,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                    ],
                    Text(
                      showTime
                          ? '${DateFormat.jm().format(o.scheduledAt)} · ${o.estimatedMinutes}m'
                          : '${o.estimatedMinutes}m',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (o.isOpen && onSkip != null)
            IconButton(
              onPressed: onSkip,
              icon: const Icon(Icons.more_horiz_rounded, size: 20),
              color: theme.textTheme.bodySmall?.color,
              visualDensity: VisualDensity.compact,
            ),
          if (o.isMissed)
            Text('Missed',
                style: TextStyle(
                    color: AppColors.behind, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({
    required this.done,
    required this.missed,
    required this.skipped,
    required this.color,
    this.onTap,
  });

  final bool done;
  final bool missed;
  final bool skipped;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerTheme.color ?? AppColors.border;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: done ? color : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: done
                ? color
                : missed
                    ? AppColors.behind.withValues(alpha: 0.5)
                    : border,
            width: 2,
          ),
        ),
        child: done
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : skipped
                ? Icon(Icons.remove_rounded, size: 14, color: border)
                : null,
      ),
    );
  }
}

/// Seven dots representing the last week. Rest days are hollow, not red --
/// a day with nothing planned is not a failure.
class ConsistencyStrip extends StatelessWidget {
  const ConsistencyStrip({super.key, required this.consistency});

  final Consistency consistency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.dividerTheme.color ?? AppColors.border;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department_rounded,
                  size: 19, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                consistency.currentStreak == 0
                    ? 'Start your streak'
                    : '${consistency.currentStreak} day streak',
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                '${consistency.weekCompleted}/${consistency.weekPlanned} this week',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: consistency.last7.map((d) {
              final (bg, fg) = switch (d.state) {
                'done' => (AppColors.onTrack, Colors.white),
                'missed' => (AppColors.behind.withValues(alpha: 0.15), AppColors.behind),
                'today' => (theme.colorScheme.primary.withValues(alpha: 0.15),
                    theme.colorScheme.primary),
                _ => (Colors.transparent, theme.textTheme.bodySmall?.color ?? border),
              };
              return Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                      border: d.state == 'rest' ? Border.all(color: border) : null,
                    ),
                    child: Center(
                      child: d.state == 'done'
                          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                          : Text(
                              d.label,
                              style: TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.w600, color: fg),
                            ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Day-of-week multi-select used by onboarding, create-goal and create-action.
class DayPicker extends StatelessWidget {
  const DayPicker({super.key, required this.selected, required this.onChanged});

  final List<int> selected;
  final ValueChanged<List<int>> onChanged;

  static const _labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _full = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final active = selected.contains(i);
        return Tooltip(
          message: _full[i],
          child: GestureDetector(
            onTap: () {
              final next = [...selected];
              active ? next.remove(i) : next.add(i);
              next.sort();
              onChanged(next);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: active ? theme.colorScheme.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active
                      ? theme.colorScheme.primary
                      : theme.dividerTheme.color ?? AppColors.border,
                  width: 1.4,
                ),
              ),
              child: Center(
                child: Text(
                  _labels[i],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: active
                        ? Colors.white
                        : theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
