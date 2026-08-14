import 'action_item.dart';

class Routine {
  const Routine({
    this.type = 'specific_days',
    this.days = const [1, 3, 5],
    this.timesPerWeek = 3,
    this.timeOfDay = 'evening',
    this.startTime = '19:00',
    this.durationMinutes = 30,
  });

  final String type;
  final List<int> days;
  final int timesPerWeek;
  final String timeOfDay;
  final String startTime;
  final int durationMinutes;

  factory Routine.fromJson(Map<String, dynamic> j) => Routine(
        type: j['type'] ?? 'specific_days',
        days: (j['days'] as List? ?? const [1, 3, 5]).map((e) => e as int).toList(),
        timesPerWeek: j['timesPerWeek'] ?? 3,
        timeOfDay: j['timeOfDay'] ?? 'evening',
        startTime: j['startTime'] ?? '19:00',
        durationMinutes: j['durationMinutes'] ?? 30,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'days': days,
        'timesPerWeek': timesPerWeek,
        'timeOfDay': timeOfDay,
        'startTime': startTime,
        'durationMinutes': durationMinutes,
      };

  Routine copyWith({
    String? type,
    List<int>? days,
    int? timesPerWeek,
    String? timeOfDay,
    String? startTime,
    int? durationMinutes,
  }) =>
      Routine(
        type: type ?? this.type,
        days: days ?? this.days,
        timesPerWeek: timesPerWeek ?? this.timesPerWeek,
        timeOfDay: timeOfDay ?? this.timeOfDay,
        startTime: startTime ?? this.startTime,
        durationMinutes: durationMinutes ?? this.durationMinutes,
      );

  static const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  /// Human summary shown on cards -- "Mon, Wed, Fri at 7:00 PM - 30 min".
  String get summary {
    final when = switch (type) {
      'daily' => 'Every day',
      'weekly_count' => '$timesPerWeek times a week',
      'once' => 'One time',
      _ => days.isEmpty
          ? 'No days set'
          : (days.toList()..sort()).map((d) => _dayNames[d]).join(', '),
    };
    return '$when  ·  $startTime  ·  ${durationMinutes}m';
  }
}

class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.category,
    required this.priority,
    required this.status,
    required this.progressPercent,
    required this.computedStatus,
    required this.statusReason,
    required this.startDate,
    required this.targetDate,
    required this.routine,
    this.description,
    this.why,
    this.customCategory,
    this.color,
    this.completedCount = 0,
    this.totalCount = 0,
  });

  final String id;
  final String title;
  final String category;
  final String priority;
  final String status;
  final int progressPercent;
  final String computedStatus;
  final String statusReason;
  final DateTime startDate;
  final DateTime targetDate;
  final Routine routine;
  final String? description;
  final String? why;
  final String? customCategory;
  final String? color;
  final int completedCount;
  final int totalCount;

  String get displayCategory =>
      category == 'custom' ? (customCategory ?? 'Custom') : category;

  int get daysRemaining => targetDate.difference(DateTime.now()).inDays;

  bool get isActive => status == 'active';

  static String statusLabel(String s) => switch (s) {
        'ahead' => 'Ahead',
        'on_track' => 'On track',
        'needs_attention' => 'Needs attention',
        'behind' => 'Behind',
        'completed' => 'Completed',
        _ => s,
      };

  factory Goal.fromJson(Map<String, dynamic> j) {
    final counts = (j['counts'] as Map?)?.cast<String, dynamic>();
    return Goal(
      id: j['id']?.toString() ?? '',
      title: j['title'] ?? '',
      category: j['category'] ?? 'personal',
      priority: j['priority'] ?? 'medium',
      status: j['status'] ?? 'active',
      progressPercent: (j['progressPercent'] ?? 0) as int,
      computedStatus: j['computedStatus'] ?? 'on_track',
      statusReason: j['statusReason'] ?? '',
      startDate: DateTime.tryParse(j['startDate']?.toString() ?? '') ?? DateTime.now(),
      targetDate: DateTime.tryParse(j['targetDate']?.toString() ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
      routine: Routine.fromJson((j['routine'] as Map?)?.cast<String, dynamic>() ?? const {}),
      description: j['description'],
      why: j['why'],
      customCategory: j['customCategory'],
      color: j['color'],
      completedCount: (counts?['completed'] ?? 0) as int,
      totalCount: (counts?['total'] ?? 0) as int,
    );
  }
}

