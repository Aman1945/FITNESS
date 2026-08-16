import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:goalflow_app/application/theme_provider.dart';

import 'package:goalflow_app/core/theme/app_theme.dart';
import 'package:goalflow_app/data/models/goal.dart';
import 'package:goalflow_app/presentation/widgets/common.dart';

/// Smoke tests for the pieces that carry real logic.
/// The full app needs a live backend, so these cover the pure units instead.
void main() {
  group('Routine.summary', () {
    test('lists specific days', () {
      const r = Routine(type: 'specific_days', days: [1, 3, 5], startTime: '19:00');
      expect(r.summary, contains('Mon'));
      expect(r.summary, contains('Wed'));
      expect(r.summary, contains('19:00'));
    });

    test('describes a daily routine', () {
      const r = Routine(type: 'daily');
      expect(r.summary, startsWith('Every day'));
    });

    test('describes a weekly count', () {
      const r = Routine(type: 'weekly_count', timesPerWeek: 4);
      expect(r.summary, startsWith('4 times a week'));
    });
  });

  group('Goal', () {
    test('falls back to the category when no custom name is set', () {
      final g = Goal.fromJson({
        'id': '1',
        'title': 'Read more',
        'category': 'learning',
        'targetDate': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });
      expect(g.displayCategory, 'learning');
    });

    test('prefers the custom category name', () {
      final g = Goal.fromJson({
        'id': '1',
        'title': 'Guitar',
        'category': 'custom',
        'customCategory': 'Music',
        'targetDate': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });
      expect(g.displayCategory, 'Music');
    });

    test('maps every status to a readable label', () {
      expect(Goal.statusLabel('on_track'), 'On track');
      expect(Goal.statusLabel('needs_attention'), 'Needs attention');
      expect(Goal.statusLabel('ahead'), 'Ahead');
    });
  });

  testWidgets('ProgressRing renders its percentage', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: ProgressRing(value: 0.65)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('65%'), findsOneWidget);
  });

  testWidgets('StatusChip shows the label for a status', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: StatusChip('behind')),
      ),
    );
    expect(find.text('Behind'), findsOneWidget);
  });

  group('ThemeMode preference', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults to following the system', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('applies a chosen mode immediately and persists it', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.notifier).set(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);

      // A fresh container must read the saved value back. The first read
      // constructs the notifier, whose restore is async -- so read, let it
      // settle, then assert.
      final restored = ProviderContainer();
      addTearDown(restored.dispose);
      restored.read(themeModeProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(restored.read(themeModeProvider), ThemeMode.dark);
    });

    test('cycles System -> Light -> Dark -> System', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(themeModeProvider.notifier);

      await notifier.cycle();
      expect(container.read(themeModeProvider), ThemeMode.light);
      await notifier.cycle();
      expect(container.read(themeModeProvider), ThemeMode.dark);
      await notifier.cycle();
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('every mode has a label, description and icon', () {
      for (final mode in ThemeMode.values) {
        expect(mode.label, isNotEmpty);
        expect(mode.description, isNotEmpty);
        expect(mode.icon, isNotNull);
      }
    });
  });
}
