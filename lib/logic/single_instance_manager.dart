import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Manages single-instance enforcement for the application.
/// Only active on desktop platforms — Android enforces single-instance at the OS level.
class SingleInstanceManager {
  static const String _lockFileName = 'filmmaker_alerts.lock';
  static File? _lockFile;

  /// Attempts to acquire a lock for this instance.
  /// Returns true if this is the only instance (or if on Android/iOS where it's always true).
  static Future<bool> acquireLock() async {
    // Android/iOS: OS already enforces single-instance — nothing to do.
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      return true;
    }

    try {
      final appSupportDir = await getApplicationSupportDirectory();
      _lockFile = File('${appSupportDir.path}/$_lockFileName');

      // If lock file exists, try to delete it (it may be stale)
      if (await _lockFile!.exists()) {
        try {
          await _lockFile!.delete();
        } catch (e) {
          // If we can't delete it, another instance likely has it open
          return false;
        }
      }

      // Try to create the lock file exclusively
      _lockFile = await _lockFile!.create(exclusive: true);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Releases the lock when the app exits.
  static Future<void> releaseLock() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      return; // No lock to release on mobile
    }
    try {
      if (_lockFile != null && await _lockFile!.exists()) {
        await _lockFile!.delete();
      }
    } catch (e) {
    }
  }
}
