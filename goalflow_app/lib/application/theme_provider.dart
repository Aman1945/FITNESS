import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Appearance choice, persisted across launches.
///
/// Kept in its own controller (not in [AuthNotifier]) because it is a device
/// preference, not account state -- it must survive signing out and must apply
/// before the user has an account at all.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _restore();
  }

  static const _key = 'gf_theme_mode';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = _decode(prefs.getString(_key));
  }

  Future<void> set(ThemeMode mode) async {
    // Paint first, persist after -- the toggle must feel instant.
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _encode(mode));
  }

  /// Cycles System -> Light -> Dark, for a single-tap control.
  Future<void> cycle() => set(switch (state) {
        ThemeMode.system => ThemeMode.light,
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
      });

  static ThemeMode _decode(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier());

extension ThemeModeDisplay on ThemeMode {
  String get label => switch (this) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  String get description => switch (this) {
        ThemeMode.system => 'Follows your device setting',
        ThemeMode.light => 'Always light',
        ThemeMode.dark => 'Always dark',
      };

  IconData get icon => switch (this) {
        ThemeMode.system => Icons.brightness_auto_rounded,
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
      };
}
