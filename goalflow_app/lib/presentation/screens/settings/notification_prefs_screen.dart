import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/common.dart';

/// Every switch here writes straight to the backend.
/// The server is the one that decides whether to send, so turning something off
/// really stops the send -- it is not a client-side filter.
class NotificationPrefsScreen extends ConsumerStatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  ConsumerState<NotificationPrefsScreen> createState() =>
      _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState extends ConsumerState<NotificationPrefsScreen> {
  bool _busy = false;

  Future<void> _patch(Map<String, dynamic> body) async {
    setState(() => _busy = true);
    try {
      await ref.read(appRepositoryProvider).updateNotificationPreferences(body);
      ref.invalidate(notificationPrefsProvider);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _pickTime(String current) async {
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 8,
        minute: int.tryParse(parts.last) ?? 0,
      ),
    );
    if (picked == null) return null;
    return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(notificationPrefsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: Gap.lg),
              child: Center(
                child: SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Gap.page),
          child: LoadingList(count: 4, height: 76),
        ),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(notificationPrefsProvider),
        ),
        data: (p) => ListView(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xxl),
          children: [
            const SectionHeader('Channels'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    value: p.pushEnabled,
                    onChanged: (v) => _patch({'pushEnabled': v}),
                    title: const Text('Push notifications'),
                    subtitle: const Text('On this device'),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: p.emailEnabled,
                    onChanged: (v) => _patch({'emailEnabled': v}),
                    title: const Text('Email'),
                    subtitle: const Text('Weekly summary and milestones'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Gap.xl),
            const SectionHeader('What to send'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    value: p.remindersEnabled,
                    onChanged: (v) =>
                        _patch({'actionReminders': {'enabled': v}}),
                    title: const Text('Action reminders'),
                    subtitle: Text('${p.minutesBefore} minutes before each action'),
                  ),
                  if (p.remindersEnabled)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
                      child: Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: p.minutesBefore.toDouble().clamp(0, 120),
                              min: 0,
                              max: 120,
                              divisions: 12,
                              label: '${p.minutesBefore} min before',
                              onChanged: (_) {},
                              onChangeEnd: (v) => _patch({
                                'actionReminders': {'minutesBefore': v.round()}
                              }),
                            ),
                          ),
                          SizedBox(
                            width: 62,
                            child: Text('${p.minutesBefore} min',
                                style: theme.textTheme.bodySmall),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: p.dailySummaryEnabled,
                    onChanged: (v) => _patch({'dailySummary': {'enabled': v}}),
                    title: const Text('Daily plan'),
                    subtitle: Text('Every morning at ${p.dailySummaryTime}'),
                  ),
                  if (p.dailySummaryEnabled)
                    ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.only(left: Gap.xl, right: Gap.lg),
                      title: const Text('Send at'),
                      trailing: Text(p.dailySummaryTime,
                          style: theme.textTheme.titleMedium),
                      onTap: () async {
                        final t = await _pickTime(p.dailySummaryTime);
                        if (t != null) _patch({'dailySummary': {'time': t}});
                      },
                    ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: p.weeklyDigestEnabled,
                    onChanged: (v) => _patch({'weeklyDigest': {'enabled': v}}),
                    title: const Text('Weekly review'),
                    subtitle: Text(
                        '${_weekday(p.weeklyDigestWeekday)} at ${p.weeklyDigestTime} · push and email'),
                  ),
                  if (p.weeklyDigestEnabled)
                    ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.only(left: Gap.xl, right: Gap.lg),
                      title: const Text('Send at'),
                      trailing: Text(p.weeklyDigestTime,
                          style: theme.textTheme.titleMedium),
                      onTap: () async {
                        final t = await _pickTime(p.weeklyDigestTime);
                        if (t != null) _patch({'weeklyDigest': {'time': t}});
                      },
                    ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: p.milestoneAlerts,
                    onChanged: (v) => _patch({'milestoneAlerts': v}),
                    title: const Text('Milestone celebrations'),
                    subtitle: const Text('When you reach a checkpoint'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Gap.xl),
            const SectionHeader('Quiet hours'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    value: p.quietHoursEnabled,
                    onChanged: (v) => _patch({'quietHours': {'enabled': v}}),
                    title: const Text('Do not disturb'),
                    subtitle: Text('${p.quietStart} to ${p.quietEnd}'),
                  ),
                  if (p.quietHoursEnabled) ...[
                    ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.only(left: Gap.xl, right: Gap.lg),
                      title: const Text('From'),
                      trailing:
                          Text(p.quietStart, style: theme.textTheme.titleMedium),
                      onTap: () async {
                        final t = await _pickTime(p.quietStart);
                        if (t != null) _patch({'quietHours': {'start': t}});
                      },
                    ),
                    ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.only(left: Gap.xl, right: Gap.lg),
                      title: const Text('Until'),
                      trailing: Text(p.quietEnd, style: theme.textTheme.titleMedium),
                      onTap: () async {
                        final t = await _pickTime(p.quietEnd);
                        if (t != null) _patch({'quietHours': {'end': t}});
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: Gap.xl),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await ref.read(appRepositoryProvider).sendTestNotification();
                  if (context.mounted) {
                    showSnack(context, 'Test notification sent');
                  }
                } on ApiException catch (e) {
                  if (context.mounted) showSnack(context, e.message, error: true);
                }
              },
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Send a test notification'),
            ),
          ],
        ),
      ),
    );
  }

  static String _weekday(int d) => const [
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
      ][d.clamp(0, 6)];
}
