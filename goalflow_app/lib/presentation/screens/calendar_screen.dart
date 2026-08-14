import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../application/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/action_item.dart';
import '../widgets/common.dart';
import '../widgets/goal_widgets.dart';

/// A personal goal schedule -- not a calendar replacement.
/// Each day carries up to three dots showing completed / missed / planned.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(calendarProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Gap.page),
          child: Column(
            children: [SkeletonBox(height: 320), SizedBox(height: Gap.lg), LoadingList()],
          ),
        ),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(calendarProvider),
        ),
        data: (items) {
          final byDay = <String, List<Occurrence>>{};
          for (final o in items) {
            final key = DateFormat('yyyy-MM-dd').format(o.scheduledDate);
            byDay.putIfAbsent(key, () => []).add(o);
          }
          List<Occurrence> forDay(DateTime d) =>
              byDay[DateFormat('yyyy-MM-dd').format(d)] ?? const [];

          final selectedItems = forDay(_selected);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                  child: TableCalendar<Occurrence>(
                    firstDay: DateTime.now().subtract(const Duration(days: 365)),
                    lastDay: DateTime.now().add(const Duration(days: 365)),
                    focusedDay: _focused,
                    selectedDayPredicate: (d) => _sameDay(d, _selected),
                    calendarFormat: _format,
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Month',
                      CalendarFormat.twoWeeks: '2 weeks',
                    },
                    eventLoader: forDay,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    onFormatChanged: (f) => setState(() => _format = f),
                    onDaySelected: (selected, focused) => setState(() {
                      _selected = selected;
                      _focused = focused;
                    }),
                    onPageChanged: (focused) {
                      _focused = focused;
                      ref.read(calendarMonthProvider.notifier).state =
                          DateTime(focused.year, focused.month);
                    },
                    headerStyle: HeaderStyle(
                      formatButtonVisible: true,
                      titleCentered: false,
                      formatButtonShowsNext: false,
                      titleTextStyle: theme.textTheme.titleLarge!,
                      formatButtonTextStyle:
                          TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                      formatButtonDecoration: BoxDecoration(
                        border: Border.all(color: theme.dividerTheme.color!),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      todayDecoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: TextStyle(color: theme.colorScheme.primary),
                      selectedDecoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      markersMaxCount: 3,
                      markerSize: 5,
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, events) {
                        if (events.isEmpty) return null;
                        // Colour by outcome, so the month reads at a glance.
                        final colors = <Color>{
                          for (final e in events.take(3))
                            e.isCompleted
                                ? AppColors.onTrack
                                : e.isMissed
                                    ? AppColors.behind
                                    : e.isSkipped
                                        ? AppColors.muted
                                        : theme.colorScheme.primary,
                        };
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: colors
                                .map((c) => Container(
                                      width: 5,
                                      height: 5,
                                      margin:
                                          const EdgeInsets.symmetric(horizontal: 1),
                                      decoration: BoxDecoration(
                                          color: c, shape: BoxShape.circle),
                                    ))
                                .toList(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Gap.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                child: Row(
                  children: [
                    Text(
                      _sameDay(_selected, DateTime.now())
                          ? 'Today'
                          : DateFormat('EEEE, d MMM').format(_selected),
                      style: theme.textTheme.titleLarge,
                    ),
                    const Spacer(),
                    Text('${selectedItems.length} planned',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: Gap.md),
              Expanded(
                child: selectedItems.isEmpty
                    ? EmptyState(
                        icon: Icons.event_available_outlined,
                        title: 'Nothing on this day',
                        message: _selected.isAfter(DateTime.now())
                            ? 'No actions are scheduled yet.'
                            : 'This day was clear.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            Gap.page, 0, Gap.page, Gap.xxl),
                        itemCount: selectedItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: Gap.sm),
                        itemBuilder: (_, i) {
                          final o = selectedItems[i];
                          return ActionTile(
                            occurrence: o,
                            onComplete: o.isOpen
                                ? () async {
                                    await ref
                                        .read(occurrenceActionsProvider)
                                        .complete(o.id);
                                    if (context.mounted) {
                                      showSnack(context, 'Done: ${o.title}');
                                    }
                                  }
                                : null,
                            onUndo: () =>
                                ref.read(occurrenceActionsProvider).undo(o.id),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
