/// The PLAN: a recurring rule attached to a goal (and optionally a milestone).
class ActionPlan {
  const ActionPlan({
    required this.id,
    required this.goalId,
    required this.title,
    required this.estimatedMinutes,
    required this.priority,
    required this.difficulty,
    required this.isRecurring,
    required this.recurrenceType,
    required this.days,
    this.milestoneId,
    this.description,
    this.preferredTime,
    this.dueDate,
    this.targetCount,
    this.unit,
  });

  final String id;
  final String goalId;
  final String title;
  final int estimatedMinutes;
  final String priority;
  final String difficulty;
  final bool isRecurring;
  final String recurrenceType;
  final List<int> days;
  final String? milestoneId;
  final String? description;
  final String? preferredTime;
  final DateTime? dueDate;
  final int? targetCount;
  final String? unit;

  factory ActionPlan.fromJson(Map<String, dynamic> j) {
    final r = (j['recurrence'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ActionPlan(
      id: j['id']?.toString() ?? '',
      goalId: j['goal']?.toString() ?? '',
      milestoneId: j['milestone']?.toString(),
      title: j['title'] ?? '',
      description: j['description'],
      estimatedMinutes: (j['estimatedMinutes'] ?? 30) as int,
      priority: j['priority'] ?? 'medium',
      difficulty: j['difficulty'] ?? 'medium',
      isRecurring: j['isRecurring'] ?? true,
      recurrenceType: r['type'] ?? 'specific_days',
      days: (r['days'] as List? ?? const []).map((e) => e as int).toList(),
      preferredTime: j['preferredTime'],
      dueDate: DateTime.tryParse(j['dueDate']?.toString() ?? ''),
      targetCount: j['targetCount'],
      unit: j['unit'],
    );
  }
}

/// The LOG: one dated instance of an [ActionPlan].
/// This is what the user actually ticks off.
class Occurrence {
  const Occurrence({
    required this.id,
    required this.title,
    required this.status,
    required this.scheduledAt,
    required this.scheduledDate,
    required this.estimatedMinutes,
    required this.priority,
    required this.goalId,
    this.goalTitle,
    this.goalColor,
    this.goalCategory,
    this.milestoneId,
    this.completedAt,
    this.actualMinutes,
    this.note,
  });

  final String id;
  final String title;
  final String status;
  final DateTime scheduledAt;
  final DateTime scheduledDate;
  final int estimatedMinutes;
  final String priority;
  final String goalId;
  final String? goalTitle;
  final String? goalColor;
  final String? goalCategory;
  final String? milestoneId;
  final DateTime? completedAt;
  final int? actualMinutes;
  final String? note;

  bool get isCompleted => status == 'completed';
  bool get isMissed => status == 'missed';
  bool get isSkipped => status == 'skipped';
  bool get isOpen => status == 'upcoming' || status == 'in_progress';

  factory Occurrence.fromJson(Map<String, dynamic> j) {
    final goal = j['goal'];
    final isPopulated = goal is Map;
    return Occurrence(
      id: j['id']?.toString() ?? '',
      title: j['title'] ?? '',
      status: j['status'] ?? 'upcoming',
      scheduledAt:
          DateTime.tryParse(j['scheduledAt']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      scheduledDate:
          DateTime.tryParse(j['scheduledDate']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      estimatedMinutes: (j['estimatedMinutes'] ?? 30) as int,
      priority: j['priority'] ?? 'medium',
      goalId: isPopulated ? goal['id']?.toString() ?? '' : goal?.toString() ?? '',
      goalTitle: isPopulated ? goal['title']?.toString() : null,
      goalColor: isPopulated ? goal['color']?.toString() : null,
      goalCategory: isPopulated ? goal['category']?.toString() : null,
      milestoneId: j['milestone']?.toString(),
      completedAt: DateTime.tryParse(j['completedAt']?.toString() ?? '')?.toLocal(),
      actualMinutes: j['actualMinutes'],
      note: j['note'],
    );
  }

  Occurrence copyWith({String? status, DateTime? completedAt}) => Occurrence(
        id: id,
        title: title,
        status: status ?? this.status,
        scheduledAt: scheduledAt,
        scheduledDate: scheduledDate,
        estimatedMinutes: estimatedMinutes,
        priority: priority,
        goalId: goalId,
        goalTitle: goalTitle,
        goalColor: goalColor,
        goalCategory: goalCategory,
        milestoneId: milestoneId,
        completedAt: completedAt ?? this.completedAt,
        actualMinutes: actualMinutes,
        note: note,
      );
}
