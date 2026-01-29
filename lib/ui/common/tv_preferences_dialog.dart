import 'package:flutter/material.dart';
import '../../data/models/contributor.dart';
import 'multi_select_chip_group.dart';

class TvPreferencesDialog extends StatefulWidget {
  final String workTitle;
  final TvNotificationPreferences initialPreferences;

  const TvPreferencesDialog({
    super.key,
    required this.workTitle,
    required this.initialPreferences,
  });

  @override
  State<TvPreferencesDialog> createState() => _TvPreferencesDialogState();
}

class _TvPreferencesDialogState extends State<TvPreferencesDialog> {
  late List<String> _selectedTypes;
  final List<String> _availableTypes = [
    'Series Premiere',
    'Season Premieres', 
    'Season Finales',
    'New Episodes',
    'Specials'
  ];

  @override
  void initState() {
    super.initState();
    _selectedTypes = widget.initialPreferences.selectedTypes;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Episode notifications for ${widget.workTitle}'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose which episode types to get notified about:',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              MultiSelectChipGroup<String>(
                options: _availableTypes,
                selectedValues: _selectedTypes,
                isAllSelected: false, // No "All" option for TV types
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
                  final preferences = TvNotificationPreferences(
                    seriesPremiere: _selectedTypes.contains('Series Premiere'),
                    seasonPremieres: _selectedTypes.contains('Season Premieres'),
                    seasonFinales: _selectedTypes.contains('Season Finales'),
                    newEpisodes: _selectedTypes.contains('New Episodes'),
                    specials: _selectedTypes.contains('Specials'),
                  );
                  Navigator.pop(context, preferences);
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

extension TvNotificationPreferencesExtension on TvNotificationPreferences {
  List<String> get selectedTypes {
    final types = <String>[];
    if (seriesPremiere) types.add('Series Premiere');
    if (seasonPremieres) types.add('Season Premieres');
    if (seasonFinales) types.add('Season Finales');
    if (newEpisodes) types.add('New Episodes');
    if (specials) types.add('Specials');
    return types;
  }

  bool get hasAnySelected => seriesPremiere || seasonPremieres || seasonFinales || newEpisodes || specials;
}