import 'dashboard.dart';
import 'goal.dart';
import 'action_item.dart';

class WeekPoint {
  const WeekPoint({
    required this.label,
    required this.planned,
    required this.completed,
    required this.percent,
    required this.minutes,
  });

  final String label;
  final int planned;
  final int completed;
  final int percent;
  final int minutes;

  factory WeekPoint.fromJson(Map<String, dynamic> j) => WeekPoint(
        label: j['label'] ?? '',
        planned: (j['planned'] ?? 0) as int,
        completed: (j['completed'] ?? 0) as int,
        percent: (j['percent'] ?? 0) as int,
        minutes: (j['minutes'] ?? 0) as int,
      );
}

class CategorySlice {
  const CategorySlice({
    required this.category,
    required this.completed,
    required this.minutes,
  });
  final String category;
  final int completed;
  final int minutes;

  factory CategorySlice.fromJson(Map<String, dynamic> j) => CategorySlice(
        category: j['category'] ?? 'personal',
        completed: (j['completed'] ?? 0) as int,
        minutes: (j['minutes'] ?? 0) as int,
      );
}

class ProgressSummary {
  const ProgressSummary({
    required this.trend,
    required this.byCategory,
    required this.goals,
    required this.consistency,
    required this.completed,
    required this.missed,
    required this.skipped,
    required this.minutes,
  });

  final List<WeekPoint> trend;
  final List<CategorySlice> byCategory;
  final List<Goal> goals;
  final Consistency consistency;
  final int completed;
  final int missed;
  final int skipped;
  final int minutes;

  factory ProgressSummary.fromJson(Map<String, dynamic> j) {
    final t = (j['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ProgressSummary(
      trend: (j['trend'] as List? ?? const [])
          .map((e) => WeekPoint.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      byCategory: (j['byCategory'] as List? ?? const [])
          .map((e) => CategorySlice.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      goals: (j['goals'] as List? ?? const [])
          .map((e) => Goal.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      consistency:
          Consistency.fromJson((j['consistency'] as Map).cast<String, dynamic>()),
      completed: (t['completed'] ?? 0) as int,
      missed: (t['missed'] ?? 0) as int,
      skipped: (t['skipped'] ?? 0) as int,
      minutes: (t['minutes'] ?? 0) as int,
    );
  }
}

class GoalWeekStat {
  const GoalWeekStat({
    required this.title,
    required this.planned,
    required this.completed,
    required this.missed,
    required this.percent,
  });

  final String title;
  final int planned;
  final int completed;
  final int missed;
  final int percent;

  factory GoalWeekStat.fromJson(Map<String, dynamic> j) => GoalWeekStat(
        title: j['title'] ?? '',
        planned: (j['planned'] ?? 0) as int,
        completed: (j['completed'] ?? 0) as int,
        missed: (j['missed'] ?? 0) as int,
        percent: (j['percent'] ?? 0) as int,
      );
}

class WeeklyReview {
  const WeeklyReview({
    required this.label,
    required this.planned,
    required this.completed,
    required this.missed,
    required this.completionRate,
    required this.goalsWorkedOn,
    required this.minutesInvested,
    required this.perGoal,
    required this.upcomingPriorities,
    this.strongest,
    this.needsAttention,
    this.wentWell,
    this.wasDifficult,
    this.improveNext,
    this.submitted = false,
  });

  final String label;
  final int planned;
  final int completed;
  final int missed;
  final int completionRate;
  final int goalsWorkedOn;
  final int minutesInvested;
  final List<GoalWeekStat> perGoal;
  final List<Occurrence> upcomingPriorities;
  final String? strongest;
  final String? needsAttention;
  final String? wentWell;
  final String? wasDifficult;
  final String? improveNext;
  final bool submitted;

  factory WeeklyReview.fromJson(Map<String, dynamic> j) {
    final s = (j['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
    final r = (j['reflection'] as Map?)?.cast<String, dynamic>();
    return WeeklyReview(
      label: j['label'] ?? '',
      planned: (s['planned'] ?? 0) as int,
      completed: (s['completed'] ?? 0) as int,
      missed: (s['missed'] ?? 0) as int,
      completionRate: (s['completionRate'] ?? 0) as int,
      goalsWorkedOn: (s['goalsWorkedOn'] ?? 0) as int,
      minutesInvested: (s['minutesInvested'] ?? 0) as int,
      strongest: s['strongestGoalTitle'],
      needsAttention: s['weakestGoalTitle'],
      perGoal: (j['perGoal'] as List? ?? const [])
          .map((e) => GoalWeekStat.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      upcomingPriorities: (j['upcomingPriorities'] as List? ?? const [])
          .map((e) => Occurrence.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      wentWell: r?['wentWell'],
      wasDifficult: r?['wasDifficult'],
      improveNext: r?['improveNext'],
      submitted: r?['submittedAt'] != null,
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id']?.toString() ?? '',
        type: j['type'] ?? 'system',
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        createdAt:
            DateTime.tryParse(j['createdAt']?.toString() ?? '')?.toLocal() ??
                DateTime.now(),
        read: j['readAt'] != null,
      );
}
