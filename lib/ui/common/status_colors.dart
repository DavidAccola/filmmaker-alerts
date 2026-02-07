import 'package:flutter/material.dart';
import '../../data/models/status_record.dart';

/// Centralized color definitions for watch status icons.
/// These colors are used consistently across the app for status buttons.
class StatusColors {
  StatusColors._();

  /// Get the color for a specific watch status
  static Color getColor(WatchStatus status, {bool isDark = true}) {
    switch (status) {
      case WatchStatus.wantToWatch:
        // Blue - anticipation, planning, like a bookmark
        return isDark ? const Color(0xFF42A5F5) : const Color(0xFF1976D2);
      case WatchStatus.inProgress:
        // Green - active, ongoing
        return isDark ? const Color(0xFF66BB6A) : const Color(0xFF388E3C);
      case WatchStatus.watched:
        // Light/neutral - completed, done, faded into the background
        return isDark ? const Color(0xFFE0E0E0) : const Color(0xFF616161);
      case WatchStatus.dnf:
        // Dark red - stopped, negative
        return isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828);
    }
  }

  /// Get a faded/inactive version of the status color
  static Color getFadedColor(WatchStatus status, {bool isDark = true}) {
    return getColor(status, isDark: isDark).withValues(alpha: 0.6);
  }

  /// Get a very subtle version for unhovered inactive states
  static Color getSubtleColor(WatchStatus status, {bool isDark = true}) {
    return getColor(status, isDark: isDark).withValues(alpha: 0.15);
  }
}
