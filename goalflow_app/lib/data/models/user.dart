class UserPreferences {
  const UserPreferences({
    this.preferredDays = const [1, 2, 3, 4, 5],
    this.preferredTimeOfDay = 'evening',
    this.preferredStartTime = '19:00',
    this.defaultSessionMinutes = 30,
    this.weeklyTargetActions = 5,
    this.progressStyle = 'percentage',
    this.constraints = const [],
  });

  final List<int> preferredDays;
  final String preferredTimeOfDay;
  final String preferredStartTime;
  final int defaultSessionMinutes;
  final int weeklyTargetActions;
  final String progressStyle;
  final List<String> constraints;

  factory UserPreferences.fromJson(Map<String, dynamic> j) => UserPreferences(
        preferredDays: (j['preferredDays'] as List? ?? const [1, 2, 3, 4, 5])
            .map((e) => e as int)
            .toList(),
        preferredTimeOfDay: j['preferredTimeOfDay'] ?? 'evening',
        preferredStartTime: j['preferredStartTime'] ?? '19:00',
        defaultSessionMinutes: j['defaultSessionMinutes'] ?? 30,
        weeklyTargetActions: j['weeklyTargetActions'] ?? 5,
        progressStyle: j['progressStyle'] ?? 'percentage',
        constraints:
            (j['constraints'] as List? ?? const []).map((e) => e.toString()).toList(),
      );

  Map<String, dynamic> toJson() => {
        'preferredDays': preferredDays,
        'preferredTimeOfDay': preferredTimeOfDay,
        'preferredStartTime': preferredStartTime,
        'defaultSessionMinutes': defaultSessionMinutes,
        'weeklyTargetActions': weeklyTargetActions,
        'progressStyle': progressStyle,
        'constraints': constraints,
      };

  UserPreferences copyWith({
    List<int>? preferredDays,
    String? preferredTimeOfDay,
    String? preferredStartTime,
    int? defaultSessionMinutes,
    int? weeklyTargetActions,
    String? progressStyle,
    List<String>? constraints,
  }) =>
      UserPreferences(
        preferredDays: preferredDays ?? this.preferredDays,
        preferredTimeOfDay: preferredTimeOfDay ?? this.preferredTimeOfDay,
        preferredStartTime: preferredStartTime ?? this.preferredStartTime,
        defaultSessionMinutes: defaultSessionMinutes ?? this.defaultSessionMinutes,
        weeklyTargetActions: weeklyTargetActions ?? this.weeklyTargetActions,
        progressStyle: progressStyle ?? this.progressStyle,
        constraints: constraints ?? this.constraints,
      );
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.pushEnabled,
    required this.emailEnabled,
    required this.remindersEnabled,
    required this.minutesBefore,
    required this.dailySummaryEnabled,
    required this.dailySummaryTime,
    required this.weeklyDigestEnabled,
    required this.weeklyDigestWeekday,
    required this.weeklyDigestTime,
    required this.milestoneAlerts,
    required this.quietHoursEnabled,
    required this.quietStart,
    required this.quietEnd,
  });

  final bool pushEnabled;
  final bool emailEnabled;
  final bool remindersEnabled;
  final int minutesBefore;
  final bool dailySummaryEnabled;
  final String dailySummaryTime;
  final bool weeklyDigestEnabled;
  final int weeklyDigestWeekday;
  final String weeklyDigestTime;
  final bool milestoneAlerts;
  final bool quietHoursEnabled;
  final String quietStart;
  final String quietEnd;

  factory NotificationPreferences.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> sub(String k) =>
        (j[k] as Map?)?.cast<String, dynamic>() ?? const {};
    return NotificationPreferences(
      pushEnabled: j['pushEnabled'] ?? true,
      emailEnabled: j['emailEnabled'] ?? true,
      remindersEnabled: sub('actionReminders')['enabled'] ?? true,
      minutesBefore: sub('actionReminders')['minutesBefore'] ?? 15,
      dailySummaryEnabled: sub('dailySummary')['enabled'] ?? true,
      dailySummaryTime: sub('dailySummary')['time'] ?? '08:00',
      weeklyDigestEnabled: sub('weeklyDigest')['enabled'] ?? true,
      weeklyDigestWeekday: sub('weeklyDigest')['weekday'] ?? 0,
      weeklyDigestTime: sub('weeklyDigest')['time'] ?? '19:00',
      milestoneAlerts: j['milestoneAlerts'] ?? true,
      quietHoursEnabled: sub('quietHours')['enabled'] ?? true,
      quietStart: sub('quietHours')['start'] ?? '22:00',
      quietEnd: sub('quietHours')['end'] ?? '07:00',
    );
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.timezone,
    required this.onboardingCompleted,
    required this.preferences,
    this.avatarUrl,
    this.mainObjective,
    this.emailVerified = false,
  });

  final String id;
  final String name;
  final String email;
  final String timezone;
  final bool onboardingCompleted;
  final UserPreferences preferences;
  final String? avatarUrl;
  final String? mainObjective;
  final bool emailVerified;

  String get firstName => name.split(' ').first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id']?.toString() ?? '',
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        timezone: j['timezone'] ?? 'Asia/Kolkata',
        onboardingCompleted: j['onboardingCompleted'] ?? false,
        preferences: UserPreferences.fromJson(
            (j['preferences'] as Map?)?.cast<String, dynamic>() ?? const {}),
        avatarUrl: j['avatarUrl'],
        mainObjective: j['mainObjective'],
        emailVerified: j['emailVerifiedAt'] != null,
      );

  AppUser copyWith({
    String? name,
    String? avatarUrl,
    String? mainObjective,
    bool? onboardingCompleted,
    UserPreferences? preferences,
  }) =>
      AppUser(
        id: id,
        name: name ?? this.name,
        email: email,
        timezone: timezone,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        preferences: preferences ?? this.preferences,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        mainObjective: mainObjective ?? this.mainObjective,
        emailVerified: emailVerified,
      );
}
