import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../application/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/common.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(appRepositoryProvider).markAllRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(dashboardProvider);
            },
            child: const Text('Mark all read'),
          ),
          IconButton(
            onPressed: () => context.push('/settings/notifications'),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Gap.page),
          child: LoadingList(count: 5, height: 70),
        ),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (result) {
          final items = result.$1;
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Nothing yet',
              message:
                  'Reminders, milestones and your weekly review will land here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.xxl),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: Gap.sm),
              itemBuilder: (_, i) {
                final n = items[i];
                final (icon, color) = switch (n.type) {
                  'action_reminder' => (Icons.alarm_rounded, AppColors.primary),
                  'milestone' => (Icons.emoji_events_outlined, AppColors.completed),
                  'weekly_digest' => (Icons.auto_stories_outlined, AppColors.ahead),
                  'daily_summary' => (Icons.today_rounded, AppColors.onTrack),
                  _ => (Icons.info_outline_rounded, AppColors.muted),
                };
                return AppCard(
                  onTap: () async {
                    await ref.read(appRepositoryProvider).markAllRead();
                    ref.invalidate(notificationsProvider);
                    if (n.type == 'weekly_digest' && context.mounted) {
                      context.push('/reflection');
                    }
                  },
                  padding: const EdgeInsets.symmetric(
                      horizontal: Gap.lg, vertical: Gap.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(icon, size: 18, color: color),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(n.title,
                                      style: theme.textTheme.titleMedium),
                                ),
                                if (!n.read)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        shape: BoxShape.circle),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(n.body, style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 5),
                            Text(_relative(n.createdAt),
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  static String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(d);
  }
}
