import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/common.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final consistency = ref.watch(dashboardProvider).valueOrNull?.consistency;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('You'),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xxl),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                backgroundImage:
                    user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                child: user.avatarUrl == null
                    ? Text(
                        user.initials,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: Gap.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    Text(user.email, style: theme.textTheme.bodySmall),
                    if (!user.emailVerified) ...[
                      const SizedBox(height: 4),
                      Text('Email not verified',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.orange)),
                    ],
                  ],
                ),
              ),
            ],
          ),

          if (user.mainObjective != null && user.mainObjective!.isNotEmpty) ...[
            const SizedBox(height: Gap.xl),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Working toward', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Text(user.mainObjective!, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ],

          if (consistency != null) ...[
            const SizedBox(height: Gap.lg),
            AppCard(
              padding: const EdgeInsets.all(Gap.xl),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatTile(
                      value: '${consistency.currentStreak}', label: 'Current streak'),
                  StatTile(
                      value: '${consistency.longestStreak}', label: 'Longest streak'),
                  StatTile(value: '${consistency.monthPercent}%', label: 'Last 30 days'),
                ],
              ),
            ),
          ],

          const SizedBox(height: Gap.xl),
          const SectionHeader('Your routine'),
          AppCard(
            child: Column(
              children: [
                _Row(
                  icon: Icons.calendar_today_outlined,
                  label: 'Preferred days',
                  value: _days(user.preferences.preferredDays),
                ),
                const Divider(height: Gap.xl),
                _Row(
                  icon: Icons.schedule_outlined,
                  label: 'Preferred time',
                  value:
                      '${user.preferences.preferredTimeOfDay[0].toUpperCase()}${user.preferences.preferredTimeOfDay.substring(1)} · ${user.preferences.preferredStartTime}',
                ),
                const Divider(height: Gap.xl),
                _Row(
                  icon: Icons.timer_outlined,
                  label: 'Session length',
                  value: '${user.preferences.defaultSessionMinutes} min',
                ),
                const Divider(height: Gap.xl),
                _Row(
                  icon: Icons.flag_outlined,
                  label: 'Weekly target',
                  value: '${user.preferences.weeklyTargetActions} actions',
                ),
              ],
            ),
          ),

          if (user.preferences.constraints.isNotEmpty) ...[
            const SizedBox(height: Gap.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Things we work around', style: theme.textTheme.bodySmall),
                  const SizedBox(height: Gap.sm),
                  ...user.preferences.constraints.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.block_outlined, size: 15),
                          const SizedBox(width: Gap.sm),
                          Expanded(child: Text(c, style: theme.textTheme.bodyMedium)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: Gap.xl),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Link(
                  icon: Icons.tune_rounded,
                  label: 'Settings & preferences',
                  onTap: () => context.push('/settings'),
                ),
                const Divider(height: 1),
                _Link(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notification preferences',
                  onTap: () => context.push('/settings/notifications'),
                ),
                const Divider(height: 1),
                _Link(
                  icon: Icons.auto_stories_outlined,
                  label: 'Weekly reflection',
                  onTap: () => context.push('/reflection'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _days(List<int> days) {
    if (days.isEmpty) return 'Not set';
    if (days.length == 7) return 'Every day';
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return (days.toList()..sort()).map((d) => names[d]).join(', ');
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});
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

class _Link extends StatelessWidget {
  const _Link({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, size: 21),
        title: Text(label, style: Theme.of(context).textTheme.bodyLarge),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}
