import '../../core/network/api_client.dart';
import '../models/action_item.dart';
import '../models/goal.dart';

class GoalRepository {
  GoalRepository(this._api);
  final ApiClient _api;

  Future<List<Goal>> list({String? status, String? category}) async {
    final data = await _api.get('/goals', query: {
      if (status != null) 'status': status,
      if (category != null) 'category': category,
    });
    return (data as List)
        .map((e) => Goal.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<GoalDetail> detail(String id) async {
    final data = await _api.get('/goals/$id');
    return GoalDetail.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Goal> create({
    required String title,
    required String category,
    required String priority,
    required DateTime targetDate,
    required Routine routine,
    String? description,
    String? why,
    String? customCategory,
    String? color,
  }) async {
    final data = await _api.post('/goals', body: {
      'title': title,
      'category': category,
      'priority': priority,
      'targetDate': targetDate.toIso8601String(),
      'routine': routine.toJson(),
      if (description != null && description.isNotEmpty) 'description': description,
      if (why != null && why.isNotEmpty) 'why': why,
      if (customCategory != null && customCategory.isNotEmpty)
        'customCategory': customCategory,
      if (color != null) 'color': color,
    });
    return Goal.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Goal> update(String id, Map<String, dynamic> patch) async {
    final data = await _api.patch('/goals/$id', body: patch);
    return Goal.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> setLifecycle(String id, String action) =>
      _api.post('/goals/$id/$action'); // pause | resume | complete

  Future<void> archive(String id) => _api.delete('/goals/$id');

  Future<List<Map<String, dynamic>>> history(String id, {int weeks = 8}) async {
    final data = await _api.get('/goals/$id/history', query: {'weeks': weeks});
    return (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Milestone> createMilestone(
    String goalId, {
    required String title,
    String? description,
    DateTime? targetDate,
  }) async {
    final data = await _api.post('/goals/$goalId/milestones', body: {
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      if (targetDate != null) 'targetDate': targetDate.toIso8601String(),
    });
    return Milestone.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> completeMilestone(String id) => _api.post('/milestones/$id/complete');

  Future<void> deleteMilestone(String id) => _api.delete('/milestones/$id');

  Future<ActionPlan> createAction({
    required String goalId,
    required String title,
    String? milestoneId,
    String? description,
    int estimatedMinutes = 30,
    String priority = 'medium',
    String difficulty = 'medium',
    String recurrenceType = 'specific_days',
    List<int> days = const [],
    String? preferredTime,
    DateTime? dueDate,
    int? targetCount,
    String? unit,
  }) async {
    final data = await _api.post('/actions', body: {
      'goal': goalId,
      'title': title,
      if (milestoneId != null) 'milestone': milestoneId,
      if (description != null && description.isNotEmpty) 'description': description,
      'estimatedMinutes': estimatedMinutes,
      'priority': priority,
      'difficulty': difficulty,
      'isRecurring': recurrenceType != 'once',
      'recurrence': {
        'type': recurrenceType,
        'days': days,
        'timesPerWeek': days.isEmpty ? 3 : days.length,
      },
      if (preferredTime != null) 'preferredTime': preferredTime,
      if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
      if (targetCount != null) 'targetCount': targetCount,
      if (unit != null && unit.isNotEmpty) 'unit': unit,
    });
    return ActionPlan.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> deleteAction(String id) => _api.delete('/actions/$id');
}
