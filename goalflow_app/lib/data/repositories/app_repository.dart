import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../models/action_item.dart';
import '../models/dashboard.dart';
import '../models/progress.dart';
import '../models/user.dart';

/// Dashboard, schedule, progress, reflections, notifications and profile.
/// Grouped because these are all "read the user's own state" calls that the
/// screens consume together.
class AppRepository {
  AppRepository(this._api);
  final ApiClient _api;

  // ---------- dashboard & schedule ----------

  Future<Dashboard> dashboard() async {
    final data = await _api.get('/dashboard');
    return Dashboard.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<TodayFeed> today() async {
    final data = await _api.get('/occurrences/today');
    return TodayFeed.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<List<Occurrence>> range(DateTime from, DateTime to) async {
    final data = await _api.get('/occurrences', query: {
      'from': _day(from),
      'to': _day(to),
    });
    return (data as List)
        .map((e) => Occurrence.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> complete(String id, {int? actualMinutes, String? note}) =>
      _api.post('/occurrences/$id/complete', body: {
        if (actualMinutes != null) 'actualMinutes': actualMinutes,
        if (note != null && note.isNotEmpty) 'note': note,
      });

  Future<void> skip(String id, {String? note}) => _api.post(
        '/occurrences/$id/skip',
        body: {if (note != null && note.isNotEmpty) 'note': note},
      );

  Future<void> undo(String id) => _api.post('/occurrences/$id/undo');

  Future<void> reschedule(String id, DateTime date) =>
      _api.patch('/occurrences/$id/reschedule', body: {'date': _day(date)});

  Future<void> regenerateSchedule() => _api.post('/occurrences/generate');

  // ---------- progress ----------

  Future<ProgressSummary> progress({String range = 'month'}) async {
    final data = await _api.get('/progress/summary', query: {'range': range});
    return ProgressSummary.fromJson((data as Map).cast<String, dynamic>());
  }

  // ---------- reflection ----------

  Future<WeeklyReview> currentReview() async {
    final data = await _api.get('/reflections/current');
    return WeeklyReview.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> saveReflection({
    String? wentWell,
    String? wasDifficult,
    String? improveNext,
  }) =>
      _api.post('/reflections', body: {
        if (wentWell != null) 'wentWell': wentWell,
        if (wasDifficult != null) 'wasDifficult': wasDifficult,
        if (improveNext != null) 'improveNext': improveNext,
      });

  // ---------- profile & preferences ----------

  Future<AppUser> me() async {
    final data = await _api.get('/users/me');
    return AppUser.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<AppUser> updateProfile(Map<String, dynamic> patch) async {
    final data = await _api.patch('/users/me', body: patch);
    return AppUser.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<String> uploadAvatar(Uint8List bytes, String filename) async {
    final data = await _api.upload('/users/me/avatar', 'avatar', bytes, filename);
    return (data as Map)['avatarUrl'] as String;
  }

  Future<UserPreferences> updatePreferences(Map<String, dynamic> patch) async {
    final data = await _api.patch('/users/me/preferences', body: patch);
    return UserPreferences.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<NotificationPreferences> notificationPreferences() async {
    final data = await _api.get('/users/me/notification-preferences');
    return NotificationPreferences.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<NotificationPreferences> updateNotificationPreferences(
      Map<String, dynamic> patch) async {
    final data = await _api.patch('/users/me/notification-preferences', body: patch);
    return NotificationPreferences.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> registerDevice(String token, String platform) =>
      _api.post('/users/me/devices', body: {'token': token, 'platform': platform});

  // ---------- onboarding ----------

  Future<AppUser> completeOnboarding(Map<String, dynamic> payload) async {
    final data = await _api.post('/onboarding/complete', body: payload);
    return AppUser.fromJson(((data as Map)['user'] as Map).cast<String, dynamic>());
  }

  // ---------- notifications ----------

  Future<(List<AppNotification>, int)> notifications() async {
    final data = await _api.get('/notifications');
    final map = (data as Map).cast<String, dynamic>();
    final items = (map['items'] as List)
        .map((e) => AppNotification.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return (items, (map['unread'] ?? 0) as int);
  }

  Future<void> markAllRead() => _api.post('/notifications/read-all');

  Future<void> sendTestNotification() => _api.post('/notifications/test');

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
