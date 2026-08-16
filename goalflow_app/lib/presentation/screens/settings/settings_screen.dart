import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../application/theme_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/goal_widgets.dart';

/// Preferences edited here feed straight back into how the backend schedules
/// actions -- the same values onboarding collected, nothing duplicated.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _saving = false;

  Future<void> _save(Map<String, dynamic> patch) async {
    setState(() => _saving = true);
    try {
      final prefs = await ref.read(appRepositoryProvider).updatePreferences(patch);
      final user = ref.read(currentUserProvider);
      if (user != null) {
        ref.read(authProvider.notifier).setUser(user.copyWith(preferences: prefs));
      }
      invalidateProgressData(ref);
      if (mounted) showSnack(context, 'Saved');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    if (user == null) return const SizedBox.shrink();
    final prefs = user.preferences;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: Gap.lg),
              child: Center(
                child: SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xxl),
        children: [
          const SectionHeader('Your schedule'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preferred days', style: theme.textTheme.labelLarge),
                const SizedBox(height: Gap.md),
                DayPicker(
                  selected: prefs.preferredDays,
                  onChanged: (d) {
                    if (d.isEmpty) return;
                    _save({'preferredDays': d});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.md),
          AppCard(
            onTap: () async {
              final parts = prefs.preferredStartTime.split(':');
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: int.tryParse(parts.first) ?? 19,
                  minute: int.tryParse(parts.last) ?? 0,
                ),
              );
              if (picked == null) return;
              final hhmm =
                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
              _save({
                'preferredStartTime': hhmm,
                'preferredTimeOfDay': picked.hour < 12
                    ? 'morning'
                    : picked.hour < 17
                        ? 'afternoon'
                        : picked.hour < 21
                            ? 'evening'
                            : 'night',
              });
            },
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 20),
                const SizedBox(width: Gap.md),
                const Text('Preferred start time'),
                const Spacer(),
                Text(prefs.preferredStartTime, style: theme.textTheme.titleMedium),
              ],
            ),
          ),

          const SizedBox(height: Gap.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Default session length',
                        style: theme.textTheme.labelLarge),
                    const Spacer(),
                    Text('${prefs.defaultSessionMinutes} min',
                        style: theme.textTheme.titleMedium),
                  ],
                ),
                Slider(
                  value: prefs.defaultSessionMinutes.toDouble(),
                  min: 10,
                  max: 120,
                  divisions: 11,
                  onChanged: (v) {
                    final user = ref.read(currentUserProvider)!;
                    ref.read(authProvider.notifier).setUser(
                          user.copyWith(
                            preferences: user.preferences
                                .copyWith(defaultSessionMinutes: v.round()),
                          ),
                        );
                  },
                  onChangeEnd: (v) => _save({'defaultSessionMinutes': v.round()}),
                ),
              ],
            ),
          ),

          const SizedBox(height: Gap.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Weekly target', style: theme.textTheme.labelLarge),
                    const Spacer(),
                    Text('${prefs.weeklyTargetActions} actions',
                        style: theme.textTheme.titleMedium),
                  ],
                ),
                Slider(
                  value: prefs.weeklyTargetActions.toDouble(),
                  min: 1,
                  max: 21,
                  divisions: 20,
                  onChanged: (v) {
                    final user = ref.read(currentUserProvider)!;
                    ref.read(authProvider.notifier).setUser(
                          user.copyWith(
                            preferences: user.preferences
                                .copyWith(weeklyTargetActions: v.round()),
                          ),
                        );
                  },
                  onChangeEnd: (v) => _save({'weeklyTargetActions': v.round()}),
                ),
              ],
            ),
          ),

          const SizedBox(height: Gap.xl),
          const SectionHeader('How progress is shown'),
          ...[
            ('percentage', 'Percentages', 'Exact completion figures'),
            ('streak', 'Consistency', 'Streaks and steadiness'),
            ('minimal', 'Minimal', 'Just today, fewer numbers'),
          ].map((s) {
            final selected = prefs.progressStyle == s.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: AppCard(
                onTap: () => _save({'progressStyle': s.$1}),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 21,
                      color: selected ? theme.colorScheme.primary : null,
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.$2, style: theme.textTheme.titleMedium),
                          Text(s.$3, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: Gap.xl),
          const SectionHeader('Appearance'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: theme.textTheme.labelLarge),
                const SizedBox(height: Gap.xs),
                Text(
                  ref.watch(themeModeProvider).description,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: Gap.md),
                _ThemePicker(
                  selected: ref.watch(themeModeProvider),
                  onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
                ),
              ],
            ),
          ),

          const SizedBox(height: Gap.xl),
          const SectionHeader('Notifications'),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.notifications_none_rounded),
              title: const Text('Notification preferences'),
              subtitle: const Text('Reminders, summaries and quiet hours'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/settings/notifications'),
            ),
          ),

          const SizedBox(height: Gap.xl),
          const SectionHeader('Schedule'),
          AppCard(
            onTap: () async {
              await ref.read(appRepositoryProvider).regenerateSchedule();
              invalidateProgressData(ref);
              if (context.mounted) showSnack(context, 'Schedule regenerated');
            },
            child: Row(
              children: [
                const Icon(Icons.refresh_rounded, size: 20),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rebuild my schedule',
                          style: theme.textTheme.titleMedium),
                      Text('Regenerate the next 7 days from your routines',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: Gap.xl),
          AppCard(
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text('Your data stays safe on your account.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Sign out')),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(authProvider.notifier).logout();
              }
            },
            child: Row(
              children: [
                const Icon(Icons.logout_rounded, size: 20, color: AppColors.behind),
                const SizedBox(width: Gap.md),
                Text('Sign out',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: AppColors.behind)),
              ],
            ),
          ),

          const SizedBox(height: Gap.xl),
          Center(
            child: Text('GoalFlow v1.0.0', style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Segmented System / Light / Dark control.
/// Deliberately shows all three at once -- a cycling icon button hides which
/// options exist, and "System" is the one people forget they can go back to.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.selected, required this.onChanged});

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        for (final mode in ThemeMode.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: mode == ThemeMode.dark ? 0 : Gap.sm,
              ),
              child: _ThemeOption(
                mode: mode,
                isSelected: mode == selected,
                accent: scheme.primary,
                onTap: () => onChanged(mode),
              ),
            ),
          ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.isSelected,
    required this.accent,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${mode.label} theme',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Gap.radiusSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: Gap.md),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: isDark ? 0.20 : 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(Gap.radiusSm),
            border: Border.all(
              color: isSelected ? accent : theme.dividerColor,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                mode.icon,
                size: 21,
                color: isSelected ? accent : theme.textTheme.bodySmall?.color,
              ),
              const SizedBox(height: Gap.xs + 2),
              Text(
                mode.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected ? accent : null,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
