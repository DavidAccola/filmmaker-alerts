import 'package:flutter/material.dart';
import '../../data/models/contributor.dart';
import 'multi_select_chip_group.dart';

/// Result from the TvPreferencesDialog containing both preferences and pause state
class TvPreferencesResult {
  final TvNotificationPreferences preferences;
  final bool notificationsPaused;

  TvPreferencesResult({
    required this.preferences,
    required this.notificationsPaused,
  });
}

class TvPreferencesDialog extends StatefulWidget {
  final String workTitle;
  final TvNotificationPreferences initialPreferences;
  final bool initialNotificationsPaused;

  /// When true, saving with high-volume types (Season Premieres, Season Finales,
  /// New Episodes, Specials) selected shows a confirmation dialog warning the
  /// user that this franchise may produce many notifications.
  final bool showHighVolumeWarning;

  const TvPreferencesDialog({
    super.key,
    required this.workTitle,
    required this.initialPreferences,
    this.initialNotificationsPaused = false,
    this.showHighVolumeWarning = false,
  });

  @override
  State<TvPreferencesDialog> createState() => _TvPreferencesDialogState();
}

class _TvPreferencesDialogState extends State<TvPreferencesDialog> {
  late List<String> _selectedTypes;
  late bool _notificationsPaused;
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
                onAllToggled: () {
                  setState(() {
                    final allSelected = _availableTypes.every((t) => _selectedTypes.contains(t));
                    _selectedTypes = allSelected ? [] : List.from(_availableTypes);
                  });
                },
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
              : () => _handleSave(context),
          child: const Text('Save'),
        ),
      ],
    );
  }

  TvPreferencesResult _buildResult() {
    return TvPreferencesResult(
      preferences: TvNotificationPreferences(
        seriesPremiere: _selectedTypes.contains('Series Premiere'),
        seasonPremieres: _selectedTypes.contains('Season Premieres'),
        seasonFinales: _selectedTypes.contains('Season Finales'),
        newEpisodes: _selectedTypes.contains('New Episodes'),
        specials: _selectedTypes.contains('Specials'),
      ),
      notificationsPaused: _notificationsPaused,
    );
  }

  /// High-volume types that warrant a warning for franchise follows.
  static const _highVolumeTypes = [
    'Season Premieres',
    'Season Finales',
    'New Episodes',
    'Specials',
  ];

  Future<void> _handleSave(BuildContext context) async {
    if (widget.showHighVolumeWarning) {
      final initialTypes = widget.initialPreferences.selectedTypes;
      final newlyEnabled = _selectedTypes
          .where((t) => _highVolumeTypes.contains(t) && !initialTypes.contains(t))
          .toList();

      if (newlyEnabled.isNotEmpty) {
        final typeList = newlyEnabled.join(', ');
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('High notification volume'),
            content: Text(
              'This franchise may have many works. Enabling "$typeList" could '
              'result in a large number of notifications. Are you sure?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Enable anyway'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
    }

    if (context.mounted) {
      Navigator.pop(context, _buildResult());
    }
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