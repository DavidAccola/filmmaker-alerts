import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../providers/providers.dart';
import '../../logic/notification_logic.dart';
import '../../data/models/preferences.dart';
import '../../utils/debug_logger.dart';
import 'package:flutter/services.dart';

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
      body: Center(
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
}