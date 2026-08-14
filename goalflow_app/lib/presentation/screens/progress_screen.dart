import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/progress.dart';
import '../widgets/common.dart';
import '../widgets/goal_widgets.dart';

/// Long-term view. Charts appear only where they explain something a number
/// cannot -- the weekly trend and where the time actually went.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(progressProvider);
    final range = ref.watch(progressRangeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            onPressed: () => context.push('/reflection'),
            icon: const Icon(Icons.auto_stories_outlined),
            tooltip: 'Weekly reflection',
          ),
        ],
      ),
      body: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Gap.page),
          child: Column(
            children: [
              SkeletonBox(height: 120),
              SizedBox(height: Gap.lg),
              SkeletonBox(height: 220),
              SizedBox(height: Gap.lg),
              LoadingList(count: 2),
            ],
          ),
        ),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(progressProvider),
        ),
        data: (p) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(progressProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xxl),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'week', label: Text('4 weeks')),
                  ButtonSegment(value: 'month', label: Text('8 weeks')),
                  ButtonSegment(value: 'quarter', label: Text('12 weeks')),
                ],
                selected: {range},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    ref.read(progressRangeProvider.notifier).state = s.first,
              ),
              const SizedBox(height: Gap.xl),

              AppCard(
                padding: const EdgeInsets.all(Gap.xl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StatTile(
                        value: '${p.completed}',
                        label: 'Completed',
                        color: AppColors.onTrack),
                    StatTile(
                        value: '${p.missed}',
                        label: 'Missed',
                        color: p.missed > 0 ? AppColors.behind : null),
                    StatTile(
                        value: '${p.consistency.currentStreak}', label: 'Day streak'),
                    StatTile(
                        value: '${(p.minutes / 60).round()}h', label: 'Time invested'),
                  ],
                ),
              ),

              const SizedBox(height: Gap.xl),
              const SectionHeader('Week by week'),
              AppCard(
                padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xl, Gap.lg, Gap.md),
                child: SizedBox(height: 190, child: _TrendChart(trend: p.trend)),
              ),

              const SizedBox(height: Gap.xl),
              ConsistencyStrip(consistency: p.consistency),

              if (p.byCategory.isNotEmpty) ...[
                const SizedBox(height: Gap.xl),
                const SectionHeader('Where your time goes'),
                AppCard(
                  child: Column(
                    children: p.byCategory.map((c) {
                      final maxV = p.byCategory
                          .map((e) => e.completed)
                          .reduce((a, b) => a > b ? a : b);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${c.category[0].toUpperCase()}${c.category.substring(1)}',
                                  style: theme.textTheme.bodyLarge,
                                ),
                                const Spacer(),
                                Text(
                                  '${c.completed} actions · ${(c.minutes / 60).round()}h',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            AppProgressBar(
                              value: maxV == 0 ? 0 : c.completed / maxV,
                              color: AppColors.forCategory(c.category),
                              height: 6,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              const SizedBox(height: Gap.xl),
              const SectionHeader('Goal status'),
              if (p.goals.isEmpty)
                const EmptyState(
                  icon: Icons.insights_outlined,
                  title: 'No active goals',
                  message: 'Create a goal and progress will show up here.',
                )
              else
                ...p.goals.map(
                  (g) => Padding(
                    padding: const EdgeInsets.only(bottom: Gap.md),
                    child: GoalCard(
                      goal: g,
                      onTap: () => context.push('/goals/${g.id}'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.trend});

  final List<WeekPoint> trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (trend.isEmpty) return const SizedBox.shrink();

    final maxY = trend
        .map((t) => t.planned > t.completed ? t.planned : t.completed)
        .fold<int>(4, (a, b) => a > b ? a : b)
        .toDouble();

    return BarChart(
      BarChartData(
        maxY: maxY * 1.15,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => theme.colorScheme.onSurface,
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${rod.toY.round()} of ${trend[group.x].planned}',
              TextStyle(color: theme.colorScheme.surface, fontSize: 12),
            ),
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: (maxY / 3).ceilToDouble(),
          getDrawingHorizontalLine: (_) =>
              FlLine(color: theme.dividerTheme.color!, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (maxY / 3).ceilToDouble(),
              getTitlesWidget: (v, _) => Text(
                v.round().toString(),
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                // Thin the labels so a 12-week range stays readable.
                if (trend.length > 6 && i % 2 != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    trend[i].label,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < trend.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: trend[i].completed.toDouble(),
                  width: trend.length > 8 ? 9 : 14,
                  borderRadius: BorderRadius.circular(5),
                  color: theme.colorScheme.primary,
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: trend[i].planned.toDouble(),
                    color: theme.colorScheme.primary.withValues(alpha: 0.13),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
