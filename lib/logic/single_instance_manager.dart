import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Manages single-instance enforcement for the application.
/// Prevents multiple instances from running simultaneously.
class SingleInstanceManager {
  static const String _lockFileName = 'filmmaker_alerts.lock';
  static File? _lockFile;

  /// Attempts to acquire a lock for this instance.
  /// Returns true if this is the only instance, false if another instance is already running.
  static Future<bool> acquireLock() async {
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      _lockFile = File('${appSupportDir.path}/$_lockFileName');

      // If lock file exists, try to delete it (it may be stale)
      if (await _lockFile!.exists()) {
        try {
          await _lockFile!.delete();
          debugPrint('[SingleInstance] Cleaned up stale lock file');
        } catch (e) {
          // If we can't delete it, another instance likely has it open
          debugPrint('[SingleInstance] Failed to clean stale lock: $e');
          return false;
        }
      }

      // Try to create the lock file exclusively
      _lockFile = await _lockFile!.create(exclusive: true);
      
      debugPrint('[SingleInstance] Lock acquired successfully');
      return true;
    } catch (e) {
      debugPrint('[SingleInstance] Failed to acquire lock: $e');
      return false;
    }
  }

  /// Releases the lock when the app exits.
  static Future<void> releaseLock() async {
    try {
      if (_lockFile != null && await _lockFile!.exists()) {
        await _lockFile!.delete();
        debugPrint('[SingleInstance] Lock released');
      }
    } catch (e) {
      debugPrint('[SingleInstance] Error releasing lock: $e');
    }
  }
}
