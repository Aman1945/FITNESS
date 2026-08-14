import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../application/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/action_item.dart';
import '../../data/models/dashboard.dart';
import '../widgets/common.dart';
import '../widgets/goal_widgets.dart';

/// Answers one question above the fold: "what should I focus on today?"
/// Everything else is secondary and lives below.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);
    final user = ref.watch(currentUserProvider);
    final d = async.valueOrNull;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardProvider),
        child: CustomScrollView(
          slivers: [
            // Pinned so "who am I and what is left today" never scrolls away.
            // It shrinks into a compact bar instead of disappearing.
            SliverPersistentHeader(
              pinned: true,
              delegate: HomeHeaderDelegate(
                // Falls back to a locally computed greeting so the header is
                // never blank while the dashboard request is in flight.
                title: d?.greeting.title ?? _localGreeting(user?.firstName),
                subtitle: d?.greeting.subtitle ?? 'Getting your day ready...',
                avatarUrl: user?.avatarUrl,
                initials: user?.initials ?? '',
                unread: d?.unreadNotifications ?? 0,
                todayRatio: d?.today.ratio ?? 0,
                topPadding: MediaQuery.of(context).padding.top,
              ),
            ),
            ...async.when(
              loading: () => const [
                SliverToBoxAdapter(child: _HomeSkeleton()),
              ],
              error: (e, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(dashboardProvider),
                  ),
                ),
              ],
              data: (d) => [_body(context, d)],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/goals/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New goal'),
      ),
    );
  }

  static String _localGreeting(String? firstName) {
    final h = DateTime.now().hour;
    final part = h < 12
        ? 'Good morning'
        : h < 17
            ? 'Good afternoon'
            : h < 21
                ? 'Good evening'
                : 'Winding down';
    return firstName == null ? part : '$part, $firstName';
  }

  Widget _body(BuildContext context, Dashboard d) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.xxl),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
                _TodayCard(dashboard: d),
                if (d.attention.isNotEmpty) ...[
                  const SizedBox(height: Gap.lg),
                  _AttentionCard(goal: d.attention.first),
                ],
                if (d.weeklyReflectionDue) ...[
                  const SizedBox(height: Gap.lg),
                  _ReflectionPrompt(),
                ],
                const SizedBox(height: Gap.xl),
                ConsistencyStrip(consistency: d.consistency),
                const SizedBox(height: Gap.xl),
                SectionHeader(
                  'Your goals',
                  action: 'See all',
                  onAction: () => context.go('/goals'),
                ),
                if (d.goals.isEmpty)
                  AppCard(
                    onTap: () => context.push('/goals/new'),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Text('Create your first goal',
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                      ],
                    ),
                  )
                else
                  ...d.goals.take(3).map(
                        (g) => Padding(
                          padding: const EdgeInsets.only(bottom: Gap.md),
                          child: GoalCard(
                            goal: g,
                            onTap: () => context.push('/goals/${g.id}'),
                          ),
                        ),
                      ),
                if (d.milestones.isNotEmpty) ...[
                  const SizedBox(height: Gap.sm),
                  const SectionHeader('Next milestone'),
                  AppCard(
                    onTap: () => context.push('/goals/${d.milestones.first.goalId}'),
                    child: Row(
                      children: [
                        Icon(Icons.flag_outlined,
                            size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.milestones.first.title,
                                  style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 3),
                              Text(
                                '${d.milestones.first.progressPercent}% complete'
                                '${d.milestones.first.goalTitle != null ? ' · ${d.milestones.first.goalTitle}' : ''}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (d.upcoming.isNotEmpty) ...[
                  const SizedBox(height: Gap.xl),
                  const SectionHeader('Coming up'),
                  ...d.upcoming.take(3).map(
                        (o) => Padding(
                          padding: const EdgeInsets.only(bottom: Gap.sm),
                          child: _UpcomingRow(occurrence: o),
                        ),
                      ),
                ],
        ]),
      ),
    );
  }
}

