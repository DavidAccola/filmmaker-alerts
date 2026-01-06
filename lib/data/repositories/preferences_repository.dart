import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants.dart';
import '../models/preferences.dart';

class PreferencesRepository {
  Box<Preferences> get _box => Hive.box<Preferences>(AppConstants.preferencesBox);

  /// Get current preferences.
  /// If no preferences exist, it creates and returns the default set.
  Preferences getPreferences() {
    if (_box.isEmpty) {
      // Return defaults defined in the model constructor
      final defaults = Preferences();
      // We don't necessarily need to save them immediately, 
      // but saving ensures the box isn't empty next time.
      _box.add(defaults); 
      debugPrint('[PreferencesRepository] Created default preferences with notifyTV: ${defaults.notifyTV}');
      return defaults;
    }
    final prefs = _box.getAt(0)!;
    debugPrint('[PreferencesRepository] Loaded preferences with notifyTV: ${prefs.notifyTV}');
    return prefs;
  }

  /// Save updated preferences.
  Future<void> savePreferences(Preferences prefs) async {
    debugPrint('[PreferencesRepository] Saving preferences with notifyTV: ${prefs.notifyTV}');
    
    if (_box.isEmpty) {
      await _box.add(prefs);
      debugPrint('[PreferencesRepository] Added new preferences to empty box');
    } else {
      // Always update the first entry (singleton pattern for prefs)
      await _box.putAt(0, prefs);
      debugPrint('[PreferencesRepository] Updated preferences at index 0');
    }
    
    // Verify the save
    final savedPrefs = _box.getAt(0)!;
    debugPrint('[PreferencesRepository] Verified saved notifyTV: ${savedPrefs.notifyTV}');
  }
}