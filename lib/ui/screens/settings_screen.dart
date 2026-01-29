import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../data/models/preferences.dart';
import '../../data/models/contributor.dart';
import '../../providers/providers.dart';

import '../common/multi_select_chip_group.dart';
import '../common/snackbar_utils.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _showDebug = false;
  int _debugTapCount = 0;

  Widget _buildAppearanceSection(BuildContext context, WidgetRef ref, Preferences prefs) {
    return _buildCard(
      context,
      title: 'Appearance',
      icon: Icons.palette_outlined,
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Use dark theme'),
            value: prefs.useDarkMode ?? false,
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => _updatePrefs(ref, prefs, useDarkMode: val),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(preferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            _debugTapCount++;
            if (_debugTapCount >= 7) {
              setState(() => _showDebug = !_showDebug);
              _debugTapCount = 0;
              showSimpleSnackBar(context, _showDebug ? 'Debug mode enabled' : 'Debug mode disabled');
            }
          },
          child: const Text('Settings'),
        ),
      ),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (prefs) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 5000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAppearanceSection(context, ref, prefs),
                    const SizedBox(height: 24),
                    _buildReleaseSection(context, ref, prefs),
                    const SizedBox(height: 24),
                    _buildRoleSection(context, ref, prefs),
                    const SizedBox(height: 24),
                    _buildTvSection(context, ref, prefs),
                    const SizedBox(height: 24),
                    _buildSearchSection(context, ref, prefs),
                    const SizedBox(height: 24),
                    _buildStreamingSection(context, ref, prefs),
                    const SizedBox(height: 24),
                    _buildMaintenanceSection(context, ref, prefs),
                    if (_showDebug) ...[
                      const SizedBox(height: 24),
                      _buildDebugSection(context, ref, prefs),
                    ],
                    const SizedBox(height: 40), // Bottom padding for breathing room
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReleaseSection(BuildContext context, WidgetRef ref, Preferences prefs) {
    const options = ['Theatrical', 'Streaming', 'Physical', 'TV Airings'];

    return _buildCard(
      context,
      title: 'Release Notifications',
      icon: Icons.notifications_active_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              'Follow release dates for these formats:',
              style: Theme.of(context).textTheme.bodySmall, // Keep existing style
            ),
          ),
          MultiSelectChipGroup<String>(
            options: options,
            selectedValues: [
              if (prefs.effectiveNotifyTheatre) 'Theatrical',
              if (prefs.effectiveNotifyStreaming) 'Streaming',
              if (prefs.effectiveNotifyPhysical) 'Physical',
              if (prefs.effectiveNotifyTV) 'TV Airings',
            ],
            isAllSelected: prefs.allReleaseTypesSelected ?? false,
            labelBuilder: (val) => val,
            onAllToggled: () {
              final isAll = prefs.allReleaseTypesSelected ?? false;
              if (isAll) {
                _updatePrefs(
                  ref, 
                  prefs,
                  allReleaseTypesSelected: false,
                  notifyTheatre: false,
                  notifyStreaming: false,
                  notifyPhysical: false,
                  notifyTV: false,
                );
              } else {
                _updatePrefs(
                  ref, 
                  prefs,
                  allReleaseTypesSelected: true,
                  notifyTheatre: true,
                  notifyStreaming: true,
                  notifyPhysical: true,
                  notifyTV: true,
                );
              }
            },
            onChanged: (newValues) {
              debugPrint('[SettingsScreen] Release types changed: $newValues');
              debugPrint('[SettingsScreen] TV Airings selected: ${newValues.contains('TV Airings')}');
              debugPrint('[SettingsScreen] Current notifyTV before update: ${prefs.notifyTV}');
              
              _updatePrefs(
                ref, 
                prefs,
                allReleaseTypesSelected: false,
                notifyTheatre: newValues.contains('Theatrical'),
                notifyStreaming: newValues.contains('Streaming'),
                notifyPhysical: newValues.contains('Physical'),
                notifyTV: newValues.contains('TV Airings'),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(),
          ),
          _buildTimeTile(context, ref, prefs),
        ],
      ),
    );
  }

  // ... (NotificationChip helper unused now, can remove if desired, but less churn to leave or remove separately)

  Widget _buildSearchSection(BuildContext context, WidgetRef ref, Preferences prefs) {
    return _buildCard(
      context,
      title: 'Search Settings',
      icon: Icons.search,
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Include Collections in Movie search'),
            subtitle: const Text('Show film series in addition to individual movies'),
            value: prefs.includeCollectionsInMovieSearch,
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => _updatePrefs(ref, prefs, includeCollectionsInMovieSearch: val),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingSection(BuildContext context, WidgetRef ref, Preferences prefs) {
    final countryCode = prefs.streamingCountry ?? 'US';
    final countryName = _getCountryName(countryCode);

    return _buildCard(
      context,
      title: 'Streaming Options',
      icon: Icons.ondemand_video_outlined,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.public),
            title: const Text('Streaming Country'),
            subtitle: Text(countryName),
            trailing: const Icon(Icons.chevron_right),
            dense: true,
            onTap: () => _showCountrySelectionDialog(context, ref, prefs),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your country to see streaming availability from JustWatch',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showCountrySelectionDialog(BuildContext context, WidgetRef ref, Preferences prefs) {
    final countries = _getAvailableCountries();
    final currentCountry = prefs.streamingCountry ?? 'US';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Streaming Country'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: countries.length,
            itemBuilder: (context, index) {
              final entry = countries.entries.elementAt(index);
              final code = entry.key;
              final name = entry.value;

              return RadioListTile<String>(
                title: Text(name),
                value: code,
                groupValue: currentCountry,
                onChanged: (value) {
                  Navigator.of(context).pop();
                  if (value != null) {
                    _updatePrefs(ref, prefs, streamingCountry: value);
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _getCountryName(String countryCode) {
    final countries = _getAvailableCountries();
    return countries[countryCode] ?? countryCode;
  }

  Map<String, String> _getAvailableCountries() {
    // Common countries supported by JustWatch
    return {
      'US': 'United States',
      'GB': 'United Kingdom',
      'CA': 'Canada',
      'AU': 'Australia',
      'DE': 'Germany',
      'FR': 'France',
      'IT': 'Italy',
      'ES': 'Spain',
      'NL': 'Netherlands',
      'SE': 'Sweden',
      'NO': 'Norway',
      'DK': 'Denmark',
      'FI': 'Finland',
      'PL': 'Poland',
      'BR': 'Brazil',
      'MX': 'Mexico',
      'JP': 'Japan',
      'IN': 'India',
      'KR': 'South Korea',
      'SG': 'Singapore',
      'NZ': 'New Zealand',
      'ZA': 'South Africa',
    };
  }

  Widget _buildDebugSection(BuildContext context, WidgetRef ref, Preferences prefs) {
    return _buildCard(
      context,
      title: 'Debugging Tools',
      icon: Icons.bug_report_outlined,
      child: Column(
        children: [
          _buildPretendDateTile(context, ref, prefs),
        ],
      ),
    );
  }

  Widget _buildRoleSection(BuildContext context, WidgetRef ref, Preferences prefs) {
    return _buildCard(
      context,
      title: 'Roles to Follow',
      icon: Icons.person_pin_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              'Choose which roles to follow by default when adding new contributors.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          MultiSelectChipGroup<String>(
            options: AppConstants.departmentPriority,
            selectedValues: prefs.effectiveDefaultDepartments,
            isAllSelected: prefs.allRolesSelected ?? false,
            allowTrueAll: prefs.autoFollowNewRoles ?? true,
            labelBuilder: (role) => role,
            onAllToggled: () {
              final autoFollowEnabled = prefs.autoFollowNewRoles ?? true;
              final isFull = prefs.effectiveDefaultDepartments.length == AppConstants.allDepartments.length;
              
              // If True All is enabled, we track based on the explicit flag.
              // If True All is DISABLED, we track based on whether the list is full.
              final bool shouldDeselect;
              if (autoFollowEnabled) {
                shouldDeselect = prefs.allRolesSelected ?? false;
              } else {
                shouldDeselect = isFull;
              }

              if (shouldDeselect) {
                // Deselect All
                _updatePrefs(
                  ref, 
                  prefs, 
                  defaultDepartments: [],
                  allRolesSelected: false,
                );
              } else {
                // Select All. Flag is only set if feature is ON.
                _updatePrefs(
                  ref, 
                  prefs, 
                  defaultDepartments: List.from(AppConstants.allDepartments),
                  allRolesSelected: autoFollowEnabled,
                );
              }
            },
            onChanged: (newValues) {
              // Individual pill was clicked. 
              // Rule: "If All is NOT marked... then All should stay UNmarked."
              // We never auto-mark "All" just because the list is full.
              _updatePrefs(
                ref, 
                prefs, 
                defaultDepartments: newValues,
                allRolesSelected: false,
              );
            },
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(),
          ),
          // Follow New Roles Toggle
          SwitchListTile(
            title: const Text('Automatically follow new roles when All is marked'),
            subtitle: const Text('If "All" is selected, also follow any future roles added to the database.'),
            value: prefs.autoFollowNewRoles ?? true,
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
               // If turning OFF, we MUST clear the allRolesSelected flag (user said "never is itself marked").
               // If turning ON, we keep whatever it was (it was likely already false or should stay false).
               _updatePrefs(
                 ref, 
                 prefs, 
                 autoFollowNewRoles: val,
                 allRolesSelected: val ? (prefs.allRolesSelected ?? false) : false,
               );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceSection(BuildContext context, WidgetRef ref, Preferences prefs) {
    return _buildCard(
      context,
      title: 'System & Maintenance',
      icon: Icons.settings_outlined,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.movie_outlined),
            title: const Text('Movie Details Preference'),
            subtitle: Text(_getMovieDetailsDescription(prefs.movieDetailsPreference ?? 'both')),
            trailing: const Icon(Icons.chevron_right),
            dense: true,
            onTap: () => _showMovieDetailsDialog(context, ref, prefs),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.refresh_outlined),
            title: const Text('Refresh Contributor Details'),
            subtitle: const Text('Force a full refresh of all filmmaker credits and hits'),
            dense: true,
            onTap: () async {
              try {
                final logic = ref.read(contributorLogicProvider);
                await logic.clearAllContributorDetails();
                
                if (context.mounted) {
                  showSimpleSnackBar(context, 'Detail cache cleared. Entering a contributor screen will now fetch fresh data.');
                }
              } catch (e) {
                if (context.mounted) {
                  showSimpleSnackBar(context, 'Error clearing cache: $e');
                }
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Clear Image Cache'),
            dense: true,
            onTap: () {
              showSimpleSnackBar(context, 'Image cache cleared (Placeholder)');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required String title, required IconData icon, required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }


  Widget _buildTimeTile(BuildContext context, WidgetRef ref, Preferences prefs) {
    return ListTile(
      title: const Text('Daily Notification Time'),
      subtitle: Text(prefs.scheduleTime),
      trailing: const Icon(Icons.access_time),
      dense: true,
      onTap: () async {
        TimeOfDay initialTime = const TimeOfDay(hour: 9, minute: 0);
        try {
          final parts = prefs.scheduleTime.split(':');
          if (parts.length == 2) {
            initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
        } catch (_) {}

        final picked = await showTimePicker(
          context: context,
          initialTime: initialTime,
        );

        if (picked != null) {
          final hour = picked.hour.toString().padLeft(2, '0');
          final minute = picked.minute.toString().padLeft(2, '0');
          _updatePrefs(ref, prefs, scheduleTime: '$hour:$minute');
          
          // Show message about restart requirement
          if (context.mounted) {
            showSimpleSnackBar(
              context,
              'Restart the app for the new notification time to take effect',
              duration: const Duration(seconds: 4),
            );
          }
        }
      },
    );
  }

  Widget _buildPretendDateTile(BuildContext context, WidgetRef ref, Preferences prefs) {
    return ListTile(
      title: const Text('Pretend Today Is (Testing)'),
      subtitle: Text(prefs.pretendToday ?? 'Today'),
      trailing: const Icon(Icons.calendar_today),
      dense: true,
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: now,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          final dateStr = picked.toIso8601String().split('T').first;
          _updatePrefs(ref, prefs, pretendToday: dateStr);
        }
      },
      onLongPress: () {
        _updatePrefs(ref, prefs, pretendToday: null);
        showSimpleSnackBar(context, 'Cleared pretend date');
      },
    );
  }

  Widget _buildTvSection(BuildContext context, WidgetRef ref, Preferences prefs) {
    final defaultTvPrefs = prefs.defaultTvNotificationPrefs ?? TvNotificationPreferences();
    
    return _buildCard(
      context,
      title: 'TV Show Notifications',
      icon: Icons.tv_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              'Default notification preferences for new TV shows.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          CheckboxListTile(
            title: const Text('Series Premiere'),
            subtitle: const Text('First episode of brand new shows'),
            value: defaultTvPrefs.seriesPremiere,
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => _updateTvPrefs(ref, prefs, seriesPremiere: value ?? false),
          ),
          CheckboxListTile(
            title: const Text('Season Premieres'),
            subtitle: const Text('First episode of any season'),
            value: defaultTvPrefs.seasonPremieres,
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => _updateTvPrefs(ref, prefs, seasonPremieres: value ?? false),
          ),
          CheckboxListTile(
            title: const Text('Season Finales'),
            subtitle: const Text('Last episode of any season'),
            value: defaultTvPrefs.seasonFinales,
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => _updateTvPrefs(ref, prefs, seasonFinales: value ?? false),
          ),
          CheckboxListTile(
            title: const Text('New Episodes'),
            subtitle: const Text('All episodes as they air'),
            value: defaultTvPrefs.newEpisodes,
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => _updateTvPrefs(ref, prefs, newEpisodes: value ?? false),
          ),
          CheckboxListTile(
            title: const Text('Specials'),
            subtitle: const Text('Holiday specials and one-offs'),
            value: defaultTvPrefs.specials,
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => _updateTvPrefs(ref, prefs, specials: value ?? false),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(),
          ),
          SwitchListTile(
            title: const Text('Notify when followed people direct TV episodes'),
            subtitle: const Text('Get notifications for TV episodes directed by people you follow'),
            value: prefs.notifyPersonTvEpisodes ?? true,
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => _updatePrefs(ref, prefs, notifyPersonTvEpisodes: val),
          ),
        ],
      ),
    );
  }

  void _updateTvPrefs(WidgetRef ref, Preferences current, {
    bool? seriesPremiere,
    bool? seasonPremieres,
    bool? seasonFinales,
    bool? newEpisodes,
    bool? specials,
  }) {
    final currentTvPrefs = current.defaultTvNotificationPrefs ?? TvNotificationPreferences();
    final newTvPrefs = TvNotificationPreferences(
      seriesPremiere: seriesPremiere ?? currentTvPrefs.seriesPremiere,
      seasonPremieres: seasonPremieres ?? currentTvPrefs.seasonPremieres,
      seasonFinales: seasonFinales ?? currentTvPrefs.seasonFinales,
      newEpisodes: newEpisodes ?? currentTvPrefs.newEpisodes,
      specials: specials ?? currentTvPrefs.specials,
    );
    
    _updatePrefs(ref, current, defaultTvNotificationPrefs: newTvPrefs);
  }

  String _getMovieDetailsDescription(String preference) {
    switch (preference) {
      case 'tmdb':
        return 'Show TMDB buttons only';
      case 'imdb':
        return 'Show IMDb buttons (with TMDB fallback)';
      case 'both':
      default:
        return 'Show both TMDB and IMDb buttons';
    }
  }

  void _showMovieDetailsDialog(BuildContext context, WidgetRef ref, Preferences prefs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Movie Details Preference'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose which movie detail buttons to show:'),
            const SizedBox(height: 16),
            RadioListTile<String>(
              title: const Text('TMDB only'),
              subtitle: const Text('Show only TMDB buttons'),
              value: 'tmdb',
              groupValue: prefs.movieDetailsPreference ?? 'both',
              onChanged: (value) {
                Navigator.of(context).pop();
                _updatePrefs(ref, prefs, movieDetailsPreference: value);
              },
            ),
            RadioListTile<String>(
              title: const Text('IMDb only'),
              subtitle: const Text('Show IMDb buttons with TMDB fallback'),
              value: 'imdb',
              groupValue: prefs.movieDetailsPreference ?? 'both',
              onChanged: (value) {
                Navigator.of(context).pop();
                _updatePrefs(ref, prefs, movieDetailsPreference: value);
              },
            ),
            RadioListTile<String>(
              title: const Text('Both TMDB and IMDb'),
              subtitle: const Text('Show both buttons when available'),
              value: 'both',
              groupValue: prefs.movieDetailsPreference ?? 'both',
              onChanged: (value) {
                Navigator.of(context).pop();
                _updatePrefs(ref, prefs, movieDetailsPreference: value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePrefs(WidgetRef ref, Preferences current, {
    bool? notifyTheatre,
    bool? notifyStreaming,
    bool? notifyPhysical,
    bool? notifyTV,
    String? scheduleTime,
    String? pretendToday,
    bool? includeCollectionsInMovieSearch,
    List<String>? defaultDepartments,
    bool? useGridView,
    bool? allRolesSelected,
    bool? allReleaseTypesSelected,
    bool? autoFollowNewRoles,
    String? movieDetailsPreference,
    TvNotificationPreferences? defaultTvNotificationPrefs,
    bool? notifyPersonTvEpisodes,
    bool? useDarkMode,
    bool? hidePopularityInDetails,
    bool? hideRatingsInDetails,
    String? streamingCountry,
  }) async {
    debugPrint('[SettingsScreen] _updatePrefs called with notifyTV: $notifyTV');
    debugPrint('[SettingsScreen] Current preferences notifyTV: ${current.notifyTV}');
    
    // Create new object with updates
    final newPrefs = Preferences(
      scheduleTime: scheduleTime ?? current.scheduleTime,
      notifyTheatre: notifyTheatre ?? current.notifyTheatre,
      notifyStreaming: notifyStreaming ?? current.notifyStreaming,
      notifyPhysical: notifyPhysical ?? current.notifyPhysical,
      notifyTV: notifyTV ?? current.notifyTV,
      defaultDepartments: defaultDepartments ?? current.defaultDepartments,
      pretendToday: pretendToday ?? current.pretendToday,
      includeCollectionsInMovieSearch: includeCollectionsInMovieSearch ?? current.includeCollectionsInMovieSearch,
      useGridView: useGridView ?? (current.useGridView ?? true),
      allRolesSelected: allRolesSelected ?? current.allRolesSelected,
      allReleaseTypesSelected: allReleaseTypesSelected ?? current.allReleaseTypesSelected,
      autoFollowNewRoles: autoFollowNewRoles ?? current.autoFollowNewRoles,
      lastCheckTime: current.lastCheckTime,
      lastViewedHistoryTime: current.lastViewedHistoryTime,
      movieDetailsPreference: movieDetailsPreference ?? current.movieDetailsPreference,
      defaultTvNotificationPrefs: defaultTvNotificationPrefs ?? current.defaultTvNotificationPrefs,
      notifyPersonTvEpisodes: notifyPersonTvEpisodes ?? current.notifyPersonTvEpisodes,
      useDarkMode: useDarkMode ?? current.useDarkMode,
      hidePopularityInDetails: hidePopularityInDetails ?? current.hidePopularityInDetails,
      hideRatingsInDetails: hideRatingsInDetails ?? current.hideRatingsInDetails,
      streamingCountry: streamingCountry ?? current.streamingCountry,
    );

    debugPrint('[SettingsScreen] New preferences notifyTV: ${newPrefs.notifyTV}');
    debugPrint('[SettingsScreen] Saving preferences...');
    
    await ref.read(preferencesRepositoryProvider).savePreferences(newPrefs);
    
    debugPrint('[SettingsScreen] Preferences saved, invalidating provider...');
    ref.invalidate(preferencesProvider);
    
    // Verify the save worked
    final savedPrefs = ref.read(preferencesRepositoryProvider).getPreferences();
    debugPrint('[SettingsScreen] Verified saved notifyTV: ${savedPrefs.notifyTV}');
  }
}