/// Pinned home header that collapses instead of scrolling away.
///
/// Expanded  : big two-line greeting + bell + avatar.
/// Collapsed : one compact line, subtitle folded away, a hairline rule and a
///             thin today-progress bar appear so the answer to "what is left
///             today" stays on screen no matter how far you scroll.
class HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  HomeHeaderDelegate({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.initials,
    required this.unread,
    required this.todayRatio,
    required this.topPadding,
  });

  final String title;
  final String subtitle;
  final String? avatarUrl;
  final String initials;
  final int unread;
  final double todayRatio;
  final double topPadding;

  static const _expandedContent = 92.0;
  static const _collapsedContent = 54.0;

  @override
  double get maxExtent => topPadding + _expandedContent;

  @override
  double get minExtent => topPadding + _collapsedContent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    // t: 1 = fully expanded, 0 = fully collapsed.
    final t = 1 - (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              // 26 expanded -> 18.5 collapsed
                              fontSize: 18.5 + 7.5 * t,
                            ),
                          ),
                          // Align + ClipRect folds the subtitle away smoothly
                          // instead of letting it overflow as the bar shrinks.
                          ClipRect(
                            child: Align(
                              alignment: Alignment.topLeft,
                              heightFactor: t,
                              child: Opacity(
                                opacity: t,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    _BellButton(unread: unread),
                    const SizedBox(width: 2),
                    _AvatarButton(
                      avatarUrl: avatarUrl,
                      initials: initials,
                      // Shrinks slightly with the bar, stays an easy tap target.
                      radius: 18 + 3 * t,
                    ),
                  ],
                ),
              ),
            ),
            // Separation appears only once content is scrolling underneath.
            Opacity(
              opacity: 1 - t,
              child: Column(
                children: [
                  if (todayRatio > 0)
                    LinearProgressIndicator(
                      value: todayRatio,
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                    ),
                  Container(height: 1, color: theme.dividerTheme.color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(HomeHeaderDelegate old) =>
      old.title != title ||
      old.subtitle != subtitle ||
      old.avatarUrl != avatarUrl ||
      old.initials != initials ||
      old.unread != unread ||
      old.todayRatio != todayRatio ||
      old.topPadding != topPadding;
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications_none_rounded, size: 23),
          tooltip: 'Notifications',
        ),
        if (unread > 0)
          Positioned(
            right: 9,
            top: 9,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
              decoration: BoxDecoration(
                color: AppColors.behind,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
              ),
              child: Center(
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({
    required this.avatarUrl,
    required this.initials,
    required this.radius,
  });

  final String? avatarUrl;
  final String initials;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.go('/profile'),
      child: Container(
        // Keeps a 44pt tap target even when the avatar shrinks.
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        alignment: Alignment.center,
        child: CircleAvatar(
          radius: radius,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
          child: avatarUrl == null
              ? Text(
                  initials,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: radius * 0.66,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// The single most important card on the app.
class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = dashboard.today;
    final open = today.actions.where((a) => a.isOpen).toList();

    return AppCard(
      padding: const EdgeInsets.all(Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 3),
                    Text(
                      today.planned == 0
                          ? 'Nothing scheduled'
                          : '${today.completed} of ${today.planned} done · ${today.minutesPlanned} min planned',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              ProgressRing(value: today.ratio, size: 52, stroke: 6),
            ],
          ),
          if (dashboard.greeting.nudge != null) ...[
            const SizedBox(height: Gap.md),
            Container(
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(
                color: AppColors.needsAttention.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Gap.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      size: 17, color: AppColors.needsAttention),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      dashboard.greeting.nudge!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.needsAttention),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Gap.lg),
          if (today.planned == 0)
            Text(
              'Your schedule is clear. Add an action to a goal, or enjoy the break.',
              style: theme.textTheme.bodyMedium,
            )
          else if (open.isEmpty)
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.onTrack, size: 20),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text('Everything done for today. Well played.',
                      style: theme.textTheme.bodyLarge),
                ),
              ],
            )
          else
            ...open.take(3).map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: _QuickAction(occurrence: o),
                  ),
                ),
          if (today.carriedOver.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            Text(
              '${today.carriedOver.length} missed yesterday - catch up if you can',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.needsAttention),
            ),
          ],
          const SizedBox(height: Gap.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push('/today'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              child: Text(today.planned == 0 ? 'View schedule' : "See today's plan"),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends ConsumerWidget {
  const _QuickAction({required this.occurrence});

  final Occurrence occurrence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Row(
      children: [
        GestureDetector(
          onTap: () async {
            HapticFeedback.lightImpact();
            await ref.read(occurrenceActionsProvider).complete(occurrence.id);
            if (context.mounted) showSnack(context, 'Nice - "${occurrence.title}" done');
          },
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.dividerTheme.color!, width: 2),
            ),
          ),
        ),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Text(
            occurrence.title,
            style: theme.textTheme.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          DateFormat.jm().format(occurrence.scheduledAt),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.goal});
  final AttentionGoal goal;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/goals/${goal.id}'),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.needsAttention.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.trending_down_rounded,
                size: 19, color: AppColors.needsAttention),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(goal.reason,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReflectionPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AppCard(
      onTap: () => context.push('/reflection'),
      child: Row(
        children: [
          Icon(Icons.auto_stories_outlined, color: primary, size: 21),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your week is ready to review',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('Two minutes, and next week gets easier.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: primary),
        ],
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.occurrence});
  final Occurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 30,
            decoration: BoxDecoration(
              color: occurrenceColor(occurrence),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(occurrence.title,
                    style: theme.textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  DateFormat('EEE, d MMM · ').add_jm().format(occurrence.scheduledAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  // A Column, not a ListView: this now lives inside a sliver, where an
  // unbounded scrollable would fail to lay out. The header is real while this
  // shows, so there is no placeholder for it.
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.xxl),
        child: Column(
          children: [
            SkeletonBox(height: 210),
            SizedBox(height: Gap.lg),
            SkeletonBox(height: 110),
            SizedBox(height: Gap.lg),
            LoadingList(count: 2, height: 104),
          ],
        ),
      );
}
