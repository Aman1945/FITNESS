import 'action_item.dart';
import 'goal.dart';

class DayDot {
  const DayDot({
    required this.label,
    required this.state,
    required this.planned,
    required this.completed,
  });

  final String label;
  /// done | missed | today | rest
  final String state;
  final int planned;
  final int completed;

  factory DayDot.fromJson(Map<String, dynamic> j) => DayDot(
        label: j['label'] ?? '',
        state: j['state'] ?? 'rest',
        planned: (j['planned'] ?? 0) as int,
        completed: (j['completed'] ?? 0) as int,
      );
}

class Consistency {
  const Consistency({
    required this.currentStreak,
    required this.longestStreak,
    required this.weekPlanned,
    required this.weekCompleted,
    required this.weekPercent,
    required this.monthPercent,
    required this.last7,
  });

  final int currentStreak;
  final int longestStreak;
  final int weekPlanned;
  final int weekCompleted;
  final int weekPercent;
  final int monthPercent;
  final List<DayDot> last7;

  factory Consistency.fromJson(Map<String, dynamic> j) {
    final w = (j['week'] as Map?)?.cast<String, dynamic>() ?? const {};
    final m = (j['month'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Consistency(
      currentStreak: (j['currentStreak'] ?? 0) as int,
      longestStreak: (j['longestStreak'] ?? 0) as int,
      weekPlanned: (w['planned'] ?? 0) as int,
      weekCompleted: (w['completed'] ?? 0) as int,
      weekPercent: (w['percent'] ?? 0) as int,
      monthPercent: (m['percent'] ?? 0) as int,
      last7: (j['last7'] as List? ?? const [])
          .map((e) => DayDot.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class Greeting {
  const Greeting({required this.title, required this.subtitle, this.nudge});
  final String title;
  final String subtitle;
  final String? nudge;

  factory Greeting.fromJson(Map<String, dynamic> j) => Greeting(
        title: j['title'] ?? '',
        subtitle: j['subtitle'] ?? '',
        nudge: j['nudge'],
      );
}

class TodayFeed {
  const TodayFeed({
    required this.actions,
    required this.carriedOver,
    required this.planned,
    required this.completed,
    required this.minutesPlanned,
  });

  final List<Occurrence> actions;
  final List<Occurrence> carriedOver;
  final int planned;
  final int completed;
  final int minutesPlanned;

  int get remaining => planned - completed;
  double get ratio => planned == 0 ? 0 : completed / planned;

  factory TodayFeed.fromJson(Map<String, dynamic> j) {
    final s = (j['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
    return TodayFeed(
      actions: (j['actions'] as List? ?? const [])
          .map((e) => Occurrence.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      carriedOver: (j['carriedOver'] as List? ?? const [])
          .map((e) => Occurrence.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      planned: (s['planned'] ?? 0) as int,
      completed: (s['completed'] ?? 0) as int,
      minutesPlanned: (s['minutesPlanned'] ?? 0) as int,
    );
  }
}

class AttentionGoal {
  const AttentionGoal({required this.id, required this.title, required this.reason});
  final String id;
  final String title;
  final String reason;
}

/// Everything the home screen renders -- delivered by a single GET /dashboard.
class Dashboard {
  const Dashboard({
    required this.greeting,
    required this.today,
    required this.goals,
    required this.consistency,
    required this.upcoming,
    required this.recentlyCompleted,
    required this.milestones,
    required this.attention,
    required this.unreadNotifications,
    required this.weeklyReflectionDue,
  });

  final Greeting greeting;
  final TodayFeed today;
  final List<Goal> goals;
  final Consistency consistency;
  final List<Occurrence> upcoming;
  final List<Occurrence> recentlyCompleted;
  final List<Milestone> milestones;
  final List<AttentionGoal> attention;
  final int unreadNotifications;
  final bool weeklyReflectionDue;

  factory Dashboard.fromJson(Map<String, dynamic> j) {
    final att = (j['attention'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Dashboard(
      greeting: Greeting.fromJson((j['greeting'] as Map).cast<String, dynamic>()),
      today: TodayFeed.fromJson((j['today'] as Map).cast<String, dynamic>()),
      goals: (j['goals'] as List? ?? const [])
          .map((e) => Goal.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      consistency:
          Consistency.fromJson((j['consistency'] as Map).cast<String, dynamic>()),
      upcoming: (j['upcoming'] as List? ?? const [])
          .map((e) => Occurrence.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      recentlyCompleted: (j['recentlyCompleted'] as List? ?? const [])
          .map((e) => Occurrence.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      milestones: (j['milestones'] as List? ?? const [])
          .map((e) => Milestone.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      attention: (att['goals'] as List? ?? const [])
          .map((e) => AttentionGoal(
                id: e['id']?.toString() ?? '',
                title: e['title'] ?? '',
                reason: e['reason'] ?? '',
              ))
          .toList(),
      unreadNotifications: (j['unreadNotifications'] ?? 0) as int,
      weeklyReflectionDue: j['weeklyReflectionDue'] ?? false,
    );
  }
}
