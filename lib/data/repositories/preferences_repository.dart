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
      return defaults;
    }
    final prefs = _box.getAt(0)!;
    return prefs;
  }

  /// Save updated preferences.
  Future<void> savePreferences(Preferences prefs) async {
    if (_box.isEmpty) {
      await _box.add(prefs);
    } else {
      // Always update the first entry (singleton pattern for prefs)
      await _box.putAt(0, prefs);
    }
    
    // Force flush to disk - ensures data survives hot restart
    await _box.flush();
  }
}