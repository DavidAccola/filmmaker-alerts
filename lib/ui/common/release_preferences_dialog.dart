import 'package:flutter/material.dart';
import '../../data/models/watchlist_entry.dart';
import 'multi_select_chip_group.dart';

class ReleasePreferencesDialog extends StatefulWidget {
  final String workTitle;
  final ReleaseNotificationPreferences initialPreferences;

  const ReleasePreferencesDialog({
    super.key,
    required this.workTitle,
    required this.initialPreferences,
  });

  @override
  State<ReleasePreferencesDialog> createState() => _ReleasePreferencesDialogState();
}

class _ReleasePreferencesDialogState extends State<ReleasePreferencesDialog> {
  late List<String> _selectedTypes;
  final List<String> _availableTypes = ['Theatrical', 'Streaming', 'Physical', 'TV'];

  @override
  void initState() {
    super.initState();
    _selectedTypes = widget.initialPreferences.selectedTypes;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Release notifications for ${widget.workTitle}'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  Navigator.pop(context, preferences);
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}