class Milestone {
  const Milestone({
    required this.id,
    required this.goalId,
    required this.title,
    required this.status,
    required this.progressPercent,
    required this.order,
    this.description,
    this.targetDate,
    this.actions = const [],
    this.goalTitle,
  });

  final String id;
  final String goalId;
  final String title;
  final String status;
  final int progressPercent;
  final int order;
  final String? description;
  final DateTime? targetDate;
  final List<ActionPlan> actions;
  final String? goalTitle;

  bool get isCompleted => status == 'completed';

  factory Milestone.fromJson(Map<String, dynamic> j) {
    final goal = j['goal'];
    return Milestone(
      id: j['id']?.toString() ?? '',
      goalId: goal is Map ? goal['id']?.toString() ?? '' : goal?.toString() ?? '',
      goalTitle: goal is Map ? goal['title']?.toString() : null,
      title: j['title'] ?? '',
      status: j['status'] ?? 'pending',
      progressPercent: (j['progressPercent'] ?? 0) as int,
      order: (j['order'] ?? 0) as int,
      description: j['description'],
      targetDate: DateTime.tryParse(j['targetDate']?.toString() ?? ''),
      actions: (j['actions'] as List? ?? const [])
          .map((e) => ActionPlan.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// Everything the goal detail screen needs, in one object.
class GoalDetail {
  const GoalDetail({
    required this.goal,
    required this.milestones,
    required this.standaloneActions,
    required this.history,
    required this.evaluation,
  });

  final Goal goal;
  final List<Milestone> milestones;
  final List<ActionPlan> standaloneActions;
  final List<Occurrence> history;
  final GoalEvaluation evaluation;

  factory GoalDetail.fromJson(Map<String, dynamic> j) => GoalDetail(
        goal: Goal.fromJson((j['goal'] as Map).cast<String, dynamic>()),
        milestones: (j['milestones'] as List? ?? const [])
            .map((e) => Milestone.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        standaloneActions: (j['standaloneActions'] as List? ?? const [])
            .map((e) => ActionPlan.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        history: (j['history'] as List? ?? const [])
            .map((e) => Occurrence.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        evaluation: GoalEvaluation.fromJson(
            (j['evaluation'] as Map).cast<String, dynamic>()),
      );
}

class GoalEvaluation {
  const GoalEvaluation({
    required this.progressPercent,
    required this.status,
    required this.reason,
    required this.completed,
    required this.missed,
    required this.totalPlanned,
    required this.daysRemaining,
    required this.adherence,
  });

  final int progressPercent;
  final String status;
  final String reason;
  final int completed;
  final int missed;
  final int totalPlanned;
  final int daysRemaining;
  final double adherence;

  factory GoalEvaluation.fromJson(Map<String, dynamic> j) {
    final m = (j['metrics'] as Map?)?.cast<String, dynamic>() ?? const {};
    return GoalEvaluation(
      progressPercent: (j['progressPercent'] ?? 0) as int,
      status: j['status'] ?? 'on_track',
      reason: j['reason'] ?? '',
      completed: (m['completed'] ?? 0) as int,
      missed: (m['missed'] ?? 0) as int,
      totalPlanned: (m['totalPlanned'] ?? 0) as int,
      daysRemaining: (m['daysRemaining'] ?? 0) as int,
      adherence: ((m['adherence'] ?? 0) as num).toDouble(),
    );
  }
}
