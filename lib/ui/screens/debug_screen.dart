import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../providers/providers.dart';
import '../../logic/notification_logic.dart';
import '../../data/models/preferences.dart';
import '../../data/models/contributor.dart'; // For TvNotificationPreferences
import '../../data/models/contributor_detail.dart'; // For WorkType
import '../../data/models/watchlist_entry.dart'; // For ReleaseNotificationPreferences
import 'package:flutter/services.dart';
import '../common/snackbar_utils.dart';

class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationService = ref.read(notificationServiceProvider);
    final preferencesAsync = ref.watch(preferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug - Notification Test'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            const Text(
              'Windows Notification Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              'Platform: ${Platform.operatingSystem}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              'Is Windows: ${Platform.isWindows}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            
            // Pretend Today Date Picker
            preferencesAsync.when(
              data: (prefs) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Testing Date Override',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        title: const Text('Pretend Today Is'),
                        subtitle: Text(prefs.pretendToday ?? 'Today (${DateTime.now().toIso8601String().split('T').first})'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: prefs.pretendToday != null 
                                ? DateTime.parse(prefs.pretendToday!) 
                                : DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            final dateStr = picked.toIso8601String().split('T').first;
                            await _updatePrefs(ref, prefs, pretendToday: dateStr);
                          }
                        },
                        onLongPress: () async {
                          await _updatePrefs(ref, prefs, pretendToday: null);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cleared pretend date - using real date')),
                            );
                          }
                        },
                      ),
                      const Text(
                        'Tap to set date, long press to clear',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      if (prefs.lastCheckTime != null && prefs.lastCheckTime!.isNotEmpty)
                        Text(
                          'Last check: ${prefs.lastCheckTime}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error loading preferences: $error'),
            ),
            
            const SizedBox(height: 20),
            
            // Notification Timing Debug Section
            preferencesAsync.when(
              data: (prefs) => _buildNotificationTimingCard(context, ref, prefs),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error loading preferences: $error'),
            ),
            
            const SizedBox(height: 20),
            
            // Watchlist Migration Section
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Watchlist Migration (Phase 8)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Migrate movie/TV show/collection contributors to watchlist',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              final migrationLogic = ref.read(watchlistMigrationLogicProvider);
                              final stats = await migrationLogic.migrateContributorsToWatchlist();
                              
                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Migration Results'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Total media contributors: ${stats['total']}'),
                                        Text('Migrated: ${stats['migrated']}'),
                                        Text('Skipped (already in watchlist): ${stats['skipped']}'),
                                        Text('Errors: ${stats['errors']}'),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Migration error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Migrate'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              final migrationLogic = ref.read(watchlistMigrationLogicProvider);
                              final validation = await migrationLogic.validateMigration();
                              
                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Validation Results'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Media contributors: ${validation['totalMediaContributors']}'),
                                        Text('In watchlist: ${validation['contributorsInWatchlist']}'),
                                        Text('Orphaned: ${validation['orphanedContributors']}'),
                                        Text('Watchlist entries: ${validation['totalWatchlistEntries']}'),
                                        Text('Consistent: ${validation['isConsistent']}'),
                                        if (validation['orphanedNames'].isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          const Text('Orphaned items:', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ...validation['orphanedNames'].map<Widget>((name) => Text('• $name')),
                                        ],
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Validation error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Validate'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            // Show confirmation dialog
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirm Cleanup'),
                                content: const Text(
                                  'This will permanently remove movie/TV show/collection contributors '
                                  'that have been migrated to watchlist. This action cannot be undone.\n\n'
                                  'Make sure to run validation first!'
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('Cleanup'),
                                  ),
                                ],
                              ),
                            );
                            
                            if (confirmed == true) {
                              try {
                                final migrationLogic = ref.read(watchlistMigrationLogicProvider);
                                final removed = await migrationLogic.cleanupMigratedContributors();
                                
                                // Refresh contributors provider
                                ref.invalidate(contributorsProvider);
                                
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Cleanup complete: removed $removed contributors'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Cleanup error: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Cleanup'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            const Text(
              'Click the buttons below to test notifications.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  debugPrint('Attempting to send test notification...');
                  await notificationService.showTestNotification();
                  debugPrint('Test notification sent successfully');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Test notification sent! Check your system notifications.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e, stackTrace) {
                  debugPrint('Error sending notification: $e');
                  debugPrint('Stack trace: $stackTrace');
                  if (context.mounted) {
                    String message = 'Error sending notification: $e';
                    Color color = Colors.red;
                    
                    if (e is UnsupportedError && e.message?.contains('Windows') == true) {
                      message = 'Windows notifications are not supported by Flutter plugins yet';
                      color = Colors.orange;
                    }
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: color,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.notifications),
              label: const Text('Send Test Notification'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  debugPrint('Testing direct notification service initialization...');
                  await notificationService.init();
                  debugPrint('Notification service initialized successfully');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notification service initialized successfully!'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                } catch (e, stackTrace) {
                  debugPrint('Error initializing notification service: $e');
                  debugPrint('Stack trace: $stackTrace');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error initializing: $e'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.settings),
              label: const Text('Test Initialization Only'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  debugPrint('Triggering real notification check...');
                  
                  // Get the release checker
                  final releaseChecker = ref.read(releaseCheckerProvider);
                  final notificationService = ref.read(notificationServiceProvider);
                  final movieCacheRepo = ref.read(movieCacheRepositoryProvider);
                  final historyRepo = ref.read(historyRepositoryProvider);
                  
                  // DEBUG: Check preferences
                  final prefsRepo = ref.read(preferencesRepositoryProvider);
                  final currentPrefs = prefsRepo.getPreferences();
                  debugPrint('[DebugScreen] DEBUG: TV notifications enabled: ${currentPrefs.effectiveNotifyTV}');
                  debugPrint('[DebugScreen] DEBUG: notifyTV: ${currentPrefs.notifyTV}');
                  debugPrint('[DebugScreen] DEBUG: allReleaseTypesSelected: ${currentPrefs.allReleaseTypesSelected}');
                  debugPrint('[DebugScreen] DEBUG: pretendToday: ${currentPrefs.pretendToday}');
                  
                  // Run the actual release check
                  final newReleases = await releaseChecker.findNewReleases();
                  
                  // Update last check time (like the real background service does)
                  debugPrint('[DebugScreen] DEBUG: Before updating preferences - notifyTV: ${currentPrefs.notifyTV}');
                  debugPrint('[DebugScreen] DEBUG: Before updating preferences - defaultTvNotificationPrefs: ${currentPrefs.defaultTvNotificationPrefs}');
                  debugPrint('[DebugScreen] DEBUG: Before updating preferences - notifyPersonTvEpisodes: ${currentPrefs.notifyPersonTvEpisodes}');
                  
                  final updatedPrefs = Preferences(
                    notifyTheatre: currentPrefs.notifyTheatre,
                    notifyStreaming: currentPrefs.notifyStreaming,
                    scheduleTime: currentPrefs.scheduleTime,
                    defaultDepartments: currentPrefs.defaultDepartments,
                    notifyPhysical: currentPrefs.notifyPhysical,
                    notifyTV: currentPrefs.notifyTV,
                    pretendToday: currentPrefs.pretendToday,
                    includeCollectionsInMovieSearch: currentPrefs.includeCollectionsInMovieSearch,
                    useGridView: currentPrefs.useGridView,
                    homeSortOrder: currentPrefs.homeSortOrder,
                    groupByType: currentPrefs.groupByType,
                    allRolesSelected: currentPrefs.allRolesSelected,
                    allReleaseTypesSelected: currentPrefs.allReleaseTypesSelected,
                    autoFollowNewRoles: currentPrefs.autoFollowNewRoles,
                    lastCheckTime: DateTime.now().toIso8601String(),
                    lastViewedHistoryTime: currentPrefs.lastViewedHistoryTime, // MISSING!
                    movieDetailsPreference: currentPrefs.movieDetailsPreference, // MISSING!
                    defaultTvNotificationPrefs: currentPrefs.defaultTvNotificationPrefs, // MISSING!
                    notifyPersonTvEpisodes: currentPrefs.notifyPersonTvEpisodes, // MISSING!
                  );
                  
                  debugPrint('[DebugScreen] DEBUG: After creating updated preferences - notifyTV: ${updatedPrefs.notifyTV}');
                  debugPrint('[DebugScreen] DEBUG: After creating updated preferences - defaultTvNotificationPrefs: ${updatedPrefs.defaultTvNotificationPrefs}');
                  debugPrint('[DebugScreen] DEBUG: After creating updated preferences - notifyPersonTvEpisodes: ${updatedPrefs.notifyPersonTvEpisodes}');
                  
                  await prefsRepo.savePreferences(updatedPrefs);
                  ref.invalidate(preferencesProvider);
                  
                  // Verify the save worked
                  final verifyPrefs = prefsRepo.getPreferences();
                  debugPrint('[DebugScreen] DEBUG: After saving - verified notifyTV: ${verifyPrefs.notifyTV}');
                  debugPrint('[DebugScreen] DEBUG: After saving - verified defaultTvNotificationPrefs: ${verifyPrefs.defaultTvNotificationPrefs}');
                  debugPrint('[DebugScreen] DEBUG: After saving - verified notifyPersonTvEpisodes: ${verifyPrefs.notifyPersonTvEpisodes}');
                  
                  if (newReleases.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No new releases found. Try adding some contributors first!'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                    return;
                  }
                  
                  debugPrint('Found ${newReleases.length} new releases');
                  
                  // Add to history (like the real background service does)
                  for (final release in newReleases) {
                    await historyRepo.addNotificationToHistory(release);
                  }
                  
                  // Refresh the history provider to ensure UI updates
                  ref.invalidate(historyProvider);
                  
                  // Get movie titles for notification
                  final movieTitles = <String>[];
                  for (final release in newReleases) {
                    String? title;
                    if (release.mediaType == 'tv') {
                      // Get TV show title from TV cache
                      final tvCacheRepo = ref.read(tvCacheRepositoryProvider);
                      final tvShow = tvCacheRepo.getShow(release.tmdbId);
                      title = tvShow?.name;
                      debugPrint('[DebugScreen] TV show lookup: tmdbId=${release.tmdbId}, found=${tvShow != null}, title="$title"');
                    } else {
                      // Get movie title from movie cache
                      final movie = movieCacheRepo.getMovie(release.tmdbId);
                      title = movie?.title;
                      debugPrint('[DebugScreen] Movie lookup: tmdbId=${release.tmdbId}, found=${movie != null}, title="$title"');
                    }
                    
                    if (title != null) {
                      movieTitles.add(title);
                    }
                  }
                  
                  if (movieTitles.isNotEmpty) {
                    // Format notification using real logic
                    final title = NotificationLogic.formatTitle(movieTitles, entries: newReleases);
                    final body = NotificationLogic.formatBody(movieTitles, newReleases,
                      getMoviePosterPath: (tmdbId) {
                        // Handle both movies and TV shows
                        final release = newReleases.firstWhere((r) => r.tmdbId == tmdbId, orElse: () => newReleases.first);
                        if (release.mediaType == 'tv') {
                          final tvCacheRepo = ref.read(tvCacheRepositoryProvider);
                          final tvShow = tvCacheRepo.getShow(tmdbId);
                          return tvShow?.posterPath;
                        } else {
                          return movieCacheRepo.getMovie(tmdbId)?.posterPath;
                        }
                      });
                    
                    // Always use history payload for debug notifications
                    String payload = 'app://history';
                    
                    // Image Logic: Collect up to 4 poster images from the releases
                    List<String> imagePaths = [];
                    for (int i = 0; i < newReleases.length && i < 4; i++) {
                      final release = newReleases[i];
                      String? posterPath;
                      
                      if (release.mediaType == 'tv') {
                        // For TV shows, get series poster
                        final tvCacheRepo = ref.read(tvCacheRepositoryProvider);
                        final tvShow = tvCacheRepo.getShow(release.tmdbId);
                        posterPath = tvShow?.posterPath;
                      } else {
                        // For movies, get movie poster
                        final movie = movieCacheRepo.getMovie(release.tmdbId);
                        posterPath = movie?.posterPath;
                      }
                      
                      if (posterPath != null && posterPath.isNotEmpty) {
                        // Convert TMDB poster path to full URL
                        imagePaths.add('https://image.tmdb.org/t/p/w200$posterPath');
                      }
                    }
                    
                    // Get priority-based release dates for 2-3 movie notifications
                    List<String>? releaseDates;
                    if (newReleases.length >= 2 && newReleases.length <= 3) {
                      releaseDates = NotificationLogic.getPriorityReleaseDates(movieTitles, newReleases);
                    }
                    
                    // Send the real notification
                    await notificationService.showNotification(
                      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                      title: title,
                      body: body,
                      payload: payload,
                      imagePaths: imagePaths.isNotEmpty ? imagePaths : null,
                      releaseDates: releaseDates,
                      totalMovieCount: newReleases.length,
                    );
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Real notification sent! Found ${newReleases.length} new release(s)'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                } catch (e, stackTrace) {
                  debugPrint('Error triggering real notification: $e');
                  debugPrint('Stack trace: $stackTrace');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.movie),
              label: const Text('Trigger Real Notification'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  debugPrint('[DebugScreen] DEBUG: Clearing notification history...');
                  final historyRepo = ref.read(historyRepositoryProvider);
                  await historyRepo.clearAllHistory();
                  ref.invalidate(historyProvider);
                  debugPrint('[DebugScreen] DEBUG: Notification history cleared successfully');
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notification history cleared! You can now re-test notifications.'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Error clearing history: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error clearing history: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Notification History'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  // await DebugLogger.instance.init();
                  final logPath = 'Debug log not available';
                  final logContent = 'Debug logging is temporarily disabled';
                  
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Debug Log'),
                        content: SizedBox(
                          width: double.maxFinite,
                          height: 400,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Log file: $logPath', 
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: SelectableText(
                                    logContent,
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: logContent));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Log copied to clipboard')),
                                );
                              }
                            },
                            child: const Text('Copy'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error reading log: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.bug_report),
              label: const Text('View Debug Log'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  // final crashLogs = DebugLogger.instance.getCrashLogs();
                  // final crashLogsPath = await DebugLogger.instance.getCrashLogsPath();
                  final crashLogs = <dynamic>[];
                  final crashLogsPath = 'Crash logs not available';
                  
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Crash Logs'),
                        content: SizedBox(
                          width: double.maxFinite,
                          height: 400,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Location: $crashLogsPath', 
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('Total crashes: ${crashLogs.length}',
                                style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 10),
                              if (crashLogs.isEmpty)
                                const Expanded(
                                  child: Center(
                                    child: Text('No crashes recorded', style: TextStyle(color: Colors.grey)),
                                  ),
                                )
                              else
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      crashLogs.map((log) => log.toString()).join('\n'),
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        actions: [
                          if (crashLogs.isNotEmpty)
                            TextButton(
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(
                                  text: crashLogs.map((log) => log.toString()).join('\n'),
                                ));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Crash logs copied to clipboard')),
                                  );
                                }
                              },
                              child: const Text('Copy'),
                            ),
                          if (crashLogs.isNotEmpty)
                            TextButton(
                              onPressed: () async {
                                // await DebugLogger.instance.clearCrashLogs();
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Crash logs cleared')),
                                  );
                                }
                              },
                              child: const Text('Clear', style: TextStyle(color: Colors.red)),
                            ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error reading crash logs: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.warning),
              label: const Text('View Crash Logs'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  // final perfLogs = DebugLogger.instance.getPerformanceLogs();
                  // final perfLogsPath = await DebugLogger.instance.getPerformanceLogsPath();
                  final perfLogs = <dynamic>[];
                  final perfLogsPath = 'Performance logs not available';
                  
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Performance Logs'),
                        content: SizedBox(
                          width: double.maxFinite,
                          height: 400,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Location: $perfLogsPath', 
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('Total events: ${perfLogs.length}',
                                style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 10),
                              if (perfLogs.isEmpty)
                                const Expanded(
                                  child: Center(
                                    child: Text('No performance issues recorded', style: TextStyle(color: Colors.grey)),
                                  ),
                                )
                              else
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      perfLogs.map((log) => log.toString()).join('\n'),
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        actions: [
                          if (perfLogs.isNotEmpty)
                            TextButton(
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(
                                  text: perfLogs.map((log) => log.toString()).join('\n'),
                                ));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Performance logs copied to clipboard')),
                                  );
                                }
                              },
                              child: const Text('Copy'),
                            ),
                          if (perfLogs.isNotEmpty)
                            TextButton(
                              onPressed: () async {
                                // await DebugLogger.instance.clearPerformanceLogs();
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Performance logs cleared')),
                                  );
                                }
                              },
                              child: const Text('Clear', style: TextStyle(color: Colors.red)),
                            ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error reading performance logs: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.speed),
              label: const Text('View Performance Logs'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  // final freezes = DebugLogger.instance.getFreezes();
                  final freezes = <dynamic>[];
                  
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Freeze Events'),
                        content: SizedBox(
                          width: double.maxFinite,
                          height: 400,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total freezes: ${freezes.length}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              if (freezes.isEmpty)
                                const Expanded(
                                  child: Center(
                                    child: Text('No freezes recorded', style: TextStyle(color: Colors.grey)),
                                  ),
                                )
                              else
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      freezes.map((log) => log.toString()).join('\n'),
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        actions: [
                          if (freezes.isNotEmpty)
                            TextButton(
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(
                                  text: freezes.map((log) => log.toString()).join('\n'),
                                ));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Freeze logs copied to clipboard')),
                                  );
                                }
                              },
                              child: const Text('Copy'),
                            ),
                          if (freezes.isNotEmpty)
                            TextButton(
                              onPressed: () async {
                                // await DebugLogger.instance.clearPerformanceLogs();
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Freeze logs cleared')),
                                  );
                                }
                              },
                              child: const Text('Clear', style: TextStyle(color: Colors.red)),
                            ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error reading freeze logs: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.pause_circle),
              label: const Text('View Freezes'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Testing Windows notifications using the windows_notification package. '
              'The "Trigger Real Notification" button runs the actual release checker and sends '
              'properly formatted notifications like the background service would.\n\n'
              'Release checking logic:\n'
              '• Debug mode (future pretend date): checks from real today to pretend date\n'
              '• Normal mode: checks from last check time to now (or 7 days if first time)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildNotificationTimingCard(BuildContext context, WidgetRef ref, Preferences prefs) {
    final now = DateTime.now();
    
    // Parse scheduled time
    int scheduleHour = 9;
    int scheduleMinute = 0;
    try {
      final parts = prefs.scheduleTime.split(':');
      if (parts.length == 2) {
        scheduleHour = int.parse(parts[0]);
        scheduleMinute = int.parse(parts[1]);
      }
    } catch (_) {}
    
    // Get today's scheduled time
    final todayScheduled = DateTime(now.year, now.month, now.day, scheduleHour, scheduleMinute);
    
    // Determine status
    String status = '';
    Color statusColor = Colors.grey;
    bool hasTriggered = false;
    
    if (prefs.lastCheckTime != null && prefs.lastCheckTime!.isNotEmpty) {
      try {
        final lastCheck = DateTime.parse(prefs.lastCheckTime!);
        if (lastCheck.isAfter(todayScheduled)) {
          status = '✓ Already triggered today';
          statusColor = Colors.green;
          hasTriggered = true;
        } else if (now.isAfter(todayScheduled)) {
          status = '⚠ Passed scheduled time (will trigger on next app start)';
          statusColor = Colors.orange;
        } else {
          status = '○ Waiting for scheduled time';
          statusColor = Colors.grey;
        }
      } catch (_) {
        status = '○ Waiting for scheduled time';
        statusColor = Colors.grey;
      }
    } else {
      if (now.isAfter(todayScheduled)) {
        status = '⚠ Passed scheduled time (will trigger on next app start)';
        statusColor = Colors.orange;
      } else {
        status = '○ Waiting for scheduled time';
        statusColor = Colors.grey;
      }
    }
    
    // Calculate next check time
    DateTime nextCheck;
    if (now.isBefore(todayScheduled)) {
      nextCheck = todayScheduled;
    } else {
      nextCheck = todayScheduled.add(const Duration(days: 1));
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Notification Timing Debug',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scheduled Time: ${scheduleHour.toString().padLeft(2, '0')}:${scheduleMinute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Current Time: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Last Check: ${prefs.lastCheckTime != null && prefs.lastCheckTime!.isNotEmpty ? prefs.lastCheckTime : 'Never'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showLastCheckTimeDialog(context, ref, prefs),
                            icon: const Icon(Icons.edit, size: 16),
                            tooltip: 'Edit Last Check Time',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Next Check: ${nextCheck.hour.toString().padLeft(2, '0')}:${nextCheck.minute.toString().padLeft(2, '0')} (${nextCheck.toIso8601String().split('T').first})',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              status,
                              style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (hasTriggered)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Reset the last check time
                        final newPrefs = Preferences(
                          notifyTheatre: prefs.notifyTheatre,
                          notifyStreaming: prefs.notifyStreaming,
                          scheduleTime: prefs.scheduleTime,
                          defaultDepartments: prefs.defaultDepartments,
                          notifyPhysical: prefs.notifyPhysical,
                          notifyTV: prefs.notifyTV,
                          pretendToday: prefs.pretendToday,
                          includeCollectionsInMovieSearch: prefs.includeCollectionsInMovieSearch,
                          useGridView: prefs.useGridView,
                          homeSortOrder: prefs.homeSortOrder,
                          groupByType: prefs.groupByType,
                          allRolesSelected: prefs.allRolesSelected,
                          allReleaseTypesSelected: prefs.allReleaseTypesSelected,
                          autoFollowNewRoles: prefs.autoFollowNewRoles,
                          lastCheckTime: null, // Reset
                          lastViewedHistoryTime: prefs.lastViewedHistoryTime,
                          movieDetailsPreference: prefs.movieDetailsPreference,
                          defaultTvNotificationPrefs: prefs.defaultTvNotificationPrefs,
                          notifyPersonTvEpisodes: prefs.notifyPersonTvEpisodes,
                        );
                        
                        await ref.read(preferencesRepositoryProvider).savePreferences(newPrefs);
                        ref.invalidate(preferencesProvider);
                        
                        if (context.mounted) {
                          showSimpleSnackBar(
                            context,
                            'Check time reset - notification will trigger on next scheduled time',
                            duration: const Duration(seconds: 3),
                          );
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset Check Time'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (hasTriggered) const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showLastCheckTimeDialog(context, ref, prefs),
                    icon: const Icon(Icons.schedule),
                    label: const Text('Set Check Time'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Force missed check button - always visible for quick testing
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Set last check time to yesterday AND set scheduled time to 1 hour ago
                  // This guarantees a "missed check" scenario regardless of current scheduled time
                  final now = DateTime.now();
                  final oneHourAgo = now.subtract(const Duration(hours: 1));
                  final yesterday = now.subtract(const Duration(days: 1));
                  
                  final newPrefs = Preferences(
                    notifyTheatre: prefs.notifyTheatre,
                    notifyStreaming: prefs.notifyStreaming,
                    scheduleTime: '${oneHourAgo.hour.toString().padLeft(2, '0')}:${oneHourAgo.minute.toString().padLeft(2, '0')}', // Set to 1 hour ago
                    defaultDepartments: prefs.defaultDepartments,
                    notifyPhysical: prefs.notifyPhysical,
                    notifyTV: prefs.notifyTV,
                    pretendToday: prefs.pretendToday,
                    includeCollectionsInMovieSearch: prefs.includeCollectionsInMovieSearch,
                    useGridView: prefs.useGridView,
                    homeSortOrder: prefs.homeSortOrder,
                    groupByType: prefs.groupByType,
                    allRolesSelected: prefs.allRolesSelected,
                    allReleaseTypesSelected: prefs.allReleaseTypesSelected,
                    autoFollowNewRoles: prefs.autoFollowNewRoles,
                    lastCheckTime: yesterday.toIso8601String(), // Set to yesterday
                    lastViewedHistoryTime: prefs.lastViewedHistoryTime,
                    movieDetailsPreference: prefs.movieDetailsPreference,
                    defaultTvNotificationPrefs: prefs.defaultTvNotificationPrefs,
                    notifyPersonTvEpisodes: prefs.notifyPersonTvEpisodes,
                  );
                  
                  await ref.read(preferencesRepositoryProvider).savePreferences(newPrefs);
                  ref.invalidate(preferencesProvider);
                  
                  if (context.mounted) {
                    showSimpleSnackBar(
                      context,
                      'Forced missed check: scheduled time set to 1 hour ago, last check to yesterday',
                      duration: const Duration(seconds: 4),
                    );
                  }
                },
                icon: const Icon(Icons.warning),
                label: const Text('Force Missed Check (Guaranteed)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Database Export button for debugging
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _exportDatabaseInfo(context, ref),
                icon: const Icon(Icons.download),
                label: const Text('Export DB Info (Watchlist & Preferences)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Fix NULL preferences button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _fixNullPreferences(context, ref),
                icon: const Icon(Icons.build),
                label: const Text('Fix NULL Preferences (Apply Defaults)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Export History/Notification Reasons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _exportHistoryInfo(context, ref),
                icon: const Icon(Icons.history),
                label: const Text('Export History (Notification Reasons)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePrefs(WidgetRef ref, Preferences current, {
    String? pretendToday,
  }) async {
    final newPrefs = Preferences(
      notifyTheatre: current.notifyTheatre,
      notifyStreaming: current.notifyStreaming,
      scheduleTime: current.scheduleTime,
      defaultDepartments: current.defaultDepartments,
      notifyPhysical: current.notifyPhysical,
      notifyTV: current.notifyTV,
      pretendToday: pretendToday ?? current.pretendToday,
      includeCollectionsInMovieSearch: current.includeCollectionsInMovieSearch,
      useGridView: current.useGridView,
      homeSortOrder: current.homeSortOrder,
      groupByType: current.groupByType,
      allRolesSelected: current.allRolesSelected,
      allReleaseTypesSelected: current.allReleaseTypesSelected,
      autoFollowNewRoles: current.autoFollowNewRoles,
      lastCheckTime: current.lastCheckTime,
      lastViewedHistoryTime: current.lastViewedHistoryTime,
      movieDetailsPreference: current.movieDetailsPreference,
      defaultTvNotificationPrefs: current.defaultTvNotificationPrefs,
      notifyPersonTvEpisodes: current.notifyPersonTvEpisodes,
    );

    await ref.read(preferencesRepositoryProvider).savePreferences(newPrefs);
    ref.invalidate(preferencesProvider);
  }

  Future<void> _showLastCheckTimeDialog(BuildContext context, WidgetRef ref, Preferences prefs) async {
    DateTime? selectedDateTime;
    
    // Parse current last check time if it exists
    if (prefs.lastCheckTime != null && prefs.lastCheckTime!.isNotEmpty) {
      try {
        selectedDateTime = DateTime.parse(prefs.lastCheckTime!);
      } catch (e) {
        selectedDateTime = DateTime.now().subtract(const Duration(hours: 1));
      }
    } else {
      selectedDateTime = DateTime.now().subtract(const Duration(hours: 1));
    }

    final result = await showDialog<DateTime>(
      context: context,
      builder: (context) => _LastCheckTimeDialog(initialDateTime: selectedDateTime!),
    );

    if (result != null) {
      final newPrefs = Preferences(
        notifyTheatre: prefs.notifyTheatre,
        notifyStreaming: prefs.notifyStreaming,
        scheduleTime: prefs.scheduleTime,
        defaultDepartments: prefs.defaultDepartments,
        notifyPhysical: prefs.notifyPhysical,
        notifyTV: prefs.notifyTV,
        pretendToday: prefs.pretendToday,
        includeCollectionsInMovieSearch: prefs.includeCollectionsInMovieSearch,
        useGridView: prefs.useGridView,
        homeSortOrder: prefs.homeSortOrder,
        groupByType: prefs.groupByType,
        allRolesSelected: prefs.allRolesSelected,
        allReleaseTypesSelected: prefs.allReleaseTypesSelected,
        autoFollowNewRoles: prefs.autoFollowNewRoles,
        lastCheckTime: result.toIso8601String(),
        lastViewedHistoryTime: prefs.lastViewedHistoryTime,
        movieDetailsPreference: prefs.movieDetailsPreference,
        defaultTvNotificationPrefs: prefs.defaultTvNotificationPrefs,
        notifyPersonTvEpisodes: prefs.notifyPersonTvEpisodes,
      );
      
      await ref.read(preferencesRepositoryProvider).savePreferences(newPrefs);
      ref.invalidate(preferencesProvider);
      
      if (context.mounted) {
        showSimpleSnackBar(
          context,
          'Last check time updated to ${result.toIso8601String()}',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _exportDatabaseInfo(BuildContext context, WidgetRef ref) async {
    try {
      final watchlistRepo = ref.read(watchlistRepositoryProvider);
      final prefsRepo = ref.read(preferencesRepositoryProvider);
      
      final watchlistEntries = watchlistRepo.getWorks();
      final prefs = prefsRepo.getPreferences();
      
      // Build export string
      final buffer = StringBuffer();
      buffer.writeln('=== WATCHLIST EXPORT ===');
      buffer.writeln('Total entries: ${watchlistEntries.length}');
      buffer.writeln('');
      
      for (final entry in watchlistEntries) {
        buffer.writeln('Title: ${entry.title}');
        buffer.writeln('  Type: ${entry.type}');
        buffer.writeln('  TMDB ID: ${entry.tmdbId}');
        buffer.writeln('  Release Date: ${entry.releaseDate}');
        buffer.writeln('  Release Type: ${entry.releaseType}');
        buffer.writeln('  Added At: ${entry.addedAt}');
        
        // Show what's actually in the database
        buffer.writeln('  [DB] Release Notification Prefs object: ${entry.releaseNotificationPrefs}');
        
        if (entry.releaseNotificationPrefs != null) {
          buffer.writeln('  [DB] Release Notification Prefs (from object):');
          buffer.writeln('    Theatrical: ${entry.releaseNotificationPrefs!.theatrical}');
          buffer.writeln('    Streaming: ${entry.releaseNotificationPrefs!.streaming}');
          buffer.writeln('    Physical: ${entry.releaseNotificationPrefs!.physical}');
          buffer.writeln('    TV: ${entry.releaseNotificationPrefs!.tv}');
          buffer.writeln('    Selected Types: ${entry.releaseNotificationPrefs!.selectedTypes}');
        } else {
          buffer.writeln('  [DB] Release Notification Prefs: NULL');
          buffer.writeln('  [UI] Will display: Global defaults (Theatre: ${prefs.effectiveNotifyTheatre}, Streaming: ${prefs.effectiveNotifyStreaming})');
        }
        
        if (entry.tvNotificationPrefs != null) {
          buffer.writeln('  [DB] TV Notification Prefs:');
          buffer.writeln('    Series Premiere: ${entry.tvNotificationPrefs!.seriesPremiere}');
          buffer.writeln('    Season Premieres: ${entry.tvNotificationPrefs!.seasonPremieres}');
          buffer.writeln('    Season Finales: ${entry.tvNotificationPrefs!.seasonFinales}');
          buffer.writeln('    New Episodes: ${entry.tvNotificationPrefs!.newEpisodes}');
          buffer.writeln('    Specials: ${entry.tvNotificationPrefs!.specials}');
        }
        
        buffer.writeln('');
      }
      
      buffer.writeln('=== GLOBAL PREFERENCES ===');
      buffer.writeln('Notify Theatre: ${prefs.notifyTheatre}');
      buffer.writeln('Notify Streaming: ${prefs.notifyStreaming}');
      buffer.writeln('Notify Physical: ${prefs.notifyPhysical}');
      buffer.writeln('Notify TV: ${prefs.notifyTV}');
      buffer.writeln('Schedule Time: ${prefs.scheduleTime}');
      buffer.writeln('Last Check Time: ${prefs.lastCheckTime}');
      buffer.writeln('Pretend Today: ${prefs.pretendToday}');
      buffer.writeln('');
      
      final exportText = buffer.toString();
      
      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: exportText));
      
      if (context.mounted) {
        showSimpleSnackBar(
          context,
          'Database info copied to clipboard!',
          duration: const Duration(seconds: 3),
        );
      }
      
      // Also print to debug console
      debugPrint(exportText);
    } catch (e) {
      if (context.mounted) {
        showSimpleSnackBar(
          context,
          'Error exporting database: $e',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _fixNullPreferences(BuildContext context, WidgetRef ref) async {
    try {
      final watchlistLogic = ref.read(watchlistLogicProvider);
      final watchlistRepo = ref.read(watchlistRepositoryProvider);
      
      final entries = watchlistRepo.getWorks();
      int fixedCount = 0;
      
      for (final entry in entries) {
        if (entry.releaseNotificationPrefs == null && entry.type == WorkType.movie) {
          // Set default preferences based on global settings
          final prefs = ref.read(preferencesRepositoryProvider).getPreferences();
          final defaultPrefs = ReleaseNotificationPreferences(
            theatrical: prefs.effectiveNotifyTheatre,
            streaming: prefs.effectiveNotifyStreaming,
            physical: prefs.effectiveNotifyPhysical,
            tv: prefs.effectiveNotifyTV,
          );
          
          await watchlistLogic.updateReleaseNotificationPreferences(
            entry.tmdbId,
            entry.type,
            defaultPrefs,
          );
          fixedCount++;
          debugPrint('[DebugScreen] Fixed preferences for: ${entry.title}');
        } else if (entry.tvNotificationPrefs == null && entry.type == WorkType.tvShow) {
          // Set default TV preferences
          final defaultTvPrefs = TvNotificationPreferences(
            seriesPremiere: true,
            seasonPremieres: true,
            seasonFinales: false,
            newEpisodes: false,
            specials: false,
          );
          
          await watchlistLogic.updateTvNotificationPreferences(
            entry.tmdbId,
            defaultTvPrefs,
          );
          fixedCount++;
          debugPrint('[DebugScreen] Fixed TV preferences for: ${entry.title}');
        }
      }
      
      ref.invalidate(watchlistEntriesProvider);
      
      if (context.mounted) {
        showSimpleSnackBar(
          context,
          'Fixed $fixedCount entries with NULL preferences',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showSimpleSnackBar(
          context,
          'Error fixing preferences: $e',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _exportHistoryInfo(BuildContext context, WidgetRef ref) async {
    try {
      final historyRepo = ref.read(historyRepositoryProvider);
      final history = historyRepo.getHistory();
      
      // Build export string
      final buffer = StringBuffer();
      buffer.writeln('=== NOTIFICATION HISTORY EXPORT ===');
      buffer.writeln('Total entries: ${history.length}');
      buffer.writeln('');
      
      for (final item in history) {
        final entry = item.entry;
        buffer.writeln('Title: ${item.title}');
        buffer.writeln('  TMDB ID: ${entry.tmdbId}');
        buffer.writeln('  Media Type: ${entry.mediaType}');
        buffer.writeln('  Notification Events: ${entry.notificationEvents.length}');
        
        for (int i = 0; i < entry.notificationEvents.length; i++) {
          final event = entry.notificationEvents[i];
          buffer.writeln('    Event $i:');
          buffer.writeln('      Release Type: ${event.releaseType}');
          buffer.writeln('      Release Date: ${event.releaseDate}');
          buffer.writeln('      Notified At: ${event.notifiedAt}');
        }
        
        buffer.writeln('  Reasons (${entry.reasons.length}):');
        for (final reason in entry.reasons) {
          buffer.writeln('    - ${reason.contributorName}');
          buffer.writeln('      Department: ${reason.department}');
          buffer.writeln('      Job: ${reason.job}');
          buffer.writeln('      Contributor ID: ${reason.contributorId}');
        }
        
        if (entry.mediaType == 'tv') {
          buffer.writeln('  TV Info:');
          buffer.writeln('    Season: ${entry.seasonNumber}');
          buffer.writeln('    Episode: ${entry.episodeNumber}');
          buffer.writeln('    Episode Title: ${entry.episodeTitle}');
          buffer.writeln('    TV Notification Type: ${entry.tvNotificationType}');
        }
        
        buffer.writeln('');
      }
      
      final exportText = buffer.toString();
      
      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: exportText));
      
      if (context.mounted) {
        showSimpleSnackBar(
          context,
          'History info copied to clipboard! (${history.length} entries)',
          duration: const Duration(seconds: 3),
        );
      }
      
      // Also print to debug console
      debugPrint(exportText);
    } catch (e) {
      if (context.mounted) {
        showSimpleSnackBar(
          context,
          'Error exporting history: $e',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }
}

class _LastCheckTimeDialog extends StatefulWidget {
  final DateTime initialDateTime;

  const _LastCheckTimeDialog({required this.initialDateTime});

  @override
  State<_LastCheckTimeDialog> createState() => _LastCheckTimeDialogState();
}

class _LastCheckTimeDialogState extends State<_LastCheckTimeDialog> {
  late DateTime selectedDateTime;
  late TextEditingController _dateController;
  late TextEditingController _timeController;

  @override
  void initState() {
    super.initState();
    selectedDateTime = widget.initialDateTime;
    _dateController = TextEditingController(
      text: '${selectedDateTime.year}-${selectedDateTime.month.toString().padLeft(2, '0')}-${selectedDateTime.day.toString().padLeft(2, '0')}',
    );
    _timeController = TextEditingController(
      text: '${selectedDateTime.hour.toString().padLeft(2, '0')}:${selectedDateTime.minute.toString().padLeft(2, '0')}',
    );
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Last Check Time'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set when the last notification check occurred. This affects which releases will be considered "new".',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text('Date:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(
                hintText: 'YYYY-MM-DD',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _updateDateTime,
            ),
            const SizedBox(height: 12),
            const Text('Time:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            TextField(
              controller: _timeController,
              decoration: const InputDecoration(
                hintText: 'HH:MM',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _updateDateTime,
            ),
            const SizedBox(height: 16),
            const Text('Quick Options:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickOptionChip(
                  label: '1 hour ago',
                  onTap: () => _setQuickTime(DateTime.now().subtract(const Duration(hours: 1))),
                ),
                _QuickOptionChip(
                  label: '6 hours ago',
                  onTap: () => _setQuickTime(DateTime.now().subtract(const Duration(hours: 6))),
                ),
                _QuickOptionChip(
                  label: '1 day ago',
                  onTap: () => _setQuickTime(DateTime.now().subtract(const Duration(days: 1))),
                ),
                _QuickOptionChip(
                  label: '3 days ago',
                  onTap: () => _setQuickTime(DateTime.now().subtract(const Duration(days: 3))),
                ),
                _QuickOptionChip(
                  label: '1 week ago',
                  onTap: () => _setQuickTime(DateTime.now().subtract(const Duration(days: 7))),
                ),
                _QuickOptionChip(
                  label: 'Yesterday (Force Missed)',
                  onTap: () => _setQuickTime(DateTime.now().subtract(const Duration(days: 1))),
                ),
                _QuickOptionChip(
                  label: 'Never',
                  onTap: () => Navigator.pop(context, DateTime.fromMillisecondsSinceEpoch(0)),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, selectedDateTime),
          child: const Text('Set'),
        ),
      ],
    );
  }

  void _updateDateTime([String? _]) {
    try {
      final dateParts = _dateController.text.split('-');
      final timeParts = _timeController.text.split(':');
      
      if (dateParts.length == 3 && timeParts.length == 2) {
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final day = int.parse(dateParts[2]);
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        
        setState(() {
          selectedDateTime = DateTime(year, month, day, hour, minute);
        });
      }
    } catch (e) {
      // Invalid format, keep current selectedDateTime
    }
  }

  void _setQuickTime(DateTime dateTime) {
    setState(() {
      selectedDateTime = dateTime;
      _dateController.text = '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
      _timeController.text = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    });
  }
}

class _QuickOptionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickOptionChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}