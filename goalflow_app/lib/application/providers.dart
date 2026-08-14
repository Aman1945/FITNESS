import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/storage/token_storage.dart';
import '../data/models/dashboard.dart';
import '../data/models/goal.dart';
import '../data/models/progress.dart';
import '../data/models/user.dart';
import '../data/repositories/app_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/goal_repository.dart';

// ---------------------------------------------------------------------------
// infrastructure
// ---------------------------------------------------------------------------

final tokenStorageProvider = Provider((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(storage: ref.watch(tokenStorageProvider));
  // A dead session anywhere in the app funnels back to one place.
  client.onSessionExpired = () => ref.read(authProvider.notifier).forceSignOut();
  return client;
});

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider)),
);
final goalRepositoryProvider =
    Provider((ref) => GoalRepository(ref.watch(apiClientProvider)));
final appRepositoryProvider =
    Provider((ref) => AppRepository(ref.watch(apiClientProvider)));

// ---------------------------------------------------------------------------
// auth
// ---------------------------------------------------------------------------

enum AuthStage { unknown, signedOut, needsOnboarding, ready }

class AuthState {
  const AuthState({required this.stage, this.user, this.pendingEmail});

  final AuthStage stage;
  final AppUser? user;

  /// email awaiting verification, so the code screen survives a rebuild
  final String? pendingEmail;

  AuthState copyWith({AuthStage? stage, AppUser? user, String? pendingEmail}) =>
      AuthState(
        stage: stage ?? this.stage,
        user: user ?? this.user,
        pendingEmail: pendingEmail ?? this.pendingEmail,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState(stage: AuthStage.unknown)) {
    restore();
  }

  final Ref _ref;
  AuthRepository get _repo => _ref.read(authRepositoryProvider);

  Future<void> restore() async {
    final user = await _repo.currentUser();
    state = user == null
        ? const AuthState(stage: AuthStage.signedOut)
        : AuthState(stage: _stageFor(user), user: user);
  }

  Future<void> login(String email, String password) async {
    final user = await _repo.login(email, password);
    state = AuthState(stage: _stageFor(user), user: user);
  }

  Future<void> register(String name, String email, String password) async {
    final user = await _repo.register(
      name: name,
      email: email,
      password: password,
      timezone: DateTime.now().timeZoneName == 'IST' ? 'Asia/Kolkata' : 'Asia/Kolkata',
    );
    state = AuthState(stage: AuthStage.needsOnboarding, user: user, pendingEmail: email);
  }

  Future<void> verifyEmail(String code) async {
    await _repo.verifyEmail(state.pendingEmail ?? state.user?.email ?? '', code);
    await restore();
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(stage: AuthStage.signedOut);
  }

  /// Called by the API client when a refresh fails.
  void forceSignOut() => state = const AuthState(stage: AuthStage.signedOut);

  void setUser(AppUser user) => state = AuthState(stage: _stageFor(user), user: user);

  static AuthStage _stageFor(AppUser user) =>
      user.onboardingCompleted ? AuthStage.ready : AuthStage.needsOnboarding;
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref));

final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authProvider).user);

// ---------------------------------------------------------------------------
// screens data
// ---------------------------------------------------------------------------

final dashboardProvider = FutureProvider.autoDispose<Dashboard>(
  (ref) => ref.watch(appRepositoryProvider).dashboard(),
);

final todayProvider = FutureProvider.autoDispose<TodayFeed>(
  (ref) => ref.watch(appRepositoryProvider).today(),
);

final goalsFilterProvider = StateProvider<String?>((ref) => null);

final goalsProvider = FutureProvider.autoDispose<List<Goal>>(
  (ref) => ref.watch(goalRepositoryProvider).list(status: ref.watch(goalsFilterProvider)),
);

final goalDetailProvider = FutureProvider.autoDispose.family<GoalDetail, String>(
  (ref, id) => ref.watch(goalRepositoryProvider).detail(id),
);

final progressRangeProvider = StateProvider<String>((ref) => 'month');

final progressProvider = FutureProvider.autoDispose<ProgressSummary>(
  (ref) => ref.watch(appRepositoryProvider).progress(range: ref.watch(progressRangeProvider)),
);

final weeklyReviewProvider = FutureProvider.autoDispose<WeeklyReview>(
  (ref) => ref.watch(appRepositoryProvider).currentReview(),
);

final calendarMonthProvider = StateProvider<DateTime>(
  (ref) => DateTime(DateTime.now().year, DateTime.now().month),
);

final calendarProvider = FutureProvider.autoDispose((ref) {
  final month = ref.watch(calendarMonthProvider);
  // Pad the range so the grid's leading/trailing days are populated too.
  final from = DateTime(month.year, month.month, 1).subtract(const Duration(days: 7));
  final to = DateTime(month.year, month.month + 1, 0).add(const Duration(days: 7));
  return ref.watch(appRepositoryProvider).range(from, to);
});

final notificationPrefsProvider = FutureProvider.autoDispose<NotificationPreferences>(
  (ref) => ref.watch(appRepositoryProvider).notificationPreferences(),
);

final notificationsProvider =
    FutureProvider.autoDispose<(List<AppNotification>, int)>(
  (ref) => ref.watch(appRepositoryProvider).notifications(),
);

/// Anything that changes an occurrence invalidates every screen that shows one,
/// so a tick on the Today screen is instantly visible on Progress and Calendar.
///
/// Takes the `invalidate` tear-off rather than a Ref, because `Ref` (providers)
/// and `WidgetRef` (widgets) are unrelated types that both expose it.
void _invalidateAll(void Function(ProviderOrFamily) invalidate) {
  invalidate(dashboardProvider);
  invalidate(todayProvider);
  invalidate(goalsProvider);
  invalidate(progressProvider);
  invalidate(calendarProvider);
  invalidate(weeklyReviewProvider);
}

void invalidateProgressData(WidgetRef ref) => _invalidateAll(ref.invalidate);

/// Actions that mutate an occurrence. Kept out of the widgets so no screen
/// contains business logic.
class OccurrenceActions {
  OccurrenceActions(this._ref);
  final Ref _ref;

  Future<void> complete(String id, {int? minutes, String? note}) async {
    await _ref.read(appRepositoryProvider).complete(id, actualMinutes: minutes, note: note);
    _invalidateAll(_ref.invalidate);
  }

  Future<void> skip(String id, {String? note}) async {
    await _ref.read(appRepositoryProvider).skip(id, note: note);
    _invalidateAll(_ref.invalidate);
  }

  Future<void> undo(String id) async {
    await _ref.read(appRepositoryProvider).undo(id);
    _invalidateAll(_ref.invalidate);
  }

  Future<void> reschedule(String id, DateTime date) async {
    await _ref.read(appRepositoryProvider).reschedule(id, date);
    _invalidateAll(_ref.invalidate);
  }
}

final occurrenceActionsProvider = Provider((ref) => OccurrenceActions(ref));
