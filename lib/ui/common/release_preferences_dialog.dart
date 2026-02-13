import 'package:flutter/material.dart';
import '../../data/models/watchlist_entry.dart';
import 'multi_select_chip_group.dart';

/// Result from the ReleasePreferencesDialog containing both preferences and pause state
class ReleasePreferencesResult {
  final ReleaseNotificationPreferences preferences;
  final bool notificationsPaused;

  ReleasePreferencesResult({
    required this.preferences,
    required this.notificationsPaused,
  });
}

class ReleasePreferencesDialog extends StatefulWidget {
  final String workTitle;
  final ReleaseNotificationPreferences initialPreferences;
  final bool initialNotificationsPaused;

  const ReleasePreferencesDialog({
    super.key,
    required this.workTitle,
    required this.initialPreferences,
    this.initialNotificationsPaused = false,
  });

  @override
  State<ReleasePreferencesDialog> createState() => _ReleasePreferencesDialogState();
}

class _ReleasePreferencesDialogState extends State<ReleasePreferencesDialog> {
  late List<String> _selectedTypes;
  late bool _notificationsPaused;
  final List<String> _availableTypes = ['Theatrical', 'Streaming', 'Physical', 'TV'];

  @override
  void initState() {
    super.initState();
    _selectedTypes = widget.initialPreferences.selectedTypes;
    _notificationsPaused = widget.initialNotificationsPaused;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: Text('Notification preferences for ${widget.workTitle}'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pause notifications toggle
              SwitchListTile(
                title: const Text('Pause notifications'),
                subtitle: Text(
                  _notificationsPaused 
                      ? 'Notifications are paused' 
                      : 'Notifications are active',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                value: _notificationsPaused,
                onChanged: (value) {
                  setState(() {
                    _notificationsPaused = value;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Choose which release types to get notified about:',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              MultiSelectChipGroup<String>(
                options: _availableTypes,
                selectedValues: _selectedTypes,
                isAllSelected: false, // No "All" option for release types
                allowTrueAll: false,
                labelBuilder: (type) => type,
                onAllToggled: () {}, // Not used since allowTrueAll is false
                onChanged: (newValues) {
                  setState(() {
                    _selectedTypes = newValues;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedTypes.isEmpty
              ? null
              : () {
                  final preferences = ReleaseNotificationPreferences(
                    theatrical: _selectedTypes.contains('Theatrical'),
                    streaming: _selectedTypes.contains('Streaming'),
                    physical: _selectedTypes.contains('Physical'),
                    tv: _selectedTypes.contains('TV'),
                  );
                  Navigator.pop(context, ReleasePreferencesResult(
                    preferences: preferences,
                    notificationsPaused: _notificationsPaused,
                  ));
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}