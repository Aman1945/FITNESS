import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
