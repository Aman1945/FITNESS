import 'package:flutter/material.dart';

/// One warm accent on a calm near-white canvas.
/// Deliberately not a "dashboard" palette -- this should feel like a consumer app.
class AppColors {
  const AppColors._();

  static const primary = Color(0xFF5B5BD6);
  static const primaryDark = Color(0xFF8B8BF0);
  static const primarySoft = Color(0xFFEEEEFB);

  static const ink = Color(0xFF16162B);
  static const inkDark = Color(0xFFF2F2F7);

  static const muted = Color(0xFF6B7280);
  static const mutedDark = Color(0xFF9CA3AF);

  static const canvas = Color(0xFFFAFAFC);
  static const canvasDark = Color(0xFF0F0F17);

  static const surface = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF1A1A26);

  static const border = Color(0xFFEDEDF2);
  static const borderDark = Color(0xFF2A2A38);

  // Progress statuses -- each one has a distinct, non-alarming hue.
  static const ahead = Color(0xFF0EA5A4);
  static const onTrack = Color(0xFF10B981);
  static const needsAttention = Color(0xFFF59E0B);
  static const behind = Color(0xFFEF4444);
  static const completed = Color(0xFF6366F1);

  /// Palette offered when creating a goal.
  static const goalPalette = <Color>[
    Color(0xFF5B5BD6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF0EA5A4),
    Color(0xFF8B5CF6),
  ];

  static Color forStatus(String status) => switch (status) {
        'ahead' => ahead,
        'on_track' => onTrack,
        'needs_attention' => needsAttention,
        'behind' => behind,
        'completed' => completed,
        _ => muted,
      };

  static Color forCategory(String category) => switch (category) {
        'health' => const Color(0xFF10B981),
        'learning' => const Color(0xFF5B5BD6),
        'career' => const Color(0xFF0EA5A4),
        'finance' => const Color(0xFFF59E0B),
        'relationships' => const Color(0xFFEC4899),
        'productivity' => const Color(0xFF8B5CF6),
        _ => const Color(0xFF6B7280),
      };
